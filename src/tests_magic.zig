const magic = @import("magic.zig");
const tables = @import("tables.zig");
const std = @import("std");
const types = @import("types.zig");

const allocator = std.testing.allocator;

test "MovegenAccessions" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    const iterations: u64 = 1000;

    // Dictionary
    var t = std.time.Timer.start() catch unreachable;
    for (0..iterations) |_| {
        var sq: types.Square = types.Square.a1;
        while (sq != types.Square.none) : (sq = sq.inc().*) {
            const moves_bishop_blockers = tables.computeBlockersComptime(tables.moves_bishop_mask[sq.index()]);
            for (moves_bishop_blockers) |blockers| {
                _ = tables.moves_bishop[sq.index()].get(tables.moves_bishop_mask[sq.index()] & blockers) orelse unreachable;
            }

            const moves_rook_blockers = tables.computeBlockersComptime(tables.moves_rook_mask[sq.index()]);
            for (moves_rook_blockers) |blockers| {
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
            const moves_bishop_blockers = tables.computeBlockersComptime(tables.moves_bishop_mask[sq.index()]);
            for (moves_bishop_blockers) |blockers| {
                _ = magic.magics_bishop[sq.index()].computeValue(blockers);
            }

            const moves_rook_blockers = tables.computeBlockersComptime(tables.moves_rook_mask[sq.index()]);
            for (moves_rook_blockers) |blockers| {
                _ = magic.magics_rook[sq.index()].computeValue(blockers);
            }
        }
    }
    const t2 = t.read();
    try std.testing.expect(t2 < t1);
}
