const position = @import("position.zig");
const std = @import("std");
const types = @import("types.zig");

const Bitboard = types.Bitboard;
const Color = types.Color;
const PieceType = types.PieceType;
const Square = types.Square;

pub var moves_bishop_mask: [types.board_size2]Bitboard = std.mem.zeroes([types.board_size2]Bitboard);
pub var moves_rook_mask: [types.board_size2]Bitboard = std.mem.zeroes([types.board_size2]Bitboard);
pub var moves_bishop: [types.board_size2]std.AutoHashMapUnmanaged(Bitboard, Bitboard) = undefined;
pub var moves_rook: [types.board_size2]std.AutoHashMapUnmanaged(Bitboard, Bitboard) = undefined;

pub var pseudo_legal_attacks: [PieceType.nb()][types.board_size2]Bitboard = std.mem.zeroes([PieceType.nb()][types.board_size2]Bitboard);
pub var pawn_attacks: [Color.nb()][types.board_size2]Bitboard = std.mem.zeroes([Color.nb()][types.board_size2]Bitboard);

pub var squares_between: [types.board_size2][types.board_size2]Bitboard = std.mem.zeroes([types.board_size2][types.board_size2]Bitboard);
pub var squares_line: [types.board_size2][types.board_size2]Bitboard = std.mem.zeroes([types.board_size2][types.board_size2]Bitboard);

pub var passed_pawn: [types.Color.nb()][types.board_size2]Bitboard = std.mem.zeroes([types.Color.nb()][types.board_size2]Bitboard);

pub inline fn filterMovesBishop(sq: Square) Bitboard {
    var b: Bitboard = 0;
    const sq_bb: Bitboard = sq.sqToBB();
    // Surely not the fastest: finds the diagonals that collides with tile
    for (0..types.board_size - 1) |i| {
        // Shifts is bounded by overflow
        // Diagonals go up
        const computed_clockwise_up: Bitboard = types.diagonal_clockwise << @intCast(i * types.board_size);
        if (computed_clockwise_up & sq_bb > 0)
            b |= computed_clockwise_up;

        const computed_counter_clockwise_up: Bitboard = types.diagonal_counter_clockwise << @intCast(i * types.board_size);
        if (computed_counter_clockwise_up & sq_bb > 0)
            b |= computed_counter_clockwise_up;

        // Diagonals go down
        const computedClockwiseDown: Bitboard = types.diagonal_clockwise >> @intCast(i * types.board_size);
        if (computedClockwiseDown & sq_bb > 0)
            b |= computedClockwiseDown;

        const computedCounterClockwiseDown: Bitboard = types.diagonal_counter_clockwise >> @intCast(i * types.board_size);
        if (computedCounterClockwiseDown & sq_bb > 0)
            b |= computedCounterClockwiseDown;
    }

    b &= ~sq_bb;

    // Remove bordered square as they can be treated as blockers

    b &= ~types.file;
    b &= ~(types.file << (types.board_size - 1));
    b &= ~types.rank;
    b &= ~(types.rank << (types.board_size - 1) * types.board_size);
    return b;
}

pub inline fn filterMovesRook(sq: Square) Bitboard {
    var b: Bitboard = 0;
    const current_file: u6 = sq.file().index();
    const current_rank: u6 = sq.rank().index();

    b |= types.file << current_file;
    b |= types.rank << (current_rank * types.board_size);
    b &= ~sq.sqToBB();

    // Remove bordered square as they can be treated as blockers
    b &= ~Square.intToBB(0 + current_file); // Bottom
    b &= ~Square.intToBB(types.board_size2 - types.board_size + current_file); // Top
    b &= ~Square.intToBB(types.board_size - 1 + (current_rank * types.board_size)); // Right
    b &= ~Square.intToBB(current_rank * types.board_size); // Left

    return b;
}

