//! This module provides tests for the 960 support of the program

const position = @import("position.zig");
const search = @import("search.zig");
const std = @import("std");
const tables = @import("tables.zig");
const types = @import("types.zig");

const expectEqual = std.testing.expectEqual;

const allocator = std.testing.allocator;

test "Castle" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, "2k5/8/8/8/8/8/8/R2K2R1 w KQ - 0 1");

    var list: std.ArrayListUnmanaged(types.Move) = .empty;
    defer list.deinit(allocator);

    pos.generateLegalMoves(allocator, pos.state.turn, &list);

    try expectEqual(26, list.items.len);
}

test "CastleIntersect" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, "1qk5/8/8/8/8/8/8/R1K1R3 w KQ - 0 1");
    var list: std.ArrayListUnmanaged(types.Move) = .empty;
    defer list.deinit(allocator);
    pos.generateLegalMoves(allocator, pos.state.turn, &list);
    try expectEqual(24, list.items.len);

    pos = try position.Position.setFen(&s, "rk3r2/8/8/pppppppp/8/8/8/R4RK1 w Qkq -");
    try expectEqual(20, search.perftTest(std.testing.allocator, &pos, 1) catch unreachable);
    try expectEqual(459, search.perftTest(std.testing.allocator, &pos, 2) catch unreachable);
    try expectEqual(9_665, search.perftTest(std.testing.allocator, &pos, 3) catch unreachable);
    try expectEqual(228_080, search.perftTest(std.testing.allocator, &pos, 4) catch unreachable);
}
