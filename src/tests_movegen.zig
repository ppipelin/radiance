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
    const stdout = std.io.getStdErr().writer();
    try expectEqual(20, search.perft(std.testing.allocator, stdout, &pos, 1, false) catch unreachable);
    try expectEqual(400, search.perft(std.testing.allocator, stdout, &pos, 2, false) catch unreachable);
    try expectEqual(8_902, search.perft(std.testing.allocator, stdout, &pos, 3, false) catch unreachable);
    try expectEqual(197_281, search.perft(std.testing.allocator, stdout, &pos, 4, false) catch unreachable);
    try expectEqual(4_865_609, search.perft(std.testing.allocator, stdout, &pos, 5, false) catch unreachable);
    // try expectEqual(119_060_324, search.perft(std.testing.allocator, stdout, &pos, 6, false) catch unreachable);
    // try expectEqual(3_195_901_860, search.perft(std.testing.allocator, stdout, &pos, 7, false) catch unreachable);
}

test "PerftKiwipete" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, position.kiwi_fen);

    const stdout = std.io.getStdErr().writer();
    try expectEqual(48, search.perft(std.testing.allocator, stdout, &pos, 1, false) catch unreachable);
    try expectEqual(2039, search.perft(std.testing.allocator, stdout, &pos, 2, false) catch unreachable);
    try expectEqual(97862, search.perft(std.testing.allocator, stdout, &pos, 3, false) catch unreachable);
    try expectEqual(4_085_603, search.perft(std.testing.allocator, stdout, &pos, 4, false) catch unreachable);
    // try expectEqual(193_690_690, search.perft(std.testing.allocator, stdout, &pos, 5, false) catch unreachable);
}

test "PerftPos3" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - -");

    const stdout = std.io.getStdErr().writer();
    try expectEqual(14, search.perft(std.testing.allocator, stdout, &pos, 1, false) catch unreachable);
    try expectEqual(191, search.perft(std.testing.allocator, stdout, &pos, 2, false) catch unreachable);
    try expectEqual(2_812, search.perft(std.testing.allocator, stdout, &pos, 3, false) catch unreachable);
    try expectEqual(43_238, search.perft(std.testing.allocator, stdout, &pos, 4, false) catch unreachable);
    try expectEqual(674_624, search.perft(std.testing.allocator, stdout, &pos, 5, false) catch unreachable);
}

test "PerftPos4" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1");

    const stdout = std.io.getStdErr().writer();
    try expectEqual(6, search.perft(std.testing.allocator, stdout, &pos, 1, false) catch unreachable);
    try expectEqual(264, search.perft(std.testing.allocator, stdout, &pos, 2, false) catch unreachable);
    try expectEqual(9_467, search.perft(std.testing.allocator, stdout, &pos, 3, false) catch unreachable);
    try expectEqual(422_333, search.perft(std.testing.allocator, stdout, &pos, 4, false) catch unreachable);
    // try expectEqual(15_833_292, search.perft(std.testing.allocator, stdout, &pos, 5, false) catch unreachable);
}

test "PerftPos5" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8");

    const stdout = std.io.getStdErr().writer();
    try expectEqual(44, search.perft(std.testing.allocator, stdout, &pos, 1, false) catch unreachable);
    try expectEqual(1_486, search.perft(std.testing.allocator, stdout, &pos, 2, false) catch unreachable);
    try expectEqual(62_379, search.perft(std.testing.allocator, stdout, &pos, 3, false) catch unreachable);
    try expectEqual(2_103_487, search.perft(std.testing.allocator, stdout, &pos, 4, false) catch unreachable);
    // try expectEqual(89_941_194, search.perft(std.testing.allocator, stdout, &pos, 5, false) catch unreachable);
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
