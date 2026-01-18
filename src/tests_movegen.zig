//! This module provides tests for move generation of the program

const movepick = @import("movepick.zig");
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
    try expectEqual(20, search.perftTest(allocator, &pos, 1, false) catch unreachable);
    try expectEqual(400, search.perftTest(allocator, &pos, 2, false) catch unreachable);
    try expectEqual(8_902, search.perftTest(allocator, &pos, 3, false) catch unreachable);
    try expectEqual(197_281, search.perftTest(allocator, &pos, 4, false) catch unreachable);
    try expectEqual(4_865_609, search.perftTest(allocator, &pos, 5, false) catch unreachable);
    // try expectEqual(119_060_324, search.perftTest(allocator, &pos, 6, false) catch unreachable);
    // try expectEqual(3_195_901_860, search.perftTest(allocator, &pos, 7, false) catch unreachable);
}

test "PerftKiwipete" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, position.kiwi_fen);
    try expectEqual(48, search.perftTest(allocator, &pos, 1, false) catch unreachable);
    try expectEqual(2039, search.perftTest(allocator, &pos, 2, false) catch unreachable);
    try expectEqual(97862, search.perftTest(allocator, &pos, 3, false) catch unreachable);
    try expectEqual(4_085_603, search.perftTest(allocator, &pos, 4, false) catch unreachable);
    // try expectEqual(193_690_690, search.perftTest(allocator, &pos, 5, false) catch unreachable);
}

test "PerftPos3" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - -");
    try expectEqual(14, search.perftTest(allocator, &pos, 1, false) catch unreachable);
    try expectEqual(191, search.perftTest(allocator, &pos, 2, false) catch unreachable);
    try expectEqual(2_812, search.perftTest(allocator, &pos, 3, false) catch unreachable);
    try expectEqual(43_238, search.perftTest(allocator, &pos, 4, false) catch unreachable);
    try expectEqual(674_624, search.perftTest(allocator, &pos, 5, false) catch unreachable);
}

test "PerftPos4" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1");
    try expectEqual(6, search.perftTest(allocator, &pos, 1, false) catch unreachable);
    try expectEqual(264, search.perftTest(allocator, &pos, 2, false) catch unreachable);
    try expectEqual(9_467, search.perftTest(allocator, &pos, 3, false) catch unreachable);
    try expectEqual(422_333, search.perftTest(allocator, &pos, 4, false) catch unreachable);
    // try expectEqual(15_833_292, search.perftTest(allocator, &pos, 5, false) catch unreachable);
}

test "PerftPos5" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8");
    try expectEqual(44, search.perftTest(allocator, &pos, 1, false) catch unreachable);
    try expectEqual(1_486, search.perftTest(allocator, &pos, 2, false) catch unreachable);
    try expectEqual(62_379, search.perftTest(allocator, &pos, 3, false) catch unreachable);
    try expectEqual(2_103_487, search.perftTest(allocator, &pos, 4, false) catch unreachable);
    // try expectEqual(89_941_194, search.perftTest(allocator, &pos, 5, false) catch unreachable);
}

test "PerftMoveCastleAddress" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, "2bq1rk1/1pp2pbp/3p2p1/3Pn3/1PPBP1P1/2N4P/5PB1/3QK2R b K -");
    try expectEqual(30, search.perftTest(allocator, &pos, 1, false) catch unreachable);
    try expectEqual(998, search.perftTest(allocator, &pos, 2, false) catch unreachable);
    try expectEqual(31_067, search.perftTest(allocator, &pos, 3, false) catch unreachable);
    try expectEqual(1_057_671, search.perftTest(allocator, &pos, 4, false) catch unreachable);

    pos = try position.Position.setFen(&s, "3q1rk1/1pp2pbp/3p2p1/3Pnb2/1PPBP1P1/2N4P/5PB1/3QK2R w K - 1 2");
    try expectEqual(37, search.perftTest(allocator, &pos, 1, false) catch unreachable);
    try expectEqual(1_205, search.perftTest(allocator, &pos, 2, false) catch unreachable);
    try expectEqual(42_491, search.perftTest(allocator, &pos, 3, false) catch unreachable);
    try expectEqual(1_398_494, search.perftTest(allocator, &pos, 4, false) catch unreachable);
    try expectEqual(49_583_496, search.perftTest(allocator, &pos, 5, false) catch unreachable);

    pos = try position.Position.setFen(&s, "3q1rk1/1pp2pbp/3p2p1/3Pn3/1PPB2P1/2NB3P/5P2/3QK2b w - -");
    try expectEqual(36, search.perftTest(allocator, &pos, 1, false) catch unreachable);
    try expectEqual(1_175, search.perftTest(allocator, &pos, 2, false) catch unreachable);
}

