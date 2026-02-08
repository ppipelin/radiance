const std = @import("std");
const tables = @import("tables.zig");
const types = @import("types.zig");

const Bitboard = types.Bitboard;

const Magic = struct {
    ptr: ?[*]Bitboard, // pointer to magic_holder for each particular square
    mask: Bitboard,
    magic: Bitboard,
    shift: u6,

    fn computeIndex(self: Magic, blockers_: Bitboard) u12 {
        var blockers = blockers_;
        blockers &= self.mask;
        blockers = blockers *% self.magic;
        blockers >>= self.shift;
        std.debug.assert(blockers < @as(u64, 1) << @truncate(64 - @as(usize, self.shift)));
        return @truncate(blockers);
    }

    pub fn computeValue(self: Magic, blockers_: Bitboard) Bitboard {
        const index = self.computeIndex(blockers_);
        return self.ptr.?[index];
    }

    fn nnz(self: Magic) u16 {
        var count: u16 = 0;
        for (0..(@as(u64, 1) << @truncate(64 - @as(usize, self.shift)))) |val| {
            if (self.ptr.?[val] != 0) count += 1;
        }
        return count;
    }

    const empty: Magic = .{
        .ptr = null,
        .mask = 0,
        .magic = 0,
        .shift = 0,
    };
};

// Contains all magic numbers
// Ordered such as [a1: bishop rook, a2: bishop rook...]
// sum(2.^bishop_bits + 2.^rook_bits)
var magic_holder: [107648]Bitboard = @splat(0);
var magic_holder_tmp: [107648]Bitboard = @splat(0);
pub var magics_bishop: [types.board_size2]Magic = undefined;
pub var magics_rook: [types.board_size2]Magic = undefined;

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

const magic_numbers: [types.board_size2 * 2]u64 = [_]u64{
    0x3505000ea8080,    0x410a11c401da0000, 0x244c300a060a004,  0x11b86047d0080002, 0x49c04e1c1200400,  0x120206b22004000a, 0x48a29210101f0000, 0x10945a0110610404,
    0x440070e98020404,  0x20203140800e108,  0xa0808122421e802,  0x800482591004411,  0x40008c10c4c16004, 0x208041c289140000, 0x297210e20840,     0x68220c63f80,
    0x22200006208d2148, 0x50026101c18090,   0x111100112a100,    0x840040403fa00,    0x200100882018011a, 0x202000100614304,  0x102020861502680,  0x8900c194034902,
    0x2050810a164a80,   0x442040109e9080,   0x10480011021400,   0x60b3080011004100, 0x60408c0040802000, 0x4802e036008400,   0xa0040400012c8682, 0x2009041cc0390,
    0x394ca200c08810,   0x641432300200840,  0x100305002080180,  0x1081010800010040, 0x40010010110240,   0x48100020441200,   0x847034b20020800,  0x3000919a88020604,
    0x2650486714000,    0x443e80209011028,  0x110182830000800,  0x800006124080804,  0xc20102010412200,  0x100301406a000100, 0x1003220b41210452, 0x8044803dd160440,
    0x18409c410067100,  0x42cfc0402230000,  0x9163d844502008,   0x8100a02309c81804, 0x1c682350160a2140, 0x80000c2828684020, 0x9420600401a8b800, 0x31704080200b000,
    0x41008201f0024828, 0x4403fa081c0280,   0x210201aca443058,  0x4010820114880c,   0x809084b0410,      0x22080604e22ea00,  0x300020183041c060, 0x4094100bc801023c,
    0x1480057040002087, 0x840002000401002,  0x85001108200100c0, 0x8200062200144013, 0x8600031005200600, 0x4880040001800200, 0x4500090011846200, 0x100028202a45500,
    0x2118401042202010, 0x400448a01002,     0x15002000f30840,   0x3012000e00184012, 0x4012001a12020408, 0x5005400070008,    0x8020028118c4200,  0x2101020204081,
    0x8280084001200841, 0xc400b8020004083,  0x12020024413282,   0x4008808010024800, 0x10c80804c010800,  0x6000808004010200, 0x808022000100,     0x2040e2001111825c,
    0x212800080244002,  0x409006100400080,  0x600c104100200108, 0x4110024900201100, 0x850a040180280080, 0x22002200102815,   0x8032081400103609, 0x8130800880005300,
    0x60874002800430,   0x400101002080,     0x502058012004020,  0x280100301002018,  0x3000080080800400, 0x2001002004408,    0x20000a9004000308, 0xd14250810e000044,
    0x80002004444000,   0x490002000404000,  0x16001080220040,   0x2009001000210028, 0x600a000c060020,   0xa08200500c420008, 0x8000859a10140048, 0x205a1410a0014,
    0x842220c83004600,  0x40810a4589220200, 0x1008200088100080, 0x4040401200180e00, 0x20000c200a006600, 0x1000040003070100, 0x8039020810c400,   0x90202040904820,
    0x80290030800019,   0x41004e00529882,   0x40080160019400a,  0x41000c400a060022, 0x108000500100613,  0x6319000608040001, 0xa1200801700180b4, 0x1500024110ac0082,
};