pub fn computeBlockers(mask_: Bitboard, v: *std.ArrayListUnmanaged(Bitboard), allocator: std.mem.Allocator) void {
    const bit_indices_size: u4 = @truncate(@popCount(mask_)); // Max is (types.board_size)*2-3
    for (1..std.math.pow(u64, 2, bit_indices_size)) |blocker_configuration| {
        var mask: Bitboard = mask_;
        var currentBlockerBB: Bitboard = 0;
        var cnt: u6 = 0;
        while (mask != 0) : (cnt += 1) {
            const bit_idx: u6 = @truncate(types.popLsb(&mask).index());

            const current_bit: Bitboard = (@as(u64, blocker_configuration) >> cnt) & 1; // Is the shifted bit in blocker_configuration activated
            currentBlockerBB |= current_bit << bit_idx; // Shift it back to its position
        }
        v.append(allocator, currentBlockerBB) catch unreachable;
    }
}

// Hyperbola Quintessence Algorithm
// https://www.chessprogramming.org/Hyperbola_Quintessence
// https://chess.stackexchange.com/questions/37309/move-generation-for-sliding-pieces-and-hyperbola-quintessence
fn slidingBB(sq: Square, blockers: Bitboard, mask: Bitboard) Bitboard {
    return (((mask & blockers) -% sq.sqToBB() *% 2) ^
        reverseBitboard(reverseBitboard(mask & blockers) -% reverseBitboard(sq.sqToBB()) *% 2)) & mask;
}

inline fn reverseBitboard(b_: Bitboard) Bitboard {
    var b = b_;
    b = (b & 0x5555555555555555) << 1 | ((b >> 1) & 0x5555555555555555);
    b = (b & 0x3333333333333333) << 2 | ((b >> 2) & 0x3333333333333333);
    b = (b & 0x0f0f0f0f0f0f0f0f) << 4 | ((b >> 4) & 0x0f0f0f0f0f0f0f0f);
    b = (b & 0x00ff00ff00ff00ff) << 8 | ((b >> 8) & 0x00ff00ff00ff00ff);

    return (b << 48) | ((b & 0xffff0000) << 16) |
        ((b >> 16) & 0xffff0000) | (b >> 48);
}

inline fn getBishopAttacks(sq: Square, blockers: Bitboard) Bitboard {
    return slidingBB(sq, blockers, types.mask_diagonal[@intCast(sq.diagonal())]) | slidingBB(sq, blockers, types.mask_anti_diagonal[@intCast(sq.antiDiagonal())]);
}

inline fn getRookAttacks(sq: Square, blockers: Bitboard) Bitboard {
    return slidingBB(sq, blockers, types.mask_file[sq.file().index()]) | slidingBB(sq, blockers, types.mask_rank[sq.rank().index()]);
}

fn initSlidersAttacks(allocator: std.mem.Allocator) void {
    // Compute moveable squares
    var sq: Square = Square.a1;
    while (sq != Square.none) : (sq = sq.inc().*) {
        moves_bishop_mask[sq.index()] = filterMovesBishop(sq);
        moves_rook_mask[sq.index()] = filterMovesRook(sq);
    }

    // Compute blockers
    sq = Square.a1;
    while (sq != Square.none) : (sq = sq.inc().*) {
        // Bishop
        moves_bishop[sq.index()] = .empty;
        var moves_bishop_blockers: std.ArrayListUnmanaged(Bitboard) = .empty;
        defer moves_bishop_blockers.deinit(allocator);

        moves_bishop_blockers.append(allocator, 0) catch unreachable;
        computeBlockers(moves_bishop_mask[sq.index()], &moves_bishop_blockers, allocator);

        for (moves_bishop_blockers.items) |blockers| {
            moves_bishop[sq.index()].put(allocator, blockers, getBishopAttacks(sq, blockers)) catch unreachable;
        }

        // Rook
        moves_rook[sq.index()] = .empty;
        var moves_rook_blockers: std.ArrayListUnmanaged(Bitboard) = .empty;
        defer moves_rook_blockers.deinit(allocator);

        moves_rook_blockers.append(allocator, 0) catch unreachable;
        computeBlockers(moves_rook_mask[sq.index()], &moves_rook_blockers, allocator);

        for (moves_rook_blockers.items) |blockers| {
            moves_rook[sq.index()].put(allocator, blockers, getRookAttacks(sq, blockers)) catch unreachable;
        }
    }
}

