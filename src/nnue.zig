const position = @import("position.zig");
const std = @import("std");
const types = @import("types.zig");

pub const Quantized = i16;
pub const Full = i32;
pub const QuantizedVec = @Vector(lanes, Quantized);
pub const FullVec = @Vector(lanes_full, Full);
const QuantizedHiddenVec = [hidden_size * 2]Quantized;
const FullHiddenVec = [hidden_size * 2]Full;

pub const lanes: comptime_int = std.simd.suggestVectorLength(Quantized) orelse 1;
pub const lanes_full: comptime_int = std.simd.suggestVectorLength(Full) orelse 1;

pub const input_size: usize = 768; // L0
pub const hidden_size: usize = 512; // L1
const quantization_a = 255;
const quantization_b = 64;
pub const quantization_scale = 400;

/// Accumulate the value of weights, this corresponds to the first hidden layer
/// 0 is friendly for black perspective while 1 is the friendly for white
/// When fed into forward be careful to put first friendly then not friendly
pub const Accumulator = [2][hidden_size]Quantized;

pub var l0w: [input_size][hidden_size]Quantized = undefined;
pub var l0b: [hidden_size]Quantized = undefined;
pub var l1w: [hidden_size * 2]Quantized = undefined; // Transposed for cache
pub var l1b: Full = undefined;

pub fn initNetwork() void {
    const nnue_bytes = @import("nnue_data").bytes;

    var nnue_content: [nnue_bytes.len / 2]Quantized = undefined;

    for (&nnue_content, 0..) |*value, i| {
        value.* = std.mem.readInt(Quantized, nnue_bytes[i * 2 ..][0..2], .little);
    }

    loadFromBin(nnue_content[0..]);
}

pub fn loadFromBin(data: []const Quantized) void {
    for (0..hidden_size) |col| {
        for (0..input_size) |row| {
            l0w[row][col] = data[row * hidden_size + col];
        }
    }
    var anchor = input_size * hidden_size;
    @memcpy(&l0b, data[anchor..(anchor + hidden_size)]);
    anchor = anchor + hidden_size;
    @memcpy(&l1w, data[anchor..(anchor + hidden_size * 2)]);
    anchor = anchor + hidden_size * 2;
    l1b = data[anchor];
}

pub inline fn featureIndex(comptime perspective: types.Color, p: types.Piece, sq: types.Square) usize {
    const is_friendly: bool = p.pieceToColor() == perspective;
    const skip: usize = if (is_friendly) 0 else 1;
    const sq_oriented: usize = if (perspective == .white) sq.index() else sq.index() ^ 56;
    return (skip * (types.PieceType.nb() - 1) + p.pieceToPieceType().index() - 1) * types.board_size2 + sq_oriented;
}

/// Should be called after weights and bias are loaded
pub fn initAccumulator(acc: *Accumulator) void {
    // Initialize accumulator with bias
    @memcpy(&acc[types.Color.white.index()], &l0b);
    @memcpy(&acc[types.Color.black.index()], &l0b);
}

pub fn fillAccumulator(acc: *Accumulator, pos: position.Position) void {
    initAccumulator(acc);

    for (std.enums.values(types.Color)) |abs_col| {
        for (std.enums.values(types.PieceType)) |pt| {
            if (pt == .none)
                continue;

            const p: types.Piece = pt.pieceTypeToPiece(abs_col);
            for (0..types.board_size2) |sq| {
                if (pos.bb_colors[abs_col.index()] & pos.bb_pieces[pt.index()] & (@as(u64, 1) << @intCast(sq)) == 0)
                    continue;

                const row_w = featureIndex(.white, p, @enumFromInt(sq));
                const row_b = featureIndex(.black, p, @enumFromInt(sq));

                for (0..hidden_size) |neuron_idx| {
                    acc[types.Color.white.index()][neuron_idx] += l0w[row_w][neuron_idx];
                    acc[types.Color.black.index()][neuron_idx] += l0w[row_b][neuron_idx];
                }
            }
        }
    }
}