pub fn compute(iterations: u64) void {
    const seed: u64 = @intCast(std.time.nanoTimestamp());
    var prng = std.Random.DefaultPrng.init(seed);
    var improved_shift: bool = false;
    var improved_sparse: bool = false;

    for (0..iterations) |i| {
        const display_step = 10;
        if (@mod(i, @max(1, @divTrunc(iterations, display_step))) == 0) {
            std.debug.print("{}%\n", .{i / @divTrunc(iterations, 10) * display_step});
        }
        var ptr: [*]Bitboard = &magic_holder_tmp;
        var sq: types.Square = .a1;
        while (sq != .none) : (sq = sq.inc().*) {
            var magic_b: Magic = .empty;
            var magic_r: Magic = .empty;
            generateMagic(&magic_b, ptr, sq, tables.moves_bishop_mask[sq.index()], tables.getBishopAttacks, bishop_bits[sq.index()], &prng);
            ptr = ptr + (@as(u64, 1) << @truncate(64 - @as(usize, magic_b.shift)));
            generateMagic(&magic_r, ptr, sq, tables.moves_rook_mask[sq.index()], tables.getRookAttacks, rook_bits[sq.index()], &prng);
            ptr = ptr + (@as(u64, 1) << @truncate(64 - @as(usize, magic_r.shift)));

            // If we found a bigger shift or if magic array is more sparse take new one
            if (magic_b.shift > magics_bishop[sq.index()].shift) {
                std.debug.print("found better bishop shift for sq {}, from {} to {}\n", .{ sq, magics_bishop[sq.index()].shift, magic_b.shift });
                magics_bishop[sq.index()] = magic_b;
                improved_shift = true;
            }
            if (magic_b.nnz() < magics_bishop[sq.index()].nnz()) {
                std.debug.print("found more sparse bishop magic for sq {}, from {} to {}\n", .{ sq, magics_bishop[sq.index()].nnz(), magic_b.nnz() });
                magics_bishop[sq.index()] = magic_b;
                improved_sparse = true;
            }

            if (magic_r.shift > magics_rook[sq.index()].shift) {
                std.debug.print("found better rook shift for sq {}, from {} to {}\n", .{ sq, magics_rook[sq.index()].shift, magic_r.shift });
                magics_rook[sq.index()] = magic_r;
                improved_shift = true;
            }
            if (magic_r.nnz() < magics_rook[sq.index()].nnz()) {
                std.debug.print("found more sparse rook magic for sq {}, from {} to {}\n", .{ sq, magics_rook[sq.index()].nnz(), magic_r.nnz() });
                magics_rook[sq.index()] = magic_r;
                improved_sparse = true;
            }
        }
    }

    std.debug.print("nnz per square :\n", .{});
    for (0..types.board_size2) |i| {
        std.debug.print("{},", .{magics_bishop[i].nnz()});
    }
    std.debug.print("\n", .{});
    for (0..types.board_size2) |i| {
        std.debug.print("{},", .{magics_rook[i].nnz()});
    }
    std.debug.print("\n", .{});

    if (improved_shift or improved_sparse) {
        if (improved_shift) {
            std.debug.print("improved shift found :\n", .{});
            for (0..types.board_size2) |i| {
                std.debug.print("{},", .{64 - @as(u7, magics_bishop[i].shift)});
            }
            for (0..types.board_size2) |i| {
                std.debug.print("{},", .{64 - @as(u7, magics_rook[i].shift)});
            }
            std.debug.print("\n", .{});
        }

        std.debug.print("improved magics found :\n", .{});
        for (0..types.board_size2) |i| {
            std.debug.print("0x{x},\n", .{magics_bishop[i].magic});
        }
        for (0..types.board_size2) |i| {
            std.debug.print("0x{x},\n", .{magics_rook[i].magic});
        }
    }
}