fn initLine() void {
    var sq1: Square = Square.a1;

    while (sq1 != Square.none) : (sq1 = sq1.inc().*) {
        var sq2: Square = Square.a1;

        while (sq2 != Square.none) : (sq2 = sq2.inc().*) {
            if (sq1 == sq2)
                continue;

            if (sq1.file() == sq2.file()) {
                squares_line[sq1.index()][sq2.index()] = types.mask_file[sq1.file().index()];
            } else if (sq1.rank() == sq2.rank()) {
                squares_line[sq1.index()][sq2.index()] = types.mask_rank[sq1.rank().index()];
            } else if (sq1.diagonal() == sq2.diagonal()) {
                squares_line[sq1.index()][sq2.index()] = types.mask_diagonal[sq1.diagonal()];
            } else if (sq1.antiDiagonal() == sq2.antiDiagonal()) {
                squares_line[sq1.index()][sq2.index()] = types.mask_anti_diagonal[sq1.antiDiagonal()];
            }
        }
    }
}

fn initSquaresBetween() void {
    var sq1: Square = Square.a1;

    while (sq1 != Square.none) : (sq1 = sq1.inc().*) {
        var sq2: Square = Square.a1;

        while (sq2 != Square.none) : (sq2 = sq2.inc().*) {
            if (sq1 == sq2)
                continue;
            const sqs: Bitboard = sq1.sqToBB() | sq2.sqToBB();
            if (sq1.diagonal() == sq2.diagonal() or sq1.antiDiagonal() == sq2.antiDiagonal()) {
                squares_between[sq1.index()][sq2.index()] = getBishopAttacks(sq1, sqs) & getBishopAttacks(sq2, sqs);
            } else if (sq1.file() == sq2.file() or sq1.rank() == sq2.rank()) {
                squares_between[sq1.index()][sq2.index()] = getRookAttacks(sq1, sqs) & getRookAttacks(sq2, sqs);
            } else {
                squares_between[sq1.index()][sq2.index()] = 0;
            }
        }
    }
}

fn initNonBlockable() void {
    std.mem.copyForwards(Bitboard, pawn_attacks[Color.black.index()][0..types.board_size2], black_pawn_attacks[0..types.board_size2]);
    std.mem.copyForwards(Bitboard, pawn_attacks[Color.white.index()][0..types.board_size2], white_pawn_attacks[0..types.board_size2]);
    std.mem.copyForwards(Bitboard, pseudo_legal_attacks[PieceType.knight.index()][0..types.board_size2], knight_attacks[0..types.board_size2]);
    std.mem.copyForwards(Bitboard, pseudo_legal_attacks[PieceType.king.index()][0..types.board_size2], king_attacks[0..types.board_size2]);
}

inline fn filterAdjacent(tile: types.Square) types.Bitboard {
    return (types.mask_file[@max(0, tile.file().index() -| 1)] | types.mask_file[@min(types.board_size - 1, @as(u4, tile.file().index()) + 1)]) & ~types.mask_file[tile.file().index()];
}

fn filterPassedPawn(tile: types.Square, col: types.Color) types.Bitboard {
    const filter_adjacent: types.Bitboard = types.mask_file[tile.file().index()] | filterAdjacent(tile);
    const row_idx: u6 = @intCast(tile.rank().index());
    const bb_max: types.Bitboard = 0xFFFFFFFFFFFFFFFF;
    const filter_top_bot: types.Bitboard = if (col.isWhite()) bb_max << types.board_size * (row_idx + 1) else bb_max >> types.board_size * (types.board_size - row_idx);
    return filter_adjacent & filter_top_bot;
}

fn initPassedPawn() void {
    var sq: Square = Square.a2;
    while (sq != Square.a8) : (sq = sq.inc().*) {
        passed_pawn[types.Color.white.index()][sq.index()] = filterPassedPawn(sq, types.Color.white);
        passed_pawn[types.Color.black.index()][sq.index()] = filterPassedPawn(sq, types.Color.black);
    }
}

