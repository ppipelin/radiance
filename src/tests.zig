//! This module provides tests for key components of the program

const position = @import("position.zig");
const std = @import("std");
const tables = @import("tables.zig");
const types = @import("types.zig");

const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;

const allocator = std.testing.allocator;

test "Position" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = position.Position.init(&s);
    try expectEqual(0, pos.state.material_key);
    try expectEqual(types.Color.white, pos.state.turn);
    try expectEqual(1, pos.state.full_move);
    try expectEqual(types.Piece.none, pos.board[0]);

    pos.add(types.Piece.w_knight, types.Square.f3);
    try expectEqual(types.Piece.w_knight, pos.board[types.Square.f3.index()]);
    try expectEqual(0x200000, pos.bb_pieces[types.PieceType.knight.index()]);

    pos.remove(types.Piece.w_knight, types.Square.f3);
    try expectEqual(types.Piece.none, pos.board[types.Square.f3.index()]);
    try expectEqual(0, pos.bb_pieces[types.PieceType.knight.index()]);
}

test "Fen" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    const fen: []const u8 = position.start_fen;
    var pos: position.Position = try position.Position.setFen(&s, fen);

    var buffer: [90]u8 = undefined;
    const computed_fen = pos.getFen(&buffer);

    try expectEqualSlices(u8, fen, computed_fen);
}

test "FenIncomplete" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    const fen: []const u8 = position.start_fen[0..45];
    var pos: position.Position = try position.Position.setFen(&s, fen);

    var buffer: [90]u8 = undefined;
    const computed_fen = pos.getFen(&buffer);

    try std.testing.expectStringStartsWith(computed_fen, fen);
}

test "FenMoved" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    const fen: []const u8 = "rnbqkb1r/pppppppp/5n2/8/8/5N2/PPPPPPPP/RNBQKB1R w KQkq - 100 100";
    var pos: position.Position = try position.Position.setFen(&s, fen);

    var buffer: [90]u8 = undefined;
    const computed_fen = pos.getFen(&buffer);

    try expectEqualSlices(u8, fen, computed_fen);
}

test "Move" {
    try expectEqual(2, @sizeOf(types.Move));
    try expectEqual(16, @bitSizeOf(types.Move));
}

test "MoveUnmovePiece" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, position.start_fen);

    var s2: position.State = position.State{};
    try pos.movePiece(types.Move.init(types.MoveFlags.quiet, types.Square.a2, types.Square.a3), &s2);

    var s3: position.State = position.State{};
    try pos.movePiece(types.Move.init(types.MoveFlags.quiet, types.Square.e7, types.Square.e6), &s3);

    try pos.unMovePiece(types.Move.init(types.MoveFlags.quiet, types.Square.e7, types.Square.e6), false);

    try pos.unMovePiece(types.Move.init(types.MoveFlags.quiet, types.Square.a2, types.Square.a3), false);

    var buffer: [90]u8 = undefined;
    const computed_fen = pos.getFen(&buffer);

    try expectEqualSlices(u8, position.start_fen, computed_fen);
}
