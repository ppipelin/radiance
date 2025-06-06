const std = @import("std");
const tables = @import("tables.zig");
const types = @import("types.zig");

const Bitboard = types.Bitboard;

var magic_holder: [107648]Bitboard = std.mem.zeroes([107648]Bitboard);

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
            if (val != 0) count += 1;
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

pub var magics_bishop: [types.board_size2]Magic = std.mem.zeroes([types.board_size2]Magic);
pub var magics_rook: [types.board_size2]Magic = std.mem.zeroes([types.board_size2]Magic);
pub var collisions_found_bishop: [types.board_size2]u12 = std.mem.zeroes([types.board_size2]u12);
pub var collisions_found_rook: [types.board_size2]u12 = std.mem.zeroes([types.board_size2]u12);

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
    0x3505000ea8080,    0x802001c181805200, 0x21082a0830200a2,  0x10082086b0292224, 0x4081104120403000, 0x2608045e000800,   0x48a29210101f0000, 0x10945a0110610404,
    0x440070e98020404,  0x20203140800e108,  0x20410212600b100,  0x10a6020a02000020, 0x84804042000201c,  0x4000088620200002, 0x2c80006804472000, 0x390800a601f01800,
    0x2040382104410e48, 0x1208089029882984, 0x111100112a100,    0x1200404008004,    0x200100882018011a, 0x924800410040340,  0x102020861502680,  0xc20004470dc801,
    0x89a8231a40820a08, 0x200450000206080c, 0x10480011021400,   0x60b3080011004100, 0x60408c0040802000, 0x4802e036008400,   0x2008250000440680, 0x2009041cc0390,
    0x10880c1080400200, 0x14a01210004283c,  0x100305002080180,  0x1081010800010040, 0x40010010110240,   0x48100020441200,   0xd881304020910,    0x169004201810100,
    0x2650486714000,    0x40980303801000,   0x10080c24048080a,  0x80004602800801,   0xc20102010412200,  0x4098082000105,    0xf182724001108,    0x8044803dd160440,
    0x100c0409c50d0090, 0x3002020fc9a80080, 0x816a221104010,    0x210288505980600,  0x2004202008504014, 0x20410204011040,   0x1120038c019884,   0x648222403d010,
    0x8000808080b04108, 0x200000410dc86080, 0xe0614021080810,   0x8000006100460802, 0x809084b0410,      0xc140c028014900,   0xa02a22155440d1,   0x10b4e00294003081,
    0x8080048094204001, 0x840002000401002,  0x85001108200100c0, 0x2880180010008104, 0xa00120004102108,  0x4880040001800200, 0x40001100a042088,  0x4200004420820104,
    0x8022800420400080, 0x4049004001028820, 0x803002200084,     0x204800802801002,  0x3001100040800,    0x8008800400020080, 0x1000d00420044,    0x2101020204081,
    0x8280084001200841, 0xc400b8020004083,  0x8828020001000,    0x4008808010024800, 0x10c80804c010800,  0x6000808004010200, 0x808022000100,     0x260060008610184,
    0x212800080244002,  0x409006100400080,  0x600c104100200108, 0x4110024900201100, 0x850a040180280080, 0x22002200102815,   0x8032081400103609, 0x8130800880005300,
    0x6094400020800082, 0x400101002080,     0x502058012004020,  0x280100301002018,  0x3000080080800400, 0x2001002004408,    0x20000a9004000308, 0xd14250810e000044,
    0x80002004444000,   0x490002000404000,  0x16001080220040,   0x2009001000210028, 0x10d0008010010,    0xa08200500c420008, 0x8000859a10140048, 0x5400008044020001,
    0x842220c83004600,  0x40810a4589220200, 0x1008200088100080, 0x100a00412200,     0x8080110801008d00, 0x1000040003070100, 0x8039020810c400,   0x90202040904820,
    0x2004110080260042, 0xe40002040810015,  0x40080160019400a,  0x41000c400a060022, 0x108000500100613,  0x6319000608040001, 0x100802088104,     0x1500024110ac0082,
};

