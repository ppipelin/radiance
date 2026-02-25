const position = @import("position.zig");
const std = @import("std");
const tables = @import("tables.zig");
const types = @import("types.zig");
const variable = @import("variable.zig");

pub fn computeDoubledPawns(bb_pawn: types.Bitboard) types.Value {
    const bb_pawn_vec: @Vector(types.board_size, types.Bitboard) = @splat(bb_pawn);
    const condition_vec: @Vector(types.board_size, types.Bitboard) = @splat(1);

    const counted_pawns = @popCount(types.mask_file & bb_pawn_vec);
    const is_doubled_file: @Vector(types.board_size, u3) = @intFromBool(counted_pawns > condition_vec);

    return @reduce(.Add, is_doubled_file * counted_pawns);
}

pub inline fn computeBlockedPawns(bb_pawn: types.Bitboard, comptime col: types.Color, blockers: types.Bitboard) types.Value {
    if (col.isWhite()) {
        return @popCount((bb_pawn <<| types.board_size) & blockers);
    } else {
        return @popCount((bb_pawn >> types.board_size) & blockers);
    }
}

pub fn computeIsolatedPawns(bb_pawn: types.Bitboard) types.Value {
    const left_neighbors = (bb_pawn & ~types.mask_file[types.File.fh.index()]) << 1;
    const right_neighbors = (bb_pawn & ~types.mask_file[types.File.fa.index()]) >> 1;
    const adjacent_pawns = left_neighbors | right_neighbors;
    const bb_pawn_vec: @Vector(types.board_size, types.Bitboard) = @splat(bb_pawn);
    const adjacent_pawns_vec: @Vector(types.board_size, types.Bitboard) = @splat(adjacent_pawns);

    const condition_vec: @Vector(types.board_size, types.Bitboard) = @splat(0);
    const is_isolated_file: @Vector(types.board_size, u3) = @intFromBool((types.mask_file & adjacent_pawns_vec) == condition_vec);

    // There needs to be at least a pawn in the column for it to be isolated
    const is_pawn_file: @Vector(types.board_size, u3) = @truncate(@popCount(types.mask_file & bb_pawn_vec));

    return @reduce(.Add, is_pawn_file * is_isolated_file);
}

// Protecting pawns are mutual so color does not matter
pub fn pawnStructure(bb_pawn: types.Bitboard) types.Value {
    const pawn_diagonal_left = (bb_pawn & ~types.mask_file[0]) << (types.board_size - 1);
    const pawn_diagonal_right = (bb_pawn & ~types.mask_file[types.board_size - 1]) << (types.board_size + 1);

    return @popCount((pawn_diagonal_right | pawn_diagonal_left) & bb_pawn);
}

// Chebyshev distance of kings
inline fn distanceKings(pos: position.Position) types.Value {
    var bb_king: types.Bitboard = pos.bb_pieces[types.PieceType.king.index()];
    std.debug.assert(@popCount(bb_king) == 2);
    const k1: types.Square = types.popLsb(&bb_king);
    const k2: types.Square = types.popLsb(&bb_king);

    return @intCast(@max(@abs(@as(types.Value, k1.rank().index()) - @as(types.Value, k2.rank().index())), @abs(@as(types.Value, k1.file().index()) - @as(types.Value, k2.file().index()))));
}

fn evaluateShannonColor(pos: position.Position, comptime col: types.Color) types.Value {
    const bb_us: types.Bitboard = pos.bb_colors[col.index()];
    const bb_them: types.Bitboard = pos.bb_colors[col.invert().index()];

    const bb_us_pawn: types.Bitboard = bb_us & pos.bb_pieces[types.PieceType.pawn.index()];

    // Compute pawn malus
    const malus_doubled_pawn: types.Value = computeDoubledPawns(bb_us_pawn);
    const malus_blocked_pawn: types.Value = computeBlockedPawns(bb_us_pawn, col, bb_us | bb_them);
    const malus_isolated_pawn: types.Value = computeIsolatedPawns(bb_us_pawn);

    // Does not include pawn quiet moves
    var mobility: types.Value = 0;

    const bb_all: types.Bitboard = bb_us | bb_them;
    for (types.PieceType.list()) |pt| {
        if (pt == types.PieceType.none or pt == types.PieceType.pawn)
            continue;
        var from_bb: types.Bitboard = pos.bb_pieces[pt.index()] & bb_us;
        while (from_bb != 0) {
            const from: types.Square = types.popLsb(&from_bb);
            const attackers: types.Bitboard = switch (pt) {
                .none => unreachable,
                inline else => |pt_current| tables.getAttacks(pt_current, col, from, bb_all),
            };
            mobility += @popCount(attackers & ~bb_us);
        }
    }

    return 20_000 * @as(types.Value, @popCount(pos.bb_pieces[types.PieceType.king.index()] & bb_us)) +
        900 * @as(types.Value, @popCount(pos.bb_pieces[types.PieceType.queen.index()] & bb_us)) +
        500 * @as(types.Value, @popCount(pos.bb_pieces[types.PieceType.rook.index()] & bb_us)) +
        300 * @as(types.Value, @popCount(pos.bb_pieces[types.PieceType.bishop.index()] & bb_us)) +
        300 * @as(types.Value, @popCount(pos.bb_pieces[types.PieceType.knight.index()] & bb_us)) +
        100 * @as(types.Value, @popCount(pos.bb_pieces[types.PieceType.pawn.index()] & bb_us)) +
        10 * mobility -
        50 * (malus_doubled_pawn + malus_blocked_pawn + malus_isolated_pawn);
}

