const evaluate = @import("evaluate.zig");
const position = @import("position.zig");
const std = @import("std");
const tables = @import("tables.zig");
const types = @import("types.zig");

test "EvaluateFlip" {
    tables.initAll(std.testing.allocator);
    defer tables.deinitAll(std.testing.allocator);

    var fen_w: []const u8 = "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1";
    var fen_b: []const u8 = "r2q1rk1/pP1p2pp/Q4n2/bbp1p3/Np6/1B3NBn/pPPP1PPP/R3K2R b KQ - 0 1";

    var s_w: position.State = position.State{};
    var pos_w: position.Position = try position.Position.setFen(&s_w, fen_w);
    var s_b: position.State = position.State{};
    var pos_b: position.Position = try position.Position.setFen(&s_b, fen_b);

    try std.testing.expectEqual(evaluate.evaluateShannon(pos_w), evaluate.evaluateShannon(pos_b));
    try std.testing.expectEqual(evaluate.evaluateTable(pos_w), evaluate.evaluateTable(pos_b));

    fen_w = "5k2/2p1pp2/p7/8/8/PPPPPPPP/PPPPPPPP/bnnb1K1b w - - 0 1";
    fen_b = "BNNB1k1B/pppppppp/pppppppp/8/8/P7/2P1PP2/5K2 b - - 0 1";

    pos_w = try position.Position.setFen(&s_w, fen_w);
    pos_b = try position.Position.setFen(&s_b, fen_b);

    try std.testing.expectEqual(evaluate.evaluateShannon(pos_w), evaluate.evaluateShannon(pos_b));
    try std.testing.expectEqual(evaluate.evaluateTable(pos_w), evaluate.evaluateTable(pos_b));

    fen_w = "r1bq1r1k/pp1npp1p/2np2p1/2p5/4P3/2bPBNP1/PPP2PBP/R2Q1R1K w - - 0 1";
    fen_b = "r2q1r1k/ppp2pbp/2Bpbnp1/4p3/2P5/2NP2P1/PP1NPP1P/R1BQ1R1K b - - 0 1";

    pos_w = try position.Position.setFen(&s_w, fen_w);
    pos_b = try position.Position.setFen(&s_b, fen_b);

    try std.testing.expectEqual(evaluate.evaluateShannon(pos_w), evaluate.evaluateShannon(pos_b));
    try std.testing.expectEqual(evaluate.evaluateTable(pos_w), evaluate.evaluateTable(pos_b));

    fen_w = "6k1/5p2/p1p2Bp1/P4n1p/1P2p3/6PP/3R2PK/2r5 b - -";
    fen_b = "2R5/3r2pk/6pp/1p2P3/p4N1P/P1P2bP1/5P2/6K1 w - -";

    pos_w = try position.Position.setFen(&s_w, fen_w);
    pos_b = try position.Position.setFen(&s_b, fen_b);

    try std.testing.expectEqual(evaluate.evaluateShannon(pos_w), evaluate.evaluateShannon(pos_b));
    try std.testing.expectEqual(evaluate.evaluateTable(pos_w), evaluate.evaluateTable(pos_b));
}

test "EvaluateTable" {
    tables.initAll(std.testing.allocator);
    defer tables.deinitAll(std.testing.allocator);

    const fen: []const u8 = "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1";

    var s: position.State = position.State{};
    const pos: position.Position = try position.Position.setFen(&s, fen);

    try std.testing.expectEqual(evaluate.evaluateTable(pos), evaluate.evaluateTable(pos));
}

test "EvaluatePawnHeuristics" {
    tables.initAll(std.testing.allocator);
    defer tables.deinitAll(std.testing.allocator);

    const fen: []const u8 = "3k4/7p/3p2P1/3P2P1/P6P/P7/P1P3P1/3K4 w - -";

    var s: position.State = position.State{};
    const pos: position.Position = try position.Position.setFen(&s, fen);

    const bb_white: types.Bitboard = pos.bb_pieces[types.PieceType.pawn.index()] & pos.bb_colors[types.Color.white.index()];
    const bb_black: types.Bitboard = pos.bb_pieces[types.PieceType.pawn.index()] & pos.bb_colors[types.Color.black.index()];

    try std.testing.expectEqual(6, evaluate.computeDoubledPawns(bb_white));
    try std.testing.expectEqual(1, evaluate.computeBlockedPawns(bb_white, types.Color.white, bb_black));
    try std.testing.expectEqual(3, evaluate.computeIsolatedPawns(bb_white));
}