test "PerftPin" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, "3K4/4Pp2/5q2/8/3k4/8/8/8 w - -");
    try expectEqual(4, search.perftTest(allocator, &pos, 1, false) catch unreachable);
    try expectEqual(104, search.perftTest(allocator, &pos, 2, false) catch unreachable);
    try expectEqual(673, search.perftTest(allocator, &pos, 3, false) catch unreachable);
    try expectEqual(18_786, search.perftTest(allocator, &pos, 4, false) catch unreachable);
}

test "PerftEnPassantCheckPinned" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, "2r5/4R3/5pp1/2n2k1p/p4pPP/8/2P5/2K2R2 b - g3");
    try expectEqual(2, search.perftTest(allocator, &pos, 1, false) catch unreachable);
    try expectEqual(55, search.perftTest(allocator, &pos, 2, false) catch unreachable);
    try expectEqual(1_144, search.perftTest(allocator, &pos, 3, false) catch unreachable);
    try expectEqual(26_967, search.perftTest(allocator, &pos, 4, false) catch unreachable);
    try expectEqual(585_494, search.perftTest(allocator, &pos, 5, false) catch unreachable);

    pos = try position.Position.setFen(&s, "8/8/8/2k5/3pP3/8/5B2/3K4 b - e3");
    try expectEqual(7, search.perftTest(allocator, &pos, 1, false) catch unreachable);
    try expectEqual(81, search.perftTest(allocator, &pos, 2, false) catch unreachable);
    try expectEqual(633, search.perftTest(allocator, &pos, 3, false) catch unreachable);
    try expectEqual(7_724, search.perftTest(allocator, &pos, 4, false) catch unreachable);
    try expectEqual(54_025, search.perftTest(allocator, &pos, 5, false) catch unreachable);
}

test "PerftEnPassantCheckPinnedPromotion" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, "2n5/r2PK3/1k6/8/8/8/8/8 w - -");
    try expectEqual(6, search.perftTest(allocator, &pos, 1, false) catch unreachable);
    try expectEqual(113, search.perftTest(allocator, &pos, 2, false) catch unreachable);
    try expectEqual(1_184, search.perftTest(allocator, &pos, 3, false) catch unreachable);
    try expectEqual(19_428, search.perftTest(allocator, &pos, 4, false) catch unreachable);
    try expectEqual(228_249, search.perftTest(allocator, &pos, 5, false) catch unreachable);

    pos = try position.Position.setFen(&s, "2p5/rP1K4/1k6/8/8/8/8/8 w - -");
    try expectEqual(6, search.perftTest(allocator, &pos, 1, false) catch unreachable);
    try expectEqual(94, search.perftTest(allocator, &pos, 2, false) catch unreachable);
    try expectEqual(980, search.perftTest(allocator, &pos, 3, false) catch unreachable);
    try expectEqual(13_897, search.perftTest(allocator, &pos, 4, false) catch unreachable);
    try expectEqual(154_327, search.perftTest(allocator, &pos, 5, false) catch unreachable);

    pos = try position.Position.setFen(&s, "kb1r4/2P5/3K4/8/8/8/8/8 w - -");
    try expectEqual(5, search.perftTest(allocator, &pos, 1, false) catch unreachable);
    try expectEqual(79, search.perftTest(allocator, &pos, 2, false) catch unreachable);
    try expectEqual(872, search.perftTest(allocator, &pos, 3, false) catch unreachable);
    try expectEqual(12_223, search.perftTest(allocator, &pos, 4, false) catch unreachable);
    try expectEqual(134_351, search.perftTest(allocator, &pos, 5, false) catch unreachable);
}