pub fn evaluateMaterialist(pos: position.Position) types.Value {
    return (if (pos.state.turn.isWhite()) pos.score_material_w - pos.score_material_b else pos.score_material_b - pos.score_material_w);
}

pub fn evaluateShannon(pos: position.Position) types.Value {
    switch (pos.state.turn) {
        inline else => |turn| return evaluateShannonColor(pos, turn) - evaluateShannonColor(pos, turn.invert()),
    }
}

// TODO: take into account pinned ?
pub fn mobilityBonus(pos: position.Position, comptime color: types.Color) types.Value {
    const bb_us: types.Bitboard = pos.bb_colors[color.index()];
    const bb_them: types.Bitboard = pos.bb_colors[color.invert().index()];
    const bb_all: types.Bitboard = pos.bb_colors[types.Color.white.index()] | pos.bb_colors[types.Color.black.index()];
    var attacked_square: types.Bitboard = tables.getAttacksAllFiltered(.pawn, color.invert(), bb_all, bb_them & pos.bb_pieces[types.PieceType.pawn.index()]);
    var bonus: types.Value = 0;

    var knight_bb: types.Bitboard = pos.bb_pieces[types.PieceType.knight.index()] & bb_us;
    while (knight_bb != 0) {
        const sq: types.Square = types.popLsb(&knight_bb);
        bonus +|= variable.getValue("knight_mobility") *| @popCount(tables.getAttacks(.knight, color, sq, bb_all) & ~bb_us & ~attacked_square);
    }

    var bishop_bb: types.Bitboard = pos.bb_pieces[types.PieceType.bishop.index()] & bb_us;
    while (bishop_bb != 0) {
        const sq: types.Square = types.popLsb(&bishop_bb);
        bonus +|= variable.getValue("bishop_mobility") *| @popCount(tables.getAttacks(.bishop, color, sq, bb_all) & ~bb_us & ~attacked_square);
    }

    attacked_square |= tables.getAttacksAllFiltered(.knight, color.invert(), bb_all, ~attacked_square & bb_them & pos.bb_pieces[types.PieceType.knight.index()]);
    attacked_square |= tables.getAttacksAllFiltered(.bishop, color.invert(), bb_all, ~attacked_square & bb_them & pos.bb_pieces[types.PieceType.bishop.index()]);

    var rook_bb: types.Bitboard = pos.bb_pieces[types.PieceType.rook.index()] & bb_us;
    while (rook_bb != 0) {
        const sq: types.Square = types.popLsb(&rook_bb);
        bonus +|= variable.getValue("rook_mobility") *| @popCount(tables.getAttacks(.rook, color, sq, bb_all) & ~bb_us & ~attacked_square);
    }

    attacked_square |= tables.getAttacksAllFiltered(.rook, color.invert(), bb_all, ~attacked_square & bb_them & pos.bb_pieces[types.PieceType.rook.index()]);

    var queen_bb: types.Bitboard = pos.bb_pieces[types.PieceType.queen.index()] & bb_us;
    while (queen_bb != 0) {
        const sq: types.Square = types.popLsb(&queen_bb);
        bonus +|= variable.getValue("queen_mobility") *| @popCount(tables.getAttacks(.queen, color, sq, bb_all) & ~bb_us & ~attacked_square);
    }

    return bonus;
}