pub fn initAll(allocator: std.mem.Allocator) void {
    initSlidersAttacks(allocator);
    initLine();
    initSquaresBetween();
    initNonBlockable();
    initPassedPawn();
}

pub fn deinitAll(allocator: std.mem.Allocator) void {
    var sq: u8 = Square.a1.index();
    while (sq <= Square.h8.index()) : (sq += 1) {
        moves_bishop[sq].deinit(allocator);
        moves_rook[sq].deinit(allocator);
    }
}

pub inline fn getAttacks(pt: PieceType, color: Color, sq: Square, blockers: Bitboard) Bitboard {
    return switch (pt) {
        PieceType.pawn => pawn_attacks[color.index()][sq.index()],
        PieceType.rook => moves_rook[sq.index()].get(moves_rook_mask[sq.index()] & blockers) orelse unreachable,
        PieceType.bishop => moves_bishop[sq.index()].get(moves_bishop_mask[sq.index()] & blockers) orelse unreachable,
        PieceType.queen => (moves_rook[sq.index()].get(moves_rook_mask[sq.index()] & blockers) orelse unreachable) | (moves_bishop[sq.index()].get(moves_bishop_mask[sq.index()] & blockers) orelse unreachable),
        else => pseudo_legal_attacks[pt.index()][sq.index()],
    };
}

pub inline fn getAttackers(pos: position.Position, color: Color, sq: Square, blockers: Bitboard) Bitboard {
    const p = getAttacks(PieceType.pawn, color.invert(), sq, blockers) & pos.bb_pieces[PieceType.pawn.index()];
    const n = getAttacks(PieceType.knight, color, sq, blockers) & pos.bb_pieces[PieceType.knight.index()];
    const b = getAttacks(PieceType.bishop, color, sq, blockers) & (pos.bb_pieces[PieceType.bishop.index()] | pos.bb_pieces[PieceType.queen.index()]);
    const r = getAttacks(PieceType.rook, color, sq, blockers) & (pos.bb_pieces[PieceType.rook.index()] | pos.bb_pieces[PieceType.queen.index()]);
    return (p | n | b | r) & pos.bb_colors[color.index()];
}

// zig fmt: off
pub const king_attacks = [64]Bitboard{
    0x302,              0x705,              0xe0a,               0x1c14,              0x3828,              0x7050,              0xe0a0,              0xc040,
    0x30203,            0x70507,            0xe0a0e,             0x1c141c,            0x382838,            0x705070,            0xe0a0e0,            0xc040c0,
    0x3020300,          0x7050700,          0xe0a0e00,           0x1c141c00,          0x38283800,          0x70507000,          0xe0a0e000,          0xc040c000,
    0x302030000,        0x705070000,        0xe0a0e0000,         0x1c141c0000,        0x3828380000,        0x7050700000,        0xe0a0e00000,        0xc040c00000,
    0x30203000000,      0x70507000000,      0xe0a0e000000,       0x1c141c000000,      0x382838000000,      0x705070000000,      0xe0a0e0000000,      0xc040c0000000,
    0x3020300000000,    0x7050700000000,    0xe0a0e00000000,     0x1c141c00000000,    0x38283800000000,    0x70507000000000,    0xe0a0e000000000,    0xc040c000000000,
    0x302030000000000,  0x705070000000000,  0xe0a0e0000000000,   0x1c141c0000000000,  0x3828380000000000,  0x7050700000000000,  0xe0a0e00000000000,  0xc040c00000000000,
    0x203000000000000,  0x507000000000000,  0xa0e000000000000,   0x141c000000000000,  0x2838000000000000,  0x5070000000000000,  0xa0e0000000000000,  0x40c0000000000000,
};

