const position = @import("position.zig");
const std = @import("std");
const types = @import("types.zig");

const Nnue = @This();

pub const Quantized = i16;
pub const Full = i32;
const lanes: comptime_int = std.simd.suggestVectorLength(Quantized) orelse 1;
const Vector = @Vector(lanes, Quantized);

pub const input_size: usize = 768; // L0
pub const hidden_size: usize = 128; // L1
const QA = 255;
const QB = 64; // Bias is quantized the same way final evaluation is quantized
pub const SCALE = 400;

/// Accumulate the value of weights, this corresponds to the first hidden layer
/// 0 is friendly for black perspective while 1 is the friendly for white
/// When fed into forward be careful to put first friendly then not friendly
accumulator: [2][hidden_size]Quantized = undefined,

pub var l0w: [input_size][hidden_size]Quantized = undefined;
pub var l0b: [hidden_size]Quantized = undefined;
pub var l1w: [hidden_size * 2]Quantized = undefined;
pub var l1w_v: @Vector(hidden_size * 2, Full) = undefined;
pub var l1b: Full = undefined;

pub fn loadFromBin(data: []const Quantized) void {
    for (0..hidden_size) |col| {
        for (0..input_size) |row| {
            l0w[row][col] = data[row * hidden_size + col];
        }
    }
    var anchor = input_size * hidden_size;
    @memcpy(l0b[0..], data[anchor..(anchor + hidden_size)]);
    anchor = anchor + hidden_size;
    @memcpy(l1w[0..], data[anchor..(anchor + hidden_size * 2)]);
    anchor = anchor + hidden_size * 2;
    l1b = data[anchor];

    l1w_v = l1w;
    std.debug.print("anchor {}\n", .{anchor});
}

pub inline fn featureIndex(is_friendly: bool, pt: types.PieceType, sq: usize) usize {
    const skip: usize = if (is_friendly) 0 else 1;
    return (skip * (types.PieceType.nb() - 1) + pt.index() - 1) * types.board_size2 + sq;
}

pub fn initAccumulator(self: *Nnue) void {
    // Initialize accumulator with bias
    @memcpy(self.accumulator[0][0..], l0b[0..]);
    @memcpy(self.accumulator[1][0..], l0b[0..]);
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

fn vectorAdd(comptime T: type, vec: T, add: anytype) T {
    return vec + @as(T, @splat(add));
}

fn vectorMult(comptime T: type, vec: T, add: anytype) T {
    return vec * @as(T, @splat(add));
}

fn vectorDiv(comptime T: type, vec: T, add: anytype) T {
    return vec / @as(T, @splat(add));
}

const FullHiddenVec = @Vector(hidden_size * 2, Full);

inline fn screlu(vec: FullHiddenVec) FullHiddenVec {
    const clipped = std.math.clamp(vec, @as(FullHiddenVec, @splat(0)), @as(FullHiddenVec, @splat(QA)));
    return clipped * clipped;
}

pub fn forward(self: *const Nnue, col: types.Color) Quantized {
    const accumulator_v: FullHiddenVec = if (col.isWhite()) self.accumulator[1] ++ self.accumulator[0] else self.accumulator[0] ++ self.accumulator[1];

    const l1: FullHiddenVec = accumulator_v;
    const l1_screlu = screlu(l1);

    var o: Full = @reduce(.Add, l1_screlu * l1w_v);

    // Reduce quantization from QA * QA * QB to QA * QB.
    o = @divTrunc(o, QA);

    // Add output bias
    o += l1b;

    // Apply scale
    o *= SCALE;

    // Remove quantization
    o = @divTrunc(o, QA * QB);

    return @intCast(o);
}