pub fn spaceBonus(pos: position.Position) types.Value {
    var bonus: types.Value = 0;

    // Vertical bonus

    const pawn_white_vec: @Vector(types.board_size, types.Bitboard) = @splat(pos.bb_pieces[types.PieceType.pawn.index()] & pos.bb_colors[types.Color.white.index()]);
    const pawn_black_vec: @Vector(types.board_size, types.Bitboard) = @splat(pos.bb_pieces[types.PieceType.pawn.index()] & pos.bb_colors[types.Color.black.index()]);

    const condition_vec: @Vector(types.board_size, types.Bitboard) = @splat(0);

    // Columns where there is a pawn
    const vertical_white: types.Bitboard = @reduce(.Or, types.mask_file * @intFromBool((types.mask_file & pawn_white_vec) != condition_vec));
    const vertical_black: types.Bitboard = @reduce(.Or, types.mask_file * @intFromBool((types.mask_file & pawn_black_vec) != condition_vec));

    const open_files: types.Bitboard = ~(vertical_white | vertical_black);
    const semi_open_files_white: types.Bitboard = ~(vertical_white) & vertical_black;
    const semi_open_files_black: types.Bitboard = ~(vertical_black) & vertical_white;

    bonus += variable.getValue("rook_open_files") * (@as(types.Value, @popCount(open_files & pos.bb_pieces[types.PieceType.rook.index()] & pos.bb_colors[types.Color.white.index()])) - @as(types.Value, @popCount(open_files & pos.bb_pieces[types.PieceType.rook.index()] & pos.bb_colors[types.Color.black.index()])));

    bonus += variable.getValue("rook_semi_open_files") * (@as(types.Value, @popCount(semi_open_files_white & pos.bb_pieces[types.PieceType.rook.index()] & pos.bb_colors[types.Color.white.index()])) - @as(types.Value, @popCount(semi_open_files_black & pos.bb_pieces[types.PieceType.rook.index()] & pos.bb_colors[types.Color.black.index()])));

    // Horizontal bonus

    // Can be a counting of ranks of safe pawn

    return bonus;
}

pub fn outpostBonus(knights_: types.Bitboard, pawns: types.Bitboard, pawns_them: types.Bitboard, comptime color: types.Color) types.Value {
    if (knights_ == 0 or pawns == 0)
        return 0;

    var count: types.Value = 0;
    var knights = knights_;

    // Remove unprotected knights
    var knight_diagonal_left: types.Bitboard = undefined;
    var knight_diagonal_right: types.Bitboard = undefined;
    if (color.isWhite()) {
        knight_diagonal_right = (knights & ~types.mask_file[types.board_size - 1]) >> (types.board_size - 1);
        knight_diagonal_left = (knights & ~types.mask_file[0]) >> (types.board_size + 1);
        const to_keep: types.Bitboard = (knight_diagonal_right & pawns) << (types.board_size - 1) | (knight_diagonal_left & pawns) << (types.board_size + 1);
        knights &= to_keep;
    } else {
        knight_diagonal_right = (knights & ~types.mask_file[types.board_size - 1]) << (types.board_size + 1);
        knight_diagonal_left = (knights & ~types.mask_file[0]) << (types.board_size - 1);
        const to_keep: types.Bitboard = (knight_diagonal_right & pawns) >> (types.board_size + 1) | (knight_diagonal_left & pawns) >> (types.board_size - 1);
        knights &= to_keep;
    }

    // Count outposts
    // Maybe this could be done without the while
    while (knights != 0) {
        const sq: types.Square = types.popLsb(&knights);
        // Use passed pawn filter without the current file
        const attackers: types.Bitboard = (tables.passed_pawn[color.index()][sq.index()] & ~types.mask_file[sq.file().index()]) & pawns_them;
        if (attackers == 0)
            count += 1;
    }
    return count;
}

