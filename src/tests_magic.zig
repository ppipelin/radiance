const magic = @import("magic.zig");
const tables = @import("tables.zig");
const std = @import("std");
const types = @import("types.zig");

const allocator = std.testing.allocator;

test "MovegenAccessions" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    const iterations: u8 = 1000;

    // Dictionary
    var t = std.time.Timer.start() catch unreachable;
    for (0..iterations) |_| {
        var sq: types.Square = types.Square.a1;
        while (sq != types.Square.none) : (sq = sq.inc().*) {
            var moves_bishop_blockers: std.ArrayListUnmanaged(types.Bitboard) = .empty;
            defer moves_bishop_blockers.deinit(allocator);

            moves_bishop_blockers.append(allocator, 0) catch unreachable;
            tables.computeBlockers(tables.moves_bishop_mask[sq.index()], &moves_bishop_blockers, allocator);

            for (moves_bishop_blockers.items) |blockers| {
                _ = tables.moves_bishop[sq.index()].get(tables.moves_bishop_mask[sq.index()] & blockers) orelse unreachable;
            }

            var moves_rook_blockers: std.ArrayListUnmanaged(types.Bitboard) = .empty;
            defer moves_rook_blockers.deinit(allocator);

            moves_rook_blockers.append(allocator, 0) catch unreachable;
            tables.computeBlockers(tables.moves_rook_mask[sq.index()], &moves_rook_blockers, allocator);

            for (moves_rook_blockers.items) |blockers| {
                _ = tables.moves_rook[sq.index()].get(tables.moves_rook_mask[sq.index()] & blockers) orelse unreachable;
            }
        }
    }
    const t1 = t.read();

    // Magic
    t = std.time.Timer.start() catch unreachable;
    var sq: types.Square = types.Square.a1;
    for (0..iterations) |_| {
        sq = types.Square.a1;
        while (sq != types.Square.none) : (sq = sq.inc().*) {
            var moves_bishop_blockers: std.ArrayListUnmanaged(types.Bitboard) = .empty;
            defer moves_bishop_blockers.deinit(allocator);

            moves_bishop_blockers.append(allocator, 0) catch unreachable;
            tables.computeBlockers(tables.moves_bishop_mask[sq.index()], &moves_bishop_blockers, allocator);

            for (moves_bishop_blockers.items) |blockers| {
                _ = magic.magics_bishop[sq.index()].computeValue(blockers);
            }

            var moves_rook_blockers: std.ArrayListUnmanaged(types.Bitboard) = .empty;
            defer moves_rook_blockers.deinit(allocator);

            moves_rook_blockers.append(allocator, 0) catch unreachable;
            tables.computeBlockers(tables.moves_rook_mask[sq.index()], &moves_rook_blockers, allocator);

            for (moves_rook_blockers.items) |blockers| {
                _ = magic.magics_rook[sq.index()].computeValue(blockers);
            }
        }
    }
    const t2 = t.read();
    std.testing.expect(t2 < t1);
}
