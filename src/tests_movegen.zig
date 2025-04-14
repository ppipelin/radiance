//! This module provides tests for move generation of the program

const position = @import("position.zig");
const search = @import("search.zig");
const std = @import("std");
const tables = @import("tables.zig");
const types = @import("types.zig");

const expectEqual = std.testing.expectEqual;

const allocator = std.testing.allocator;

test "Perft" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, position.start_fen);
    try expectEqual(20, search.perftTest(allocator, &pos, 1) catch unreachable);
    try expectEqual(400, search.perftTest(allocator, &pos, 2) catch unreachable);
    try expectEqual(8_902, search.perftTest(allocator, &pos, 3) catch unreachable);
    try expectEqual(197_281, search.perftTest(allocator, &pos, 4) catch unreachable);
    try expectEqual(4_865_609, search.perftTest(allocator, &pos, 5) catch unreachable);
    // try expectEqual(119_060_324, search.perftTest(allocator, &pos, 6) catch unreachable);
    // try expectEqual(3_195_901_860, search.perftTest(allocator, &pos, 7) catch unreachable);
}

test "PerftKiwipete" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, position.kiwi_fen);
    try expectEqual(48, search.perftTest(allocator, &pos, 1) catch unreachable);
    try expectEqual(2039, search.perftTest(allocator, &pos, 2) catch unreachable);
    try expectEqual(97862, search.perftTest(allocator, &pos, 3) catch unreachable);
    try expectEqual(4_085_603, search.perftTest(allocator, &pos, 4) catch unreachable);
    // try expectEqual(193_690_690, search.perftTest(allocator, &pos, 5) catch unreachable);
}

test "PerftPos3" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - -");
    try expectEqual(14, search.perftTest(allocator, &pos, 1) catch unreachable);
    try expectEqual(191, search.perftTest(allocator, &pos, 2) catch unreachable);
    try expectEqual(2_812, search.perftTest(allocator, &pos, 3) catch unreachable);
    try expectEqual(43_238, search.perftTest(allocator, &pos, 4) catch unreachable);
    try expectEqual(674_624, search.perftTest(allocator, &pos, 5) catch unreachable);
}

test "PerftPos4" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1");
    try expectEqual(6, search.perftTest(allocator, &pos, 1) catch unreachable);
    try expectEqual(264, search.perftTest(allocator, &pos, 2) catch unreachable);
    try expectEqual(9_467, search.perftTest(allocator, &pos, 3) catch unreachable);
    try expectEqual(422_333, search.perftTest(allocator, &pos, 4) catch unreachable);
    // try expectEqual(15_833_292, search.perftTest(allocator, &pos, 5) catch unreachable);
}

test "PerftPos5" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8");
    try expectEqual(44, search.perftTest(allocator, &pos, 1) catch unreachable);
    try expectEqual(1_486, search.perftTest(allocator, &pos, 2) catch unreachable);
    try expectEqual(62_379, search.perftTest(allocator, &pos, 3) catch unreachable);
    try expectEqual(2_103_487, search.perftTest(allocator, &pos, 4) catch unreachable);
    // try expectEqual(89_941_194, search.perftTest(allocator, &pos, 5) catch unreachable);
}

test "PerftMoveCastleAddress" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, "2bq1rk1/1pp2pbp/3p2p1/3Pn3/1PPBP1P1/2N4P/5PB1/3QK2R b K -");
    try expectEqual(30, search.perftTest(allocator, &pos, 1) catch unreachable);
    try expectEqual(998, search.perftTest(allocator, &pos, 2) catch unreachable);
    try expectEqual(31_067, search.perftTest(allocator, &pos, 3) catch unreachable);
    try expectEqual(1_057_671, search.perftTest(allocator, &pos, 4) catch unreachable);

    pos = try position.Position.setFen(&s, "3q1rk1/1pp2pbp/3p2p1/3Pnb2/1PPBP1P1/2N4P/5PB1/3QK2R w K - 1 2");
    try expectEqual(37, search.perftTest(allocator, &pos, 1) catch unreachable);
    try expectEqual(1_205, search.perftTest(allocator, &pos, 2) catch unreachable);
    try expectEqual(42_491, search.perftTest(allocator, &pos, 3) catch unreachable);
    try expectEqual(1_398_494, search.perftTest(allocator, &pos, 4) catch unreachable);
    try expectEqual(49_583_496, search.perftTest(allocator, &pos, 5) catch unreachable);

    pos = try position.Position.setFen(&s, "3q1rk1/1pp2pbp/3p2p1/3Pn3/1PPB2P1/2NB3P/5P2/3QK2b w - -");
    try expectEqual(36, search.perftTest(allocator, &pos, 1) catch unreachable);
    try expectEqual(1_175, search.perftTest(allocator, &pos, 2) catch unreachable);
}

test "PerftPin" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, "3K4/4Pp2/5q2/8/3k4/8/8/8 w - -");
    try expectEqual(4, search.perftTest(allocator, &pos, 1) catch unreachable);
    try expectEqual(104, search.perftTest(allocator, &pos, 2) catch unreachable);
    try expectEqual(673, search.perftTest(allocator, &pos, 3) catch unreachable);
    try expectEqual(18_786, search.perftTest(allocator, &pos, 4) catch unreachable);
}

