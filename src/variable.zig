const std = @import("std");
const types = @import("types.zig");

const Value = types.Value;

pub const Tunable = struct {
    name: []const u8,
    default: Value,
    min: ?Value = null,
    max: ?Value = null,
};

pub const knight_mobility: Value = 5;
pub const bishop_mobility: Value = 5;
pub const rook_mobility: Value = 5;
pub const queen_mobility: Value = 5;
pub const king_mobility: Value = 5;

pub const pawn_threat_knight: Value = 0;
pub const pawn_threat_bishop: Value = 0;
pub const pawn_threat_rook: Value = 0;
pub const pawn_threat_queen: Value = 0;

pub const pawn_defend_king: Value = 5;
pub const pawn_isolated: Value = 30;
pub const pawn_doubled: Value = 15;
pub const pawn_blocked: Value = 10;
pub const pawn_protection: Value = 30;

pub const bishop_pair: Value = 10;

pub const rook_open_files: Value = 40;
pub const rook_semi_open_files: Value = 20;

pub var tunables = [_]Tunable{
    .{ .name = "knight_mobility", .default = knight_mobility, .min = 0, .max = 50 },
    .{ .name = "bishop_mobility", .default = bishop_mobility, .min = 0, .max = 50 },
    .{ .name = "rook_mobility", .default = rook_mobility, .min = 0, .max = 50 },
    .{ .name = "queen_mobility", .default = queen_mobility, .min = 0, .max = 50 },
    // .{ .name = "king_mobility", .default = king_mobility, .min = -50, .max = 50 },
    // .{ .name = "pawn_threat_knight", .default = pawn_threat_knight, .min = 0, .max = 50 },
    // .{ .name = "pawn_threat_bishop", .default = pawn_threat_bishop, .min = 0, .max = 50 },
    // .{ .name = "pawn_threat_rook", .default = pawn_threat_rook, .min = 0, .max = 50 },
    // .{ .name = "pawn_threat_queen", .default = pawn_threat_queen, .min = 0, .max = 50 },
    .{ .name = "pawn_defend_king", .default = pawn_defend_king, .min = 0, .max = 50 },
    .{ .name = "pawn_isolated", .default = pawn_isolated, .min = 0, .max = 50 },
    .{ .name = "pawn_doubled", .default = pawn_doubled, .min = 0, .max = 50 },
    .{ .name = "pawn_blocked", .default = pawn_blocked, .min = 0, .max = 50 },
    .{ .name = "pawn_protection", .default = pawn_protection, .min = 0, .max = 50 },
    .{ .name = "bishop_pair", .default = bishop_pair, .min = -100, .max = 100 },
    .{ .name = "rook_open_files", .default = rook_open_files, .min = 0, .max = 100 },
    .{ .name = "rook_semi_open_files", .default = rook_semi_open_files, .min = 0, .max = 100 },
};

pub fn getValues(buffer: []types.Value) void {
    std.debug.assert(buffer.len >= tunables.len);
    for (tunables, 0..) |tunable, i| {
        buffer[i] = tunable.default;
    }
}

pub fn getValue(comptime name: []const u8) types.Value {
    inline for (tunables) |tunable| {
        if (std.ascii.eqlIgnoreCase(tunable.name, name)) {
            return tunable.default;
        }
    }
    unreachable;
}
