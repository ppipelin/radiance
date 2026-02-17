const std = @import("std");
const types = @import("types.zig");

const Value = types.Value;
const ValueTunable = i32;
// const factor_tunable: ValueTunable = 1000;
const factor_tunable: ValueTunable = 1;

pub const Tunable = struct {
    name: []const u8,
    default: ValueTunable,
    min: ?ValueTunable = null,
    max: ?ValueTunable = null,

    pub inline fn value(self: Tunable) types.Value {
        return @truncate(@divTrunc(self.default, factor_tunable));
    }
};

pub const knight_mobility: ValueTunable = 5 * factor_tunable;
pub const bishop_mobility: ValueTunable = 5 * factor_tunable;
pub const rook_mobility: ValueTunable = 5 * factor_tunable;
pub const queen_mobility: ValueTunable = 5 * factor_tunable;
pub const king_mobility: ValueTunable = 5 * factor_tunable;

pub const pawn_threat_knight: ValueTunable = 0 * factor_tunable;
pub const pawn_threat_bishop: ValueTunable = 0 * factor_tunable;
pub const pawn_threat_rook: ValueTunable = 0 * factor_tunable;
pub const pawn_threat_queen: ValueTunable = 0 * factor_tunable;

pub const pawn_defend_king: ValueTunable = 5 * factor_tunable;
pub const pawn_isolated: ValueTunable = 30 * factor_tunable;
pub const pawn_doubled: ValueTunable = 15 * factor_tunable;
pub const pawn_blocked: ValueTunable = 10 * factor_tunable;
pub const pawn_protection: ValueTunable = 30 * factor_tunable;

pub const bishop_pair: ValueTunable = 10 * factor_tunable;

pub const rook_open_files: ValueTunable = 40 * factor_tunable;
pub const rook_semi_open_files: ValueTunable = 20 * factor_tunable;

//    4,    2,    0,    2,  -10,    9,    8,    9,  187,   23,   25,   21,
//   +5,   +3,   -1,   +3,  -11,   +8,   +9,  +12,  +34,  +20,  +28,  +18,
pub var tunables = [_]Tunable{
    .{ .name = "knight_mobility", .default = knight_mobility },
    .{ .name = "bishop_mobility", .default = bishop_mobility },
    .{ .name = "rook_mobility", .default = rook_mobility },
    .{ .name = "queen_mobility", .default = queen_mobility },
    // .{ .name = "king_mobility", .default = king_mobility },
    // .{ .name = "pawn_threat_knight", .default = pawn_threat_knight },
    // .{ .name = "pawn_threat_bishop", .default = pawn_threat_bishop },
    // .{ .name = "pawn_threat_rook", .default = pawn_threat_rook },
    // .{ .name = "pawn_threat_queen", .default = pawn_threat_queen },
    .{ .name = "pawn_defend_king", .default = pawn_defend_king },
    .{ .name = "pawn_isolated", .default = pawn_isolated },
    .{ .name = "pawn_doubled", .default = pawn_doubled },
    .{ .name = "pawn_blocked", .default = pawn_blocked },
    .{ .name = "pawn_protection", .default = pawn_protection },
    .{ .name = "bishop_pair", .default = bishop_pair },
    .{ .name = "rook_open_files", .default = rook_open_files },
    .{ .name = "rook_semi_open_files", .default = rook_semi_open_files },
};

pub fn getValues(buffer: []types.Value) void {
    std.debug.assert(buffer.len >= tunables.len);
    for (tunables, 0..) |tunable, i| {
        buffer[i] = tunable.value();
    }
}

pub fn getValue(name: []const u8) types.Value {
    inline for (tunables) |tunable| {
        if (std.ascii.eqlIgnoreCase(tunable.name, name)) {
            return tunable.value();
        }
    }
    unreachable;
}