pub fn initMagic() void {
    var ptr: [*]Bitboard = &magic_holder;

    var sq = types.Square.a1;
    while (sq != types.Square.none) : (sq = sq.inc().*) {
        var blockers: [1 << 12]Bitboard = @splat(0);

        magics_bishop[sq.index()] = Magic{ .ptr = ptr, .mask = tables.moves_bishop_mask[sq.index()], .magic = magic_numbers[sq.index()], .shift = @truncate(64 - bishop_bits[sq.index()]) };

        var blockers_size = tables.computeBlockers(magics_bishop[sq.index()].mask, &blockers);
        for (blockers[0..blockers_size]) |blocker| {
            const index = magics_bishop[sq.index()].computeIndex(blocker);
            magics_bishop[sq.index()].ptr.?[index] = tables.getBishopAttacks(sq, blocker);
        }

        ptr = ptr + (@as(u64, 1) << @truncate(64 - @as(u64, magics_bishop[sq.index()].shift)));

        // defer blockers.clearRetainingCapacity(); ????
        blockers = @splat(0);

        magics_rook[sq.index()] = Magic{ .ptr = ptr, .mask = tables.moves_rook_mask[sq.index()], .magic = magic_numbers[types.board_size2 + sq.index()], .shift = @truncate(64 - rook_bits[sq.index()]) };

        blockers_size = tables.computeBlockers(magics_rook[sq.index()].mask, &blockers);
        for (blockers[0..blockers_size]) |blocker| {
            const index = magics_rook[sq.index()].computeIndex(blocker);
            magics_rook[sq.index()].ptr.?[index] = tables.getRookAttacks(sq, blocker);
        }
        ptr = ptr + (@as(u64, 1) << @truncate(64 - @as(u64, magics_rook[sq.index()].shift)));
    }
}

// shift corresponds to the best shift so far
fn generateMagic(noalias magic_out: *Magic, noalias ptr: [*]Bitboard, sq: types.Square, mask: Bitboard, getAttacks: fn (types.Square, Bitboard) Bitboard, shift: u8, prng: *std.Random.DefaultPrng) void {
    var blockers: [1 << 12]Bitboard = @splat(0);
    const blockers_size: usize = tables.computeBlockers(mask, &blockers);

    while (true) {
        // Erase previous data
        @memset(ptr[0..((@as(u64, 1) << @truncate(shift)))], 0);

        var magic = Magic{
            .ptr = ptr,
            .mask = mask,
            .magic = prng.random().int(u64) & prng.random().int(u64) & prng.random().int(u64),
            // .shift = @truncate(64 - @divTrunc(@as(u64, prng.random().int(u8)) * shift, 1 << 8)),
            .shift = @truncate(64 - (shift -| prng.random().int(u1))), // half the time increase size of shift
        };

        var valid = true;
        for (blockers[0..blockers_size]) |blocker| {
            const index = magic.computeIndex(blocker);
            const moves = getAttacks(sq, blocker);
            if (magic.ptr.?[index] == 0) {
                magic.ptr.?[index] = moves;
            } else if (magic.ptr.?[index] != moves) {
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