fn screlu(in: QuantizedHiddenVec, out: *FullHiddenVec) void {
    var cnt: usize = 0;
    while (cnt + lanes_full <= hidden_size * 2) : (cnt += lanes_full) {
        const in_simd: FullVec = in[cnt..(cnt + lanes_full)][0..lanes_full].*;
        const clipped: FullVec = std.math.clamp(in_simd, @as(FullVec, @splat(0)), @as(FullVec, @splat(quantization_a)));
        const clipped_squared: FullVec = clipped * clipped;
        const clipped_squared_array: [lanes_full]Full = clipped_squared;
        @memcpy(out[cnt..(cnt + lanes_full)], &clipped_squared_array);
    }

    while (cnt < hidden_size * 2) : (cnt += 1) {
        const clipped: Full = std.math.clamp(in[cnt], 0, quantization_a);
        out[cnt] = clipped * clipped;
    }
}

pub fn forward(noalias acc: *const Accumulator, noalias pos: *const position.Position) Quantized {
    const l1: QuantizedHiddenVec = if (pos.state.turn.isWhite()) acc[1] ++ acc[0] else acc[0] ++ acc[1];

    var l1_screlu: FullHiddenVec = undefined;
    screlu(l1, &l1_screlu);

    var o: Full = 0;
    var cnt: usize = 0;
    while (cnt + lanes_full <= hidden_size * 2) : (cnt += lanes_full) {
        const l1_screlu_simd: FullVec = l1_screlu[cnt..(cnt + lanes_full)][0..lanes_full].*;
        const l1w_simd: FullVec = l1w[cnt..(cnt + lanes_full)][0..lanes_full].*;
        const mult: FullVec = l1_screlu_simd * l1w_simd;
        o += @reduce(.Add, mult);
    }

    while (cnt < hidden_size * 2) : (cnt += 1) {
        o += l1_screlu[cnt] * l1w[cnt];
    }

    // Reduce quantization from QA * QA * QB to QA * QB.
    o = @divTrunc(o, quantization_a);

    // Add output bias
    o += l1b;

    // Apply quantization_scale
    o *= quantization_scale;

    // Remove quantization
    o = @divTrunc(o, quantization_a * quantization_b);

    return @intCast(o);
}

pub fn remove(noalias acc: *Accumulator, p: types.Piece, sq: types.Square) void {
    const row_w = featureIndex(.white, p, sq);
    const row_b = featureIndex(.black, p, sq);

    var i: usize = 0;
    while (i < hidden_size) : (i += lanes) {
        const target_w: *[lanes]Quantized = acc[types.Color.white.index()][i..][0..lanes];
        const target_b: *[lanes]Quantized = acc[types.Color.black.index()][i..][0..lanes];

        const weights_w: QuantizedVec = l0w[row_w][i..][0..lanes].*;
        const weights_b: QuantizedVec = l0w[row_b][i..][0..lanes].*;

        target_w.* = @as(QuantizedVec, target_w.*) - weights_w;
        target_b.* = @as(QuantizedVec, target_b.*) - weights_b;
    }
}

pub fn add(noalias acc: *Accumulator, p: types.Piece, sq: types.Square) void {
    const row_w = featureIndex(.white, p, sq);
    const row_b = featureIndex(.black, p, sq);

    var i: usize = 0;
    while (i < hidden_size) : (i += lanes) {
        const target_w: *[lanes]Quantized = acc[types.Color.white.index()][i..][0..lanes];
        const target_b: *[lanes]Quantized = acc[types.Color.black.index()][i..][0..lanes];

        const weights_w: QuantizedVec = l0w[row_w][i..][0..lanes].*;
        const weights_b: QuantizedVec = l0w[row_b][i..][0..lanes].*;

        target_w.* = @as(QuantizedVec, target_w.*) + weights_w;
        target_b.* = @as(QuantizedVec, target_b.*) + weights_b;
    }
}

