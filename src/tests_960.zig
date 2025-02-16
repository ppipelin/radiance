//! This module provides tests for the 960 support of the program

const position = @import("position.zig");
const std = @import("std");
const tables = @import("tables.zig");
const types = @import("types.zig");

const expectEqual = std.testing.expectEqual;

const allocator = std.testing.allocator;

test "Castle" {
    tables.initAll(allocator);
    defer tables.deinitAll();

    var s: position.State = position.State{};
    var pos: position.Position = position.Position.setFen(&s, "2k5/8/8/8/8/8/8/R2K2R1 w KQ - 0 1");

    var list = std.ArrayList(types.Move).init(allocator);
    defer list.deinit();

    pos.generateLegalMoves(pos.state.turn, &list);

    try expectEqual(26, list.items.len);
}

test "CastleIntersect" {
    tables.initAll(allocator);
    defer tables.deinitAll();

    var s: position.State = position.State{};
    var pos: position.Position = position.Position.setFen(&s, "1qk5/8/8/8/8/8/8/R1K1R3 w KQ - 0 1");

    var list = std.ArrayList(types.Move).init(allocator);
    defer list.deinit();

    pos.generateLegalMoves(pos.state.turn, &list);

    try expectEqual(24, list.items.len);
}