test "PerftEnPassantCheckPinned" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, "2r5/4R3/5pp1/2n2k1p/p4pPP/8/2P5/2K2R2 b - g3");
    try expectEqual(2, search.perftTest(allocator, &pos, 1) catch unreachable);
    try expectEqual(55, search.perftTest(allocator, &pos, 2) catch unreachable);
    try expectEqual(1_144, search.perftTest(allocator, &pos, 3) catch unreachable);
    try expectEqual(26_967, search.perftTest(allocator, &pos, 4) catch unreachable);
    try expectEqual(585_494, search.perftTest(allocator, &pos, 5) catch unreachable);

    pos = try position.Position.setFen(&s, "8/8/8/2k5/3pP3/8/5B2/3K4 b - e3");
    try expectEqual(7, search.perftTest(allocator, &pos, 1) catch unreachable);
    try expectEqual(81, search.perftTest(allocator, &pos, 2) catch unreachable);
    try expectEqual(633, search.perftTest(allocator, &pos, 3) catch unreachable);
    try expectEqual(7_724, search.perftTest(allocator, &pos, 4) catch unreachable);
    try expectEqual(54_025, search.perftTest(allocator, &pos, 5) catch unreachable);
}

test "PerftEnPassantCheckPinnedPromotion" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, "2n5/r2PK3/1k6/8/8/8/8/8 w - -");
    try expectEqual(6, search.perftTest(allocator, &pos, 1) catch unreachable);
    try expectEqual(113, search.perftTest(allocator, &pos, 2) catch unreachable);
    try expectEqual(1_184, search.perftTest(allocator, &pos, 3) catch unreachable);
    try expectEqual(19_428, search.perftTest(allocator, &pos, 4) catch unreachable);
    try expectEqual(228_249, search.perftTest(allocator, &pos, 5) catch unreachable);

    pos = try position.Position.setFen(&s, "2p5/rP1K4/1k6/8/8/8/8/8 w - -");
    try expectEqual(6, search.perftTest(allocator, &pos, 1) catch unreachable);
    try expectEqual(94, search.perftTest(allocator, &pos, 2) catch unreachable);
    try expectEqual(980, search.perftTest(allocator, &pos, 3) catch unreachable);
    try expectEqual(13_897, search.perftTest(allocator, &pos, 4) catch unreachable);
    try expectEqual(154_327, search.perftTest(allocator, &pos, 5) catch unreachable);

    pos = try position.Position.setFen(&s, "kb1r4/2P5/3K4/8/8/8/8/8 w - -");
    try expectEqual(5, search.perftTest(allocator, &pos, 1) catch unreachable);
    try expectEqual(79, search.perftTest(allocator, &pos, 2) catch unreachable);
    try expectEqual(872, search.perftTest(allocator, &pos, 3) catch unreachable);
    try expectEqual(12_223, search.perftTest(allocator, &pos, 4) catch unreachable);
    try expectEqual(134_351, search.perftTest(allocator, &pos, 5) catch unreachable);
}

test "MovegenEnPassant" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, "4k3/8/8/3pPp2/8/8/8/4K3 w - d6 0 3");

    var list: std.ArrayListUnmanaged(types.Move) = .empty;
    defer list.deinit(allocator);

    pos.generateLegalMoves(allocator, pos.state.turn, &list);

    try expectEqual(7, list.items.len);
}

test "MovegenBishop" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, "3k4/8/8/B5BB/8/1B4B1/5B2/2BKB3 w - - 0 1");

    var list: std.ArrayListUnmanaged(types.Move) = .empty;
    defer list.deinit(allocator);

    pos.generateLegalMoves(allocator, pos.state.turn, &list);

    try expectEqual(52, list.items.len);
}

test "MovegenRook" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, "3k4/8/8/R5RR/8/1R4R1/5R2/2RKR3 w - - 0 1");

    var list: std.ArrayListUnmanaged(types.Move) = .empty;
    defer list.deinit(allocator);

    pos.generateLegalMoves(allocator, pos.state.turn, &list);

    try expectEqual(84, list.items.len);
}

test "MovegenSliders" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, "3k4/4R3/3B4/1Q6/8/5R2/2Q1B3/1Q1K1R2 w - - 0 1");

    var list: std.ArrayListUnmanaged(types.Move) = .empty;
    defer list.deinit(allocator);

    pos.generateLegalMoves(allocator, pos.state.turn, &list);

    try expectEqual(86, list.items.len);
}

test "MovegenKing" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, "3qkr2/8/8/8/8/8/8/4K3 w - - 0 1");

    var list: std.ArrayListUnmanaged(types.Move) = .empty;
    defer list.deinit(allocator);

    pos.generateLegalMoves(allocator, pos.state.turn, &list);

    try expectEqual(1, list.items.len);

    list.clearAndFree(allocator);

    pos = try position.Position.setFen(&s, "3qk3/8/8/8/8/8/8/R3K2R w KQ - 0 1");
    pos.generateLegalMoves(allocator, pos.state.turn, &list);

    try expectEqual(23, list.items.len);
}