test "PerftQueens" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, "4k3/pppppppp/8/QQQQQQQQ/8/QQQQQQQQ/8/4K3 w - - 0 1");
    try expectEqual(130, search.perftTest(allocator, &pos, 1, false) catch unreachable);
    try expectEqual(1009, search.perftTest(allocator, &pos, 2, false) catch unreachable);
    try expectEqual(134_922, search.perftTest(allocator, &pos, 3, false) catch unreachable);
    try expectEqual(1_088_511, search.perftTest(allocator, &pos, 4, false) catch unreachable);
}

test "SeeBasicQueen" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    const pos: position.Position = try position.Position.setFen(&s, "1k1r4/1pp4p/p7/4q3/8/P5P1/1PP4P/2K1R3 w");

    try std.testing.expect(search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "e1e5"), -100));
    try std.testing.expect(search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "e1e5"), 0));
    try std.testing.expect(search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "e1e5"), 100));
    try std.testing.expect(search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "e1e5"), tables.material[types.PieceType.queen.index()]));
    try std.testing.expect(!search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "e1e5"), tables.material[types.PieceType.queen.index()] + 1));
}

test "SeeBasicPawn" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};

    const pos: position.Position = try position.Position.setFen(&s, "1k1r4/1pp4p/p7/4p3/8/P5P1/1PP4P/2K1R3 w");

    try std.testing.expect(search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "e1e5"), -100));
    try std.testing.expect(search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "e1e5"), 0));
    try std.testing.expect(search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "e1e5"), tables.material[types.PieceType.pawn.index()]));
    try std.testing.expect(!search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "e1e5"), tables.material[types.PieceType.pawn.index()] + 1));
}

test "SeeComplex" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    const pos: position.Position = try position.Position.setFen(&s, "3k4/8/6rn/8/6p1/5P2/4Q3/3K2R1 w");

    try std.testing.expect(search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "f3g4"), -100));
    try std.testing.expect(search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "f3g4"), 0));
    try std.testing.expect(search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "f3g4"), tables.material[types.PieceType.pawn.index()]));
    try std.testing.expect(!search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "f3g4"), tables.material[types.PieceType.pawn.index()] + 1));

    // Rook takes first is negative
    try std.testing.expect(search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "g1g4"), -tables.material[types.PieceType.rook.index()] + tables.material[types.PieceType.knight.index()] + tables.material[types.PieceType.pawn.index()]));
    try std.testing.expect(!search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "g1g4"), -tables.material[types.PieceType.rook.index()] + tables.material[types.PieceType.knight.index()] + tables.material[types.PieceType.pawn.index()] + 1));
    try std.testing.expect(!search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "g1g4"), 0));
}

test "SeeComplexNoCapture" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    const pos: position.Position = try position.Position.setFen(&s, "3k4/8/6rn/8/8/6P1/4Q3/3K2R1 w");

    try std.testing.expect(search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "g3g4"), -100));
    try std.testing.expect(search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "g3g4"), 0));
    try std.testing.expect(!search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "g3g4"), 1));
}

test "SeeComplexNoCaptureLoss" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    const pos: position.Position = try position.Position.setFen(&s, "3k4/8/6rn/7b/8/6P1/4Q3/3K2R1 w");

    try std.testing.expect(search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "g3g4"), -tables.material[types.PieceType.pawn.index()]));
    try std.testing.expect(!search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "g3g4"), 0));
}