pub const knight_attacks = [64]Bitboard{
    0x20400,            0x50800,            0xa1100,             0x142200,            0x284400,            0x508800,            0xa01000,            0x402000,
    0x2040004,          0x5080008,          0xa110011,           0x14220022,          0x28440044,          0x50880088,          0xa0100010,          0x40200020,
    0x204000402,        0x508000805,        0xa1100110a,         0x1422002214,        0x2844004428,        0x5088008850,        0xa0100010a0,        0x4020002040,
    0x20400040200,      0x50800080500,      0xa1100110a00,       0x142200221400,      0x284400442800,      0x508800885000,      0xa0100010a000,      0x402000204000,
    0x2040004020000,    0x5080008050000,    0xa1100110a0000,     0x14220022140000,    0x28440044280000,    0x50880088500000,    0xa0100010a00000,    0x40200020400000,
    0x204000402000000,  0x508000805000000,  0xa1100110a000000,   0x1422002214000000,  0x2844004428000000,  0x5088008850000000,  0xa0100010a0000000,  0x4020002040000000,
    0x400040200000000,  0x800080500000000,  0x1100110a00000000,  0x2200221400000000,  0x4400442800000000,  0x8800885000000000,  0x100010a000000000,  0x2000204000000000,
    0x4020000000000,    0x8050000000000,    0x110a0000000000,    0x22140000000000,    0x44280000000000,    0x0088500000000000,  0x0010a00000000000,  0x20400000000000,
};

pub const white_pawn_attacks = [64]Bitboard{
    0x200,              0x500,              0xa00,              0x1400,              0x2800,               0x5000,              0xa000,              0x4000,
    0x20000,            0x50000,            0xa0000,            0x140000,            0x280000,             0x500000,            0xa00000,            0x400000,
    0x2000000,          0x5000000,          0xa000000,          0x14000000,          0x28000000,           0x50000000,          0xa0000000,          0x40000000,
    0x200000000,        0x500000000,        0xa00000000,        0x1400000000,        0x2800000000,         0x5000000000,        0xa000000000,        0x4000000000,
    0x20000000000,      0x50000000000,      0xa0000000000,      0x140000000000,      0x280000000000,       0x500000000000,      0xa00000000000,      0x400000000000,
    0x2000000000000,    0x5000000000000,    0xa000000000000,    0x14000000000000,    0x28000000000000,     0x50000000000000,    0xa0000000000000,    0x40000000000000,
    0x200000000000000,  0x500000000000000,  0xa00000000000000,  0x1400000000000000,  0x2800000000000000,   0x5000000000000000,  0xa000000000000000,  0x4000000000000000,
    0x0,                0x0,                0x0,                0x0,                 0x0,                  0x0,                 0x0,                 0x0,
};

pub const black_pawn_attacks = [64]Bitboard{
    0x0,                0x0,                0x0,                0x0,                 0x0,                  0x0,                 0x0,                 0x0,
    0x2,                0x5,                0xa,                0x14,                0x28,                 0x50,                0xa0,                0x40,
    0x200,              0x500,              0xa00,              0x1400,              0x2800,               0x5000,              0xa000,              0x4000,
    0x20000,            0x50000,            0xa0000,            0x140000,            0x280000,             0x500000,            0xa00000,            0x400000,
    0x2000000,          0x5000000,          0xa000000,          0x14000000,          0x28000000,           0x50000000,          0xa0000000,          0x40000000,
    0x200000000,        0x500000000,        0xa00000000,        0x1400000000,        0x2800000000,         0x5000000000,        0xa000000000,        0x4000000000,
    0x20000000000,      0x50000000000,      0xa0000000000,      0x140000000000,      0x280000000000,       0x500000000000,      0xa00000000000,      0x400000000000,
    0x2000000000000,    0x5000000000000,    0xa000000000000,    0x14000000000000,    0x28000000000000,     0x50000000000000,    0xa0000000000000,    0x40000000000000,
};


// Start position total 14152, max 20952
pub const material = [types.PieceType.nb()]types.Value { 0, 100, 305, 333, 563, 950, 10_000 };

pub const passed_pawn_table = [types.board_size - 1]types.Value { 0, 15, 15, 25, 40, 60, 70 };

