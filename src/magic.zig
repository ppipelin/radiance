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
        std.debug.assert(blockers < 4096);
        return @truncate(blockers);
    }

    pub fn computeValue(self: Magic, blockers_: Bitboard) Bitboard {
        const index = self.computeIndex(blockers_);
        return self.ptr[index];
    }
};

pub var magics_bishop: [types.board_size2]Magic = std.mem.zeroes([types.board_size2]Magic);
pub var magics_rook: [types.board_size2]Magic = std.mem.zeroes([types.board_size2]Magic);
pub var collisions_found_bishop: [types.board_size2]u12 = std.mem.zeroes([types.board_size2]u12);
pub var collisions_found_rook: [types.board_size2]u12 = std.mem.zeroes([types.board_size2]u12);

pub fn compute(allocator: std.mem.Allocator) void {
    const seed: u64 = @intCast(std.time.nanoTimestamp());
    var prng = std.Random.DefaultPrng.init(seed);

    var sq = types.Square.a1;
    while (sq != types.Square.none) : (sq = sq.inc().*) {
        generateMagic(allocator, &magics_bishop[sq.index()], sq, tables.moves_bishop_mask[sq.index()], tables.getBishopAttacks, bishop_bits, &prng);

        generateMagic(allocator, &magics_rook[sq.index()], sq, tables.moves_rook_mask[sq.index()], tables.getRookAttacks, rook_bits, &prng);

        std.debug.print("found magic for sq {}\n", .{sq});
    }
}

const rook_bits = [types.board_size2]u8{
    12, 11, 11, 11, 11, 11, 11, 12,
    11, 10, 10, 10, 10, 10, 10, 11,
    11, 10, 10, 10, 10, 10, 10, 11,
    11, 10, 10, 10, 10, 10, 10, 11,
    11, 10, 10, 10, 10, 10, 10, 11,
    11, 10, 10, 10, 10, 10, 10, 11,
    11, 10, 10, 10, 10, 10, 10, 11,
    12, 11, 11, 11, 11, 11, 11, 12,
};

const bishop_bits = [types.board_size2]u8{
    6, 5, 5, 5, 5, 5, 5, 6,
    5, 5, 5, 5, 5, 5, 5, 5,
    5, 5, 7, 7, 7, 7, 5, 5,
    5, 5, 7, 9, 9, 7, 5, 5,
    5, 5, 7, 9, 9, 7, 5, 5,
    5, 5, 7, 7, 7, 7, 5, 5,
    5, 5, 5, 5, 5, 5, 5, 5,
    6, 5, 5, 5, 5, 5, 5, 6,
};

fn generateMagic(allocator: std.mem.Allocator, magic_out: *Magic, sq: types.Square, mask: Bitboard, getAttacks: fn (types.Square, Bitboard) Bitboard, bits: [types.board_size2]u8, prng: *std.Random.DefaultPrng) void {
    var blockers: std.ArrayListUnmanaged(Bitboard) = .empty;
    defer blockers.deinit(allocator);

    blockers.append(allocator, 0) catch unreachable;
    tables.computeBlockers(mask, &blockers, allocator);

    while (true) {
        var magic = Magic{
            .ptr = std.mem.zeroes([4096]Bitboard),
            .mask = mask,
            .magic = prng.random().int(u64) & prng.random().int(u64) & prng.random().int(u64),
            .shift = @truncate(64 - bits[sq.index()]),
        };

        var valid = true;
        for (blockers.items) |blocker| {
            const index = magic.computeIndex(blocker);
            if (index > magic.ptr.len) {
                valid = false;
                break;
            }
            const moves = getAttacks(sq, blocker);
            if (magic.ptr[index] == 0) {
                magic.ptr[index] = moves;
            } else if (magic.ptr[index] != moves) {
                valid = false;
                break;
            } else {
                // std.debug.print("constructive collision\n", .{});
            }
        }

        if (valid) {
            magic_out.* = magic;
            break;
        }
    }
}
