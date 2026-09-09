const position = @import("position.zig");
const std = @import("std");
const types = @import("types.zig");

const Nnue = @This();

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
pub const output_size: usize = 8; // Output buckets number
const divisor: usize = std.math.divCeil(usize, 32, output_size) catch unreachable;
const quantization_a = 255;
const quantization_b = 64;
pub const quantization_scale = 400;

/// Accumulate the value of weights, this corresponds to the first hidden layer
/// 0 is friendly for black perspective while 1 is the friendly for white
/// When fed into forward be careful to put first friendly then not friendly
accumulator: [2][hidden_size]Quantized = undefined,

pub var l0w: [input_size][hidden_size]Quantized = undefined;
pub var l0b: [hidden_size]Quantized = undefined;
pub var l1w: [output_size][hidden_size * 2]Quantized = undefined; // Transposed for cache
pub var l1b: [output_size]Full = undefined;

pub fn loadFromBin(data: []const Quantized) void {
    for (0..hidden_size) |col| {
        for (0..input_size) |row| {
            l0w[row][col] = data[row * hidden_size + col];
        }
    }
    var anchor = input_size * hidden_size;
    @memcpy(&l0b, data[anchor..(anchor + hidden_size)]);
    anchor = anchor + hidden_size;
    for (0..output_size) |i| {
        @memcpy(&l1w[i], data[anchor..(anchor + hidden_size * 2)]);
        anchor = anchor + hidden_size * 2;
    }

    for (data[anchor..(anchor + output_size)], 0..) |bias, i| {
        l1b[i] = @intCast(bias);
    }
}

pub inline fn featureIndex(is_friendly: bool, pt: types.PieceType, sq: usize) usize {
    const skip: usize = if (is_friendly) 0 else 1;
    return (skip * (types.PieceType.nb() - 1) + pt.index() - 1) * types.board_size2 + sq;
}

pub fn initAccumulator(self: *Nnue) void {
    // Initialize accumulator with bias
    @memcpy(&self.accumulator[0], &l0b);
    @memcpy(&self.accumulator[1], &l0b);
}

pub fn fillAccumulator(self: *Nnue, pos: position.Position) void {
    initAccumulator(self);

    for (std.enums.values(types.Color)) |abs_col| {
        const is_friendly: bool = abs_col == pos.state.turn;
        for (std.enums.values(types.PieceType)) |pt| {
            if (pt == .none)
                continue;
            for (0..types.board_size2) |sq| {
                if (pos.bb_colors[abs_col.index()] & pos.bb_pieces[pt.index()] & (@as(u64, 1) << @intCast(sq)) == 0)
                    continue;

                const sq_mirror = sq ^ 56;

                // Friendly
                const row_us = featureIndex(is_friendly, pt, if (pos.state.turn.isWhite()) sq else sq_mirror);
                // Not friendly
                const row_them = featureIndex(!is_friendly, pt, if (pos.state.turn.isWhite()) sq_mirror else sq);

                for (0..hidden_size) |neuron_idx| {
                    self.accumulator[pos.state.turn.index()][neuron_idx] += l0w[row_us][neuron_idx];
                    self.accumulator[pos.state.turn.invert().index()][neuron_idx] += l0w[row_them][neuron_idx];
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

inline fn outputBucketIdx(pos: *const position.Position) usize {
    const occupancy: u7 = @popCount(pos.bb_colors[types.Color.white.index()] | pos.bb_colors[types.Color.black.index()]);
    return @min(output_size - 1, @divTrunc(occupancy - 2, divisor));
}

pub fn forward(self: *const Nnue, pos: *const position.Position) Quantized {
    const l1: QuantizedHiddenVec = if (pos.state.turn.isWhite()) self.accumulator[1] ++ self.accumulator[0] else self.accumulator[0] ++ self.accumulator[1];

    var l1_screlu: FullHiddenVec = undefined;
    screlu(l1, &l1_screlu);

    const output_bucket_idx: usize = outputBucketIdx(pos);

    var o: Full = 0;
    var cnt: usize = 0;
    while (cnt + lanes_full <= hidden_size * 2) : (cnt += lanes_full) {
        const l1_screlu_simd: FullVec = l1_screlu[cnt..(cnt + lanes_full)][0..lanes_full].*;
        const l1w_simd: FullVec = l1w[output_bucket_idx][cnt..(cnt + lanes_full)][0..lanes_full].*;
        const mult: FullVec = l1_screlu_simd * l1w_simd;
        o += @reduce(.Add, mult);
    }

    while (cnt < hidden_size * 2) : (cnt += 1) {
        o += l1_screlu[cnt] * l1w[output_bucket_idx][cnt];
    }

    // Reduce quantization from QA * QA * QB to QA * QB.
    o = @divTrunc(o, quantization_a);

    // Add output bias
    o += l1b[output_bucket_idx];

    // Apply quantization_scale
    o *= quantization_scale;

    // Remove quantization
    o = @divTrunc(o, quantization_a * quantization_b);

    return @intCast(o);
}