test "SeePin" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    const pos: position.Position = try position.Position.setFen(&s, "kr3r2/6nb/6b1/1Q3p2/4P3/3B4/2B5/1K3R2 w");

    try std.testing.expect(search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "e4f5"), -tables.material[types.PieceType.pawn.index()]));
    try std.testing.expect(search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "e4f5"), 0));
    try std.testing.expect(!search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "e4f5"), tables.material[types.PieceType.pawn.index()]));
}

test "SeePin2" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    const pos: position.Position = try position.Position.setFen(&s, "k7/6b1/5b2/4p1q1/3B1Q2/2B1K1B1/8/8 w");

    try std.testing.expect(search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "d4e5"), -tables.material[types.PieceType.bishop.index()] + tables.material[types.PieceType.pawn.index()]));
    try std.testing.expect(!search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "d4e5"), -tables.material[types.PieceType.pawn.index()]));
}

test "SeePinUpdate" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    const pos: position.Position = try position.Position.setFen(&s, "k7/6b1/3B1b2/4p1q1/3B1Q2/2B1K3/8/8 w");

    try std.testing.expect(search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "d4e5"), 0));
    try std.testing.expect(search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "d4e5"), tables.material[types.PieceType.pawn.index()]));
}

test "SeePinUpdate2" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    const pos: position.Position = try position.Position.setFen(&s, "k7/6b1/3B1b2/4p1qr/3B1Q2/2B1K3/8/8 w");

    try std.testing.expect(!search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "d4e5"), 0));
    try std.testing.expect(!search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "d4e5"), tables.material[types.PieceType.pawn.index()]));
}

test "SeePinUpdate3" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    const pos: position.Position = try position.Position.setFen(&s, "k7/6b1/3B1b2/4p1qr/3B1B2/2B1K3/8/8 w");

    try std.testing.expect(search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "d4e5"), -tables.material[types.PieceType.bishop.index()] + tables.material[types.PieceType.pawn.index()]));
    try std.testing.expect(search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "d4e5"), tables.material[types.PieceType.pawn.index()]));
    try std.testing.expect(!search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "d4e5"), tables.material[types.PieceType.pawn.index()] + 1));
}

test "SeePinUpdate4" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    const pos: position.Position = try position.Position.setFen(&s, "2k5/8/8/8/8/4q1B1/3Q4/2K1Q1q1 b");

    try std.testing.expect(search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "g1e1"), 0));
    try std.testing.expect(!search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "g1e1"), 1));
}

test "MovegenEnPassant" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, "4k3/8/8/3pPp2/8/8/8/4K3 w - d6 0 3");

    var move_list: [types.max_moves]types.Move = @splat(.none);
    var move_len: usize = 0;

    pos.updateAttacked(false);
    pos.generateLegalMoves(types.GenerationType.all, .white, &move_list, &move_len, false);

    try expectEqual(7, move_len);
}

test "MovegenBishop" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, "2k5/8/8/B5BB/8/1B4B1/5B2/2BKB3 w - - 0 1");

    var move_list: [types.max_moves]types.Move = @splat(.none);
    var move_len: usize = 0;

    pos.updateAttacked(false);
    pos.generateLegalMoves(types.GenerationType.all, .white, &move_list, &move_len, false);

    try expectEqual(52, move_len);
}

test "MovegenRook" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, "3k4/8/8/R5RR/8/1R4R1/5R2/2RKR3 w - - 0 1");

    var move_list: [types.max_moves]types.Move = @splat(.none);
    var move_len: usize = 0;

    pos.updateAttacked(false);
    pos.generateLegalMoves(types.GenerationType.all, .white, &move_list, &move_len, false);

    try expectEqual(84, move_len);
}

test "MovegenSliders" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, "3k4/4R3/3B4/1Q6/8/5R2/2Q1B3/1Q1K1R2 w - - 0 1");

    var move_list: [types.max_moves]types.Move = @splat(.none);
    var move_len: usize = 0;

    pos.updateAttacked(false);
    pos.generateLegalMoves(types.GenerationType.all, .white, &move_list, &move_len, false);

    try expectEqual(86, move_len);
}