pub fn compute(allocator: std.mem.Allocator, iterations: u64) void {
    const seed: u64 = @intCast(std.time.nanoTimestamp());
    var prng = std.Random.DefaultPrng.init(seed);

    for (0..iterations) |_| {
        var ptr: [*]Bitboard = &magic_holder;
        var sq = types.Square.a1;
        while (sq != types.Square.none) : (sq = sq.inc().*) {
            var magic_b: Magic = .empty;
            var magic_r: Magic = .empty;
            generateMagic(allocator, &magic_b, ptr, sq, tables.moves_bishop_mask[sq.index()], tables.getBishopAttacks, bishop_bits[sq.index()], &prng);
            ptr = ptr + (@as(u64, 1) << @truncate(64 - @as(usize, magic_b.shift)));
            generateMagic(allocator, &magic_r, ptr, sq, tables.moves_rook_mask[sq.index()], tables.getRookAttacks, rook_bits[sq.index()], &prng);
            ptr = ptr + (@as(u64, 1) << @truncate(64 - @as(usize, magic_r.shift)));

            // If magic array is more sparse take new one
            if (magic_b.nnz() < magics_bishop[sq.index()].nnz()) {
                std.debug.print("found better bishop magic for sq {}\n", .{sq});
                magics_bishop[sq.index()] = magic_b;
            }

            if (magic_r.nnz() < magics_rook[sq.index()].nnz()) {
                std.debug.print("found better rook magic for sq {}\n", .{sq});
                magics_rook[sq.index()] = magic_r;
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

    std.debug.print("magics found :\n", .{});
    for (0..types.board_size2) |i| {
        std.debug.print("0x{x},\n", .{magics_bishop[i].magic});
    }
    for (0..types.board_size2) |i| {
        std.debug.print("0x{x},\n", .{magics_rook[i].magic});
    }
}

pub fn initMagic(allocator: std.mem.Allocator) void {
    var ptr: [*]Bitboard = &magic_holder;

    var sq = types.Square.a1;
    while (sq != types.Square.none) : (sq = sq.inc().*) {
        var blockers: std.ArrayListUnmanaged(Bitboard) = .empty;
        defer blockers.deinit(allocator);

        magics_bishop[sq.index()] = Magic{ .ptr = ptr, .mask = tables.moves_bishop_mask[sq.index()], .magic = magic_numbers[sq.index()], .shift = @truncate(64 - bishop_bits[sq.index()]) };

        blockers.append(allocator, 0) catch unreachable;
        tables.computeBlockers(magics_bishop[sq.index()].mask, &blockers, allocator);
        for (blockers.items) |blocker| {
            const index = magics_bishop[sq.index()].computeIndex(blocker);
            magics_bishop[sq.index()].ptr.?[index] = tables.getBishopAttacks(sq, blocker);
        }

        ptr = ptr + (@as(u64, 1) << @truncate(64 - @as(u64, magics_bishop[sq.index()].shift)));

        defer blockers.clearRetainingCapacity();

        magics_rook[sq.index()] = Magic{ .ptr = ptr, .mask = tables.moves_rook_mask[sq.index()], .magic = magic_numbers[types.board_size2 + sq.index()], .shift = @truncate(64 - rook_bits[sq.index()]) };

        blockers.append(allocator, 0) catch unreachable;
        tables.computeBlockers(magics_rook[sq.index()].mask, &blockers, allocator);
        for (blockers.items) |blocker| {
            const index = magics_rook[sq.index()].computeIndex(blocker);
            magics_rook[sq.index()].ptr.?[index] = tables.getRookAttacks(sq, blocker);
        }
        ptr = ptr + (@as(u64, 1) << @truncate(64 - @as(u64, magics_rook[sq.index()].shift)));
    }
}

fn generateMagic(allocator: std.mem.Allocator, magic_out: *Magic, ptr: [*]Bitboard, sq: types.Square, mask: Bitboard, getAttacks: fn (types.Square, Bitboard) Bitboard, shift: u8, prng: *std.Random.DefaultPrng) void {
    var blockers: std.ArrayListUnmanaged(Bitboard) = .empty;
    defer blockers.deinit(allocator);

    blockers.append(allocator, 0) catch unreachable;
    tables.computeBlockers(mask, &blockers, allocator);

    while (true) {
        // Erase previous data
        @memset(ptr[0..((@as(u64, 1) << @truncate(shift)))], 0);

        var magic = Magic{
            .ptr = ptr,
            .mask = mask,
            .magic = prng.random().int(u64) & prng.random().int(u64) & prng.random().int(u64),
            .shift = @truncate(64 - shift),
        };

        var valid = true;
        for (blockers.items) |blocker| {
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