// TODO: Add pawn structure hash
pub fn evaluateTable(pos: position.Position) types.Value {
    var score: types.Value = pos.score_material_w - pos.score_material_b;
    const endgame: bool = pos.endgame(pos.state.turn);

    const bb_white: types.Bitboard = pos.bb_colors[types.Color.white.index()];
    const bb_black: types.Bitboard = pos.bb_colors[types.Color.black.index()];
    const bb_all: types.Bitboard = bb_white | bb_black;

    // Evaluate king pseudo legal moveset
    // Malus for mg bonus for eg

    const white_king: types.Square = @enumFromInt(types.lsb(bb_white & pos.bb_pieces[types.PieceType.king.index()]));
    const black_king: types.Square = @enumFromInt(types.lsb(bb_black & pos.bb_pieces[types.PieceType.king.index()]));

    if (endgame) {
        const moveset_white_king = tables.getAttacks(.king, .white, white_king, bb_all) & ~bb_white;
        const moveset_black_king = tables.getAttacks(.king, .black, black_king, bb_all) & ~bb_black;
        score +|= @as(types.Value, @popCount(moveset_white_king)) - @as(types.Value, @popCount(moveset_black_king));
    } else {
        const moveset_white_king = tables.getAttacks(.queen, .white, white_king, bb_all) & ~bb_white;
        const moveset_black_king = tables.getAttacks(.queen, .black, black_king, bb_all) & ~bb_black;
        score -|= @as(types.Value, @popCount(moveset_white_king)) - @as(types.Value, @popCount(moveset_black_king));
    }

    // Evaluate space with open files (and some ranks ?)

    // Compute threats (by lesser pieces)

    // Compute potential checkers (queen slider from king with our pieces to remove blockers maybe ? expensive)

    score +|= mobilityBonus(pos, .white) - mobilityBonus(pos, .black);

    score +|= spaceBonus(pos);

    const bb_white_pawn_: types.Bitboard = bb_white & pos.bb_pieces[types.PieceType.pawn.index()];
    const bb_black_pawn_: types.Bitboard = bb_black & pos.bb_pieces[types.PieceType.pawn.index()];

    score -|=
        variable.getValue("pawn_isolated") *| (computeIsolatedPawns(bb_white_pawn_) - computeIsolatedPawns(bb_black_pawn_)) +|
        variable.getValue("pawn_doubled") *| (computeDoubledPawns(bb_white_pawn_) - computeDoubledPawns(bb_black_pawn_)) +|
        variable.getValue("pawn_blocked") *| (computeBlockedPawns(bb_white_pawn_, types.Color.white, bb_black) - computeBlockedPawns(bb_black_pawn_, types.Color.black, bb_white));

    score +|= variable.getValue("pawn_protection") * (pawnStructure(bb_white_pawn_) - pawnStructure(bb_white_pawn_));

    var bb_white_pawn: types.Bitboard = bb_white_pawn_;
    while (bb_white_pawn != 0) {
        const sq: types.Square = types.popLsb(&bb_white_pawn);
        if (tables.passed_pawn[types.Color.white.index()][sq.index()] & bb_black_pawn_ == 0) {
            score +|= tables.passed_pawn_table[sq.rank().relativeRank(types.Color.white).index()];
        }
    }

    var bb_black_pawn: types.Bitboard = bb_black_pawn_;
    while (bb_black_pawn != 0) {
        const sq: types.Square = types.popLsb(&bb_black_pawn);
        if (tables.passed_pawn[types.Color.black.index()][sq.index()] & bb_white_pawn_ == 0) {
            score -|= tables.passed_pawn_table[sq.rank().relativeRank(types.Color.black).index()];
        }
    }

    const knights: types.Bitboard = pos.bb_pieces[types.PieceType.knight.index()];
    const knights_white: types.Bitboard = bb_white & knights;
    const knights_black: types.Bitboard = bb_black & knights;

    score +|= variable.getValue("outpost") * (outpostBonus(knights_white, bb_white_pawn_, bb_black_pawn_, .white) - outpostBonus(knights_black, bb_black_pawn_, bb_white_pawn_, .black));

    const bishops: types.Bitboard = pos.bb_pieces[types.PieceType.bishop.index()];
    const bishops_white: types.Bitboard = bb_white & bishops;
    const bishops_black: types.Bitboard = bb_black & bishops;

    const white_pair: types.Value = @intFromBool(@popCount(bishops_white) >= 2);
    const black_pair: types.Value = @intFromBool(@popCount(bishops_black) >= 2);
    score +|= variable.getValue("bishop_pair") * (white_pair - black_pair);

    if (endgame) {
        if (score > 0) {
            score +|= -pos.score_king_b;
        } else if (score < 0) {
            score +|= pos.score_king_w;
        }
        score +|= if (pos.state.turn.isWhite()) distanceKings(pos) else -distanceKings(pos);
    } else {
        // Pawn bonus when in side of king
        const filter_left = types.file | types.file >> 1 | types.file >> 2 | types.file >> 3;
        const filter_right = types.file >> 4 | types.file >> 5 | types.file >> 6 | types.file >> 7;
        if (white_king.file().index() < 4) {
            score +|= variable.getValue("pawn_defend_king") *| @popCount(filter_left & bb_white_pawn_);
        } else {
            score +|= variable.getValue("pawn_defend_king") *| @popCount(filter_right & bb_white_pawn_);
        }
        if (black_king.file().index() < 4) {
            score -|= variable.getValue("pawn_defend_king") *| @popCount(filter_left & bb_black_pawn_);
        } else {
            score -|= variable.getValue("pawn_defend_king") *| @popCount(filter_right & bb_black_pawn_);
        }
    }

    const tapered: i64 = @divTrunc(@as(i64, pos.score_material_w + pos.score_material_b - 2 * tables.material[types.PieceType.king.index()]) * 10_000, (4152 * 2));
    score +|= @truncate(@divTrunc(tapered * pos.score_mg, 10_000));
    score +|= @truncate(@divTrunc((10_000 - tapered) * pos.score_eg, 10_000));

    return if (pos.state.turn.isWhite()) score else -score;
}