test "MovegenKing" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, "3qkr2/8/8/8/8/8/8/4K3 w - - 0 1");

    var move_list: [types.max_moves]types.Move = @splat(.none);
    var move_len: usize = 0;

    pos.updateAttacked(false);
    pos.generateLegalMoves(types.GenerationType.all, .white, &move_list, &move_len, false);

    try expectEqual(1, move_len);

    move_list = @splat(.none);
    move_len = 0;
    pos = try position.Position.setFen(&s, "3qk3/8/8/8/8/8/8/R3K2R w KQ - 0 1");

    pos.updateAttacked(false);
    pos.generateLegalMoves(types.GenerationType.all, .white, &move_list, &move_len, false);

    try expectEqual(23, move_len);
}

test "MovepickMvvLva" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var output: [4096]u8 = undefined;
    var stdout = std.Io.Writer.fixed(&output);

    var mp: movepick.MovePick = .{};
    defer mp.deinit();

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, "4k3/8/7p/3q2B1/8/8/1K6/2rR2p1 w - -");

    var move: types.Move = try mp.nextMove(&pos, .none, false);
    while (move != types.Move.none) : (move = try mp.nextMove(&pos, .none, false)) {
        try types.Move.printUCI(move, &stdout);
    }
    var buffer_out: []u8 = stdout.buffered();
    try std.testing.expectStringStartsWith(buffer_out, "d1d5g5c1d1c1");
    // try std.testing.expectStringEndsWith(stdout.buffered(), "g5h6d1g1b2c1"); // Works when there is no SEE

    // Reset
    _ = stdout.consumeAll();
    mp.deinit();
    mp = .{};

    pos = try position.Position.setFen(&s, "3k4/8/6rn/8/6p1/5P2/4Q3/3K2R1 w");

    move = try mp.nextMove(&pos, .none, false);
    while (move != types.Move.none) : (move = try mp.nextMove(&pos, .none, false)) {
        try types.Move.printUCI(move, &stdout);
    }

    buffer_out = stdout.buffered();
    try std.testing.expectStringStartsWith(buffer_out, "f3g4");
    try std.testing.expectStringEndsWith(buffer_out, "g1g4");
}

test "MovepickSee" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var output: [4096]u8 = undefined;
    var stdout = std.Io.Writer.fixed(&output);

    var mp: movepick.MovePick = .{};
    defer mp.deinit();

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, "3kr3/8/4r1rn/8/4p1p1/5B1P/4Q3/3K2R1 w"); // win with second pawn

    var move: types.Move = try mp.nextMove(&pos, .none, false);
    while (move != types.Move.none) : (move = try mp.nextMove(&pos, .none, false)) {
        try types.Move.printUCI(move, &stdout);
    }

    const buffer_out: []u8 = stdout.buffered();
    try std.testing.expectStringStartsWith(buffer_out, "h3g4f3g4");
    // try std.testing.expectStringEndsWith(buffer_out, "g1g4f3e4"); // Bad captures (See < 0) are not sorted by SEE

    pos = try position.Position.setFen(&s, "3k1r2/5r2/8/5n2/4b1B1/7B/5R2/3K1R2 w");

    mp.deinit();
    mp = .{};
    _ = stdout.consumeAll();

    move = try mp.nextMove(&pos, .none, false);
    while (move != types.Move.none) : (move = try mp.nextMove(&pos, .none, false)) {
        try types.Move.printUCI(move, &stdout);
    }

    try std.testing.expectStringStartsWith(buffer_out, "g4f5f2f5");

    pos = try position.Position.setFen(&s, "3k1r2/5r2/5r2/5n2/4b1B1/7B/5R2/3K1R2 w");

    mp.deinit();
    mp = .{};
    _ = stdout.consumeAll();

    move = try mp.nextMove(&pos, .none, false);
    while (move != types.Move.none) : (move = try mp.nextMove(&pos, .none, false)) {
        try types.Move.printUCI(move, &stdout);
    }

    try std.testing.expect(!std.mem.eql(u8, buffer_out, "g4f5"));
}