// Tables are displayed for white which corresponds to black order of tiles
// https://www.chessprogramming.org/PeSTO%27s_Evaluation_Function
pub const psq: [types.PieceType.nb()][2][types.board_size2]types.Value = .{
    .{
        .{
            0,   0,   0,   0,   0,   0,   0,  0,
            0,   0,   0,   0,   0,   0,   0,  0,
            0,   0,   0,   0,   0,   0,   0,  0,
            0,   0,   0,   0,   0,   0,   0,  0,
            0,   0,   0,   0,   0,   0,   0,  0,
            0,   0,   0,   0,   0,   0,   0,  0,
            0,   0,   0,   0,   0,   0,   0,  0,
            0,   0,   0,   0,   0,   0,   0,  0,
        }, .{
            0,   0,   0,   0,   0,   0,   0,  0,
            0,   0,   0,   0,   0,   0,   0,  0,
            0,   0,   0,   0,   0,   0,   0,  0,
            0,   0,   0,   0,   0,   0,   0,  0,
            0,   0,   0,   0,   0,   0,   0,  0,
            0,   0,   0,   0,   0,   0,   0,  0,
            0,   0,   0,   0,   0,   0,   0,  0,
            0,   0,   0,   0,   0,   0,   0,  0,
        },
    },
    .{
        .{
            0,   0,   0,   0,   0,   0,   0,  0,
            98,  134, 61,  95,  68,  126, 34, -11,
            -6,  7,   26,  31,  65,  56,  25, -20,
            -14, 13,  6,   21,  23,  12,  17, -23,
            -27, -2,  -5,  12,  17,  6,   10, -25,
            -26, -4,  -4,  -10, 3,   3,   33, -12,
            -35, -1,  -20, -23, -15, 24,  38, -22,
            0,   0,   0,   0,   0,   0,   0,  0,
        },
        .{
            0,   0,   0,   0,   0,   0,   0,   0,
            178, 173, 158, 134, 147, 132, 165, 187,
            94,  100, 85,  67,  56,  53,  82,  84,
            32,  24,  13,  5,   -2,  4,   17,  17,
            13,  9,   -3,  -7,  -7,  -8,  3,   -1,
            4,   7,   -6,  1,   0,   -5,  -1,  -8,
            13,  8,   8,   10,  13,  0,   2,   -7,
            0,   0,   0,   0,   0,   0,   0,   0,
        },
    },
    .{
        .{
            -167, -89, -34, -49, 61,  -97, -15, -107,
            -73,  -41, 72,  36,  23,  62,  7,   -17,
            -47,  60,  37,  65,  84,  129, 73,  44,
            -9,   17,  19,  53,  37,  69,  18,  22,
            -13,  4,   16,  13,  28,  19,  21,  -8,
            -23,  -9,  12,  10,  19,  17,  25,  -16,
            -29,  -53, -12, -3,  -1,  18,  -14, -19,
            -105, -21, -58, -33, -17, -28, -19, -23,
        },
        .{
            -58, -38, -13, -28, -31, -27, -63, -99,
            -25, -8,  -25, -2,  -9,  -25, -24, -52,
            -24, -20, 10,  9,   -1,  -9,  -19, -41,
            -17, 3,   22,  22,  22,  11,  8,   -18,
            -18, -6,  16,  25,  16,  17,  4,   -18,
            -23, -3,  -1,  15,  10,  -3,  -20, -22,
            -42, -20, -10, -5,  -2,  -20, -23, -44,
            -29, -51, -23, -15, -22, -18, -50, -64,
        },
    },
    .{
        .{
            -29, 4,  -82, -37, -25, -42, 7,   -8,
            -26, 16, -18, -13, 30,  59,  18,  -47,
            -16, 37, 43,  40,  35,  50,  37,  -2,
            -4,  5,  19,  50,  37,  37,  7,   -2,
            -6,  13, 13,  26,  34,  12,  10,  4,
            0,   15, 15,  15,  14,  27,  18,  10,
            4,   15, 16,  0,   7,   21,  33,  1,
            -33, -3, -14, -21, -13, -12, -39, -21,
        },
        .{
            -14, -21, -11, -8,  -7, -9,  -17, -24,
            -8,  -4,  7,   -12, -3, -13, -4,  -14,
            2,   -8,  0,   -1,  -2, 6,   0,   4,
            -3,  9,   12,  9,   14, 10,  3,   2,
            -6,  3,   13,  19,  7,  10,  -3,  -9,
            -12, -3,  8,   10,  13, 3,   -7,  -15,
            -14, -18, -7,  -1,  4,  -9,  -15, -27,
            -23, -9,  -23, -5,  -9, -16, -5,  -17,
        },
    },
    .{
        .{
            32,  42,  32,  51,  63, 9,  31,  43,
            27,  32,  58,  62,  80, 67, 26,  44,
            -5,  19,  26,  36,  17, 45, 61,  16,
            -24, -11, 7,   26,  24, 35, -8,  -20,
            -36, -26, -12, -1,  9,  -7, 6,   -23,
            -45, -25, -16, -17, 3,  0,  -5,  -33,
            -44, -16, -20, -9,  -1, 11, -6,  -71,
            -19, -13, 1,   17,  16, 7,  -37, -26,
        },
        .{
            13, 10, 18, 15, 12, 12,  8,   5,
            11, 13, 13, 11, -3, 3,   8,   3,
            7,  7,  7,  5,  4,  -3,  -5,  -3,
            4,  3,  13, 1,  2,  1,   -1,  2,
            3,  5,  8,  4,  -5, -6,  -8,  -11,
            -4, 0,  -5, -1, -7, -12, -8,  -16,
            -6, -6, 0,  2,  -9, -9,  -11, -3,
            -9, 2,  3,  -1, -5, -13, 4,   -20,
        },
    },
    .{
        .{
            -28, 0,   29,  12,  59,  44,  43,  45,
            -24, -39, -5,  1,   -16, 57,  28,  54,
            -13, -17, 7,   8,   29,  56,  47,  57,
            -27, -27, -16, -16, -1,  17,  -2,  1,
            -9,  -26, -9,  -10, -2,  -4,  3,   -3,
            -14, 2,   -11, -2,  -5,  2,   14,  5,
            -35, -8,  11,  2,   8,   15,  -3,  1,
            -1,  -18, -9,  10,  -15, -25, -31, -50,
        },
        .{
            -9,  22,  22,  27,  27,  19,  10,  20,
            -17, 20,  32,  41,  58,  25,  30,  0,
            -20, 6,   9,   49,  47,  35,  19,  9,
            3,   22,  24,  45,  57,  40,  57,  36,
            -18, 28,  19,  47,  31,  34,  39,  23,
            -16, -27, 15,  6,   9,   17,  10,  5,
            -22, -23, -30, -16, -16, -23, -36, -32,
            -33, -28, -22, -43, -5,  -32, -20, -41,
        },
    },
    .{
        .{
            -65, 23,  16,  -15, -56, -34, 2,   13,
            29,  -1,  -20, -7,  -8,  -4,  -38, -29,
            -9,  24,  2,   -16, -20, 6,   22,  -22,
            -17, -20, -12, -27, -30, -25, -14, -36,
            -49, -1,  -27, -39, -46, -44, -33, -51,
            -14, -14, -22, -46, -44, -30, -15, -27,
            1,   7,   -8,  -64, -43, -16, 9,   8,
            -15, 36,  12,  -54, 8,   -28, 24,  14,
        },
        .{
            -74, -35, -18, -18, -11, 15,  4,   -17,
            -12, 17,  14,  17,  17,  38,  23,  11,
            10,  17,  23,  15,  20,  45,  44,  13,
            -8,  22,  24,  27,  26,  33,  26,  3,
            -18, -4,  21,  24,  27,  23,  9,   -11,
            -19, -3,  11,  21,  23,  16,  7,   -9,
            -27, -11, 4,   13,  14,  4,   -5,  -17,
            -53, -34, -21, -11, -28, -14, -24, -43,
        },
    },
};
// zig fmt: on
