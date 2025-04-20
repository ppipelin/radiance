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

pub const magic_numbers: [types.board_size2 * 2]u64 = [_]u64{
    0x40011800808085,   0x4002180509020010, 0x9c1010808b100000, 0x4084440080048000, 0x4081104120403000, 0x6023004080000,    0x280420220204301,  0x9001220510082200,
    0x114004880a00c0,   0xe2200404099022,   0xa001100c8a005000, 0x10a6020a02000020, 0x84804042000201c,  0x4000088620200002, 0x1050021a90041000, 0x4000f404122800,
    0x1006400890100600, 0x8c416483004c200,  0x111100112a100,    0x1200404008004,    0x200100882018011a, 0x924800410040340,  0x828900108480200,  0x100288082011014,
    0x208200040640100,  0x200450000206080c, 0x10480011021400,   0x60b3080011004100, 0x60408c0040802000, 0x4802e036008400,   0x2008250000440680, 0x4c00404001040200,
    0x10880c1080400200, 0x14a01210004283c,  0x100305002080180,  0x1081010800010040, 0x40010010110240,   0x48100020441200,   0xa11002008838e400, 0x169004201810100,
    0x3081103064041108, 0xe2012920008814,   0x10080c24048080a,  0x80004602800801,   0xc20102010412200,  0x4098082000105,    0x258102400481084,  0x1404870401201502,
    0x1002020104400000, 0x206004622108040,  0x1284021042080048, 0x10020042021000,   0x2004202008504014, 0x20410204011040,   0x480e10441900a8,   0xe280304008041,
    0xd3808448124000,   0x4020020044040c04, 0xe0614021080810,   0x8000006100460802, 0xc0200084008a200,  0xc140c028014900,   0x8020a0040104c8,   0xc4408204c0180,
    0x8080048094204001, 0x840002000401002,  0x85001108200100c0, 0x2880180010008104, 0xa00120004102108,  0x4880040001800200, 0x40001100a042088,  0x4200004420820104,
    0x8022800420400080, 0x4049004001028820, 0x803002200084,     0x204800802801002,  0x3001100040800,    0x8008800400020080, 0x1000d00420044,    0x2802000041028204,
    0x8280084001200841, 0xc400b8020004083,  0x8828020001000,    0x4008808010024800, 0x10c80804c010800,  0x6000808004010200, 0x808022000100,     0x260060008610184,
    0x212800080244002,  0x409006100400080,  0x600c104100200108, 0x4110024900201100, 0x850a040180280080, 0x22002200102815,   0x8032081400103609, 0x8130800880005300,
    0x6094400020800082, 0x400101002080,     0x502058012004020,  0x280100301002018,  0x3000080080800400, 0x2001002004408,    0x20000a9004000308, 0xd14250810e000044,
    0x80002004444000,   0x490002000404000,  0x16001080220040,   0x2009001000210028, 0x10d0008010010,    0xa08200500c420008, 0xc888210040019,    0x5400008044020001,
    0x842220c83004600,  0x40810a4589220200, 0x1008200088100080, 0x100a00412200,     0x8080110801008d00, 0x802200040080,     0x8039020810c400,   0x200080a114004600,
    0x2004110080260042, 0xe40002040810015,  0x4490040102001,    0x141a005020044842, 0x84200102044584a,  0x6319000608040001, 0x100802088104,     0x42150824010a4282,
};

pub fn compute(allocator: std.mem.Allocator) void {
    const seed: u64 = @intCast(std.time.nanoTimestamp());
    var prng = std.Random.DefaultPrng.init(seed);

    var sq = types.Square.a1;
    while (sq != types.Square.none) : (sq = sq.inc().*) {
        generateMagic(allocator, &magics_bishop[sq.index()], sq, tables.moves_bishop_mask[sq.index()], tables.getBishopAttacks, bishop_bits, &prng);
        generateMagic(allocator, &magics_rook[sq.index()], sq, tables.moves_rook_mask[sq.index()], tables.getRookAttacks, rook_bits, &prng);

        std.debug.print("found magic for sq {}\n", .{sq});
    }

    std.debug.print("magics found :\n", .{});
    for (0..types.board_size2) |i| {
        std.debug.print("0x{x},\n", .{magics_bishop[i].magic});
    }

    for (0..types.board_size2) |i| {
        std.debug.print("0x{x},\n", .{magics_rook[i].magic});
    }
}

pub fn initMagic(allocator: std.mem.Allocator) void {
    var sq = types.Square.a1;
    while (sq != types.Square.none) : (sq = sq.inc().*) {
        var blockers: std.ArrayListUnmanaged(Bitboard) = .empty;
        defer blockers.deinit(allocator);

        magics_bishop[sq.index()] = Magic{ .ptr = std.mem.zeroes([4096]Bitboard), .mask = tables.moves_bishop_mask[sq.index()], .magic = magic_numbers[sq.index()], .shift = @truncate(64 - bishop_bits[sq.index()]) };

        blockers.append(allocator, 0) catch unreachable;
        tables.computeBlockers(magics_bishop[sq.index()].mask, &blockers, allocator);
        for (blockers.items) |blocker| {
            const index = magics_bishop[sq.index()].computeIndex(blocker);
            magics_bishop[sq.index()].ptr[index] = tables.getBishopAttacks(sq, blocker);
        }

        defer blockers.clearRetainingCapacity();

        magics_rook[sq.index()] = Magic{ .ptr = std.mem.zeroes([4096]Bitboard), .mask = tables.moves_rook_mask[sq.index()], .magic = magic_numbers[types.board_size2 + sq.index()], .shift = @truncate(64 - rook_bits[sq.index()]) };

        blockers.append(allocator, 0) catch unreachable;
        tables.computeBlockers(magics_rook[sq.index()].mask, &blockers, allocator);
        for (blockers.items) |blocker| {
            const index = magics_rook[sq.index()].computeIndex(blocker);
            magics_rook[sq.index()].ptr[index] = tables.getRookAttacks(sq, blocker);
        }
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
