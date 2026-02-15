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

    var move_list: [types.max_moves]types.Move = @splat(.none);
    var move_len: usize = 0;

    pos.updateAttacked(true);
    pos.generateLegalMoves(types.GenerationType.all, .white, &move_list, &move_len, true);

    try expectEqual(26, move_len);
}

test "CastleIntersect" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, "1qk5/8/8/8/8/8/8/R1K1R3 w KQ - 0 1");
    var move_list: [types.max_moves]types.Move = @splat(.none);
    var move_len: usize = 0;

    pos.updateAttacked(true);
    pos.generateLegalMoves(types.GenerationType.all, .white, &move_list, &move_len, true);
    try expectEqual(24, move_len);

    pos = try position.Position.setFen(&s, "rk3r2/8/8/pppppppp/8/8/8/R4RK1 w Qkq -");
    try expectEqual(20, search.perftTest(allocator, &pos, 1, true) catch unreachable);
    try expectEqual(459, search.perftTest(allocator, &pos, 2, true) catch unreachable);
    try expectEqual(9_665, search.perftTest(allocator, &pos, 3, true) catch unreachable);
    try expectEqual(228_080, search.perftTest(allocator, &pos, 4, true) catch unreachable);
}

test "CastleMixed" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, "1r1k1b1q/2pp2pp/1p3p2/4r3/4n3/1P6/1PPP1PPP/R2KRBBQ w AEb");

    var move_list: [types.max_moves]types.Move = @splat(.none);
    var move_len: usize = 0;

    pos.updateAttacked(true);
    pos.generateLegalMoves(types.GenerationType.all, .white, &move_list, &move_len, true);

    try expectEqual(31, move_len);
}

test "CastleCheck" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, "1rk1rbbq/2p2ppp/1p2p3/3pPP2/5P2/QN6/PPPP3P/1RNKRB2 b KQq -");

    try expectEqual(23, search.perftTest(allocator, &pos, 1, true) catch unreachable);
    try expectEqual(806, search.perftTest(allocator, &pos, 2, true) catch unreachable);
    try expectEqual(17_730, search.perftTest(allocator, &pos, 3, true) catch unreachable);
    try expectEqual(641_118, search.perftTest(allocator, &pos, 4, true) catch unreachable);
    try expectEqual(14_466_362, search.perftTest(allocator, &pos, 5, true) catch unreachable);

    pos = try position.Position.setFen(&s, "1rk1rbbq/2p2ppp/1p2p3/3pPP2/5P2/QN6/PPPP3P/1RNKRB2 b KQq");
    var s2: position.State = position.State{};
    try pos.movePiece(try types.Move.initFromStr(pos, "e6f5"), &s2);
    var s3: position.State = position.State{};
    try pos.movePiece(try types.Move.initFromStr(pos, "a3a8"), &s3);
    try expectEqual(21, search.perftTest(allocator, &pos, 1, true) catch unreachable);
    try expectEqual(749, search.perftTest(allocator, &pos, 2, true) catch unreachable);
    try expectEqual(15_546, search.perftTest(allocator, &pos, 3, true) catch unreachable);
}