pub fn removeAdd(noalias acc: *Accumulator, remove_p: types.Piece, remove_sq: types.Square, add_p: types.Piece, add_sq: types.Square) void {
    const w_add = featureIndex(.white, add_p, add_sq);
    const w_rem = featureIndex(.white, remove_p, remove_sq);
    const b_add = featureIndex(.black, add_p, add_sq);
    const b_rem = featureIndex(.black, remove_p, remove_sq);

    var i: usize = 0;
    while (i < hidden_size) : (i += lanes) {
        const target_w: *[lanes]Quantized = acc[types.Color.white.index()][i..][0..lanes];
        const target_b: *[lanes]Quantized = acc[types.Color.black.index()][i..][0..lanes];

        const weights_remove_w: QuantizedVec = l0w[w_rem][i..][0..lanes].*;
        const weights_remove_b: QuantizedVec = l0w[b_rem][i..][0..lanes].*;
        const weights_add_w: QuantizedVec = l0w[w_add][i..][0..lanes].*;
        const weights_add_b: QuantizedVec = l0w[b_add][i..][0..lanes].*;

        target_w.* = @as(QuantizedVec, target_w.*) + (weights_add_w - weights_remove_w);
        target_b.* = @as(QuantizedVec, target_b.*) + (weights_add_b - weights_remove_b);
    }
}

/// Only castle and promo-capture uses 4-piece change, set last add to .none for capture
pub fn removeRemoveAddAdd(
    noalias acc: *Accumulator,
    p1: types.Piece,
    remove_1: types.Square,
    p2: types.Piece,
    remove_2: types.Square,
    p3: types.Piece,
    add_3: types.Square,
    p4: types.Piece,
    add_4: types.Square,
) void {
    const p1_remove_w = featureIndex(.white, p1, remove_1);
    const p1_remove_b = featureIndex(.black, p1, remove_1);
    const p2_remove_w = featureIndex(.white, p2, remove_2);
    const p2_remove_b = featureIndex(.black, p2, remove_2);
    const p3_add_w = featureIndex(.white, p3, add_3);
    const p3_add_b = featureIndex(.black, p3, add_3);
    var p4_add_w: usize = 0;
    var p4_add_b: usize = 0;
    if (p4 != .none) {
        p4_add_w = featureIndex(.white, p4, add_4);
        p4_add_b = featureIndex(.black, p4, add_4);
    }

    var i: usize = 0;
    while (i < hidden_size) : (i += lanes) {
        const target_w: *[lanes]Quantized = acc[types.Color.white.index()][i..][0..lanes];
        const target_b: *[lanes]Quantized = acc[types.Color.black.index()][i..][0..lanes];

        const weights_remove1_w: QuantizedVec = l0w[p1_remove_w][i..][0..lanes].*;
        const weights_remove1_b: QuantizedVec = l0w[p1_remove_b][i..][0..lanes].*;
        const weights_remove2_w: QuantizedVec = l0w[p2_remove_w][i..][0..lanes].*;
        const weights_remove2_b: QuantizedVec = l0w[p2_remove_b][i..][0..lanes].*;
        const weights_add3_w: QuantizedVec = l0w[p3_add_w][i..][0..lanes].*;
        const weights_add3_b: QuantizedVec = l0w[p3_add_b][i..][0..lanes].*;

        if (p4 != .none) {
            const weights_add4_w: QuantizedVec = l0w[p4_add_w][i..][0..lanes].*;
            const weights_add4_b: QuantizedVec = l0w[p4_add_b][i..][0..lanes].*;

            target_w.* = @as(QuantizedVec, target_w.*) + (weights_add3_w + weights_add4_w - weights_remove1_w - weights_remove2_w);
            target_b.* = @as(QuantizedVec, target_b.*) + (weights_add3_b + weights_add4_b - weights_remove1_b - weights_remove2_b);
        } else {
            target_w.* = @as(QuantizedVec, target_w.*) + (weights_add3_w - weights_remove1_w - weights_remove2_w);
            target_b.* = @as(QuantizedVec, target_b.*) + (weights_add3_b - weights_remove1_b - weights_remove2_b);
        }
    }
}
