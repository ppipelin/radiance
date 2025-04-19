const std = @import("std");
const tables = @import("tables.zig");
const types = @import("types.zig");
const utils = @import("utils.zig");

const Bitboard = types.Bitboard;

const Magic = struct {
    ptr: [4096]Bitboard, // pointer to attack_table for each particular square
    mask: Bitboard, // to mask relevant squares of both lines (no outer squares)
    magic: Bitboard, // magic 64-bit factor
    shift: u6, // shift right

    fn computeIndex(self: Magic, blockers_: Bitboard) u12 {
        var blockers = blockers_;
        blockers &= self.mask;
        blockers = blockers *% self.magic;
        blockers >>= self.shift;
        return @truncate(blockers);
    }

    pub fn computeValue(self: Magic, blockers_: Bitboard) Bitboard {
        const ptr = self.ptr;
        var blockers = blockers_;
        blockers &= self.mask;
        blockers = blockers *% self.magic;
        blockers >>= self.shift;
        std.debug.assert(blockers < 4096);
        return ptr[blockers];
    }
};

// pub var moves_bishop: [types.board_size2][4096]Bitboard = std.mem.zeroes([types.board_size2][4096]Bitboard);
pub var magics_bishop: [types.board_size2]Magic = std.mem.zeroes([types.board_size2]Magic);

pub fn compute(allocator: std.mem.Allocator) void {
    // var prng = utils.PRNG.new(0x246C_CB2D_3B40_2853_9918_0A6D_BC3A_F444);
    const seed: u64 = @intCast(std.time.nanoTimestamp());
    var rng = std.Random.DefaultPrng.init(seed); // seed the RNG

    var sq = types.Square.a1;

    // Bishop
    while (sq != types.Square.none) : (sq = sq.inc().*) {
        var found: bool = false;

        var moves_bishop_blockers: std.ArrayListUnmanaged(Bitboard) = .empty;
        defer moves_bishop_blockers.deinit(allocator);

        moves_bishop_blockers.append(allocator, 0) catch unreachable;
        tables.computeBlockers(tables.moves_bishop_mask[sq.index()], &moves_bishop_blockers, allocator);
        while (!found) {
            found = true;
            // moves_bishop[sq.index()] = std.mem.zeroes([4096]Bitboard);
            magics_bishop[sq.index()] = Magic{ .ptr = std.mem.zeroes([4096]Bitboard), .mask = tables.moves_bishop_mask[sq.index()], .magic = rng.random().int(u64), .shift = 64 - 12 };
            // std.debug.print("magic {}", .{magic.magic});
            for (moves_bishop_blockers.items) |blockers| {
                const index = magics_bishop[sq.index()].computeIndex(blockers);
                const moves: Bitboard = tables.moves_bishop[sq.index()].get(tables.moves_bishop_mask[sq.index()] & blockers).?;
                if (magics_bishop[sq.index()].ptr[index] == 0) {
                    magics_bishop[sq.index()].ptr[index] = moves;
                    // std.debug.print("magic for blockers {}\n", .{blockers});
                } else if (magics_bishop[sq.index()].ptr[index] != moves) {
                    // std.debug.print("\nreset\n", .{});
                    found = false;
                    break;
                } else {
                    // found correlation
                    std.debug.print("found correlation\n", .{});
                }
            }
        }
        std.debug.print("found magic for sq {}\n", .{sq});
    }
}
