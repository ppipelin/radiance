const position = @import("position.zig");
const std = @import("std");
const tables = @import("tables.zig");
const types = @import("types.zig");

inline fn computeDoubledPawns(bb_pawn: types.Bitboard) types.Value {
    var doubled_pawns: types.Value = 0;
    for (types.mask_file) |mask| {
        if (@popCount(mask & bb_pawn) > 1)
            doubled_pawns += 1;
    }
    return doubled_pawns;
}

inline fn computeBlockedPawns(bb_pawn: types.Bitboard, col: types.Color, blockers: types.Bitboard) types.Value {
    if (col.isWhite()) {
        return @popCount((bb_pawn <<| types.board_size) & blockers);
    } else {
        return @popCount((bb_pawn >> types.board_size) & blockers);
    }
}

inline fn computeIsolatedPawns(bb_pawn: types.Bitboard) types.Value {
    const left_neighbors = (bb_pawn & ~types.mask_file[types.File.fh.index()]) >> 1;
    const right_neighbors = (bb_pawn & ~types.mask_file[types.File.fa.index()]) << 1;
    var adjacent_pawns = left_neighbors | right_neighbors;

    for (types.mask_file) |mask| {
        if ((mask & adjacent_pawns) > 1)
            adjacent_pawns |= mask;
    }

    return @popCount(bb_pawn & ~adjacent_pawns);
}

// Chebyshev distance of kings
inline fn distanceKings(pos: position.Position) types.Value {
    var bb_king: types.Bitboard = pos.bb_pieces[types.PieceType.king.index()];
    std.debug.assert(@popCount(bb_king) == 2);
    const k1: types.Square = types.popLsb(&bb_king);
    const k2: types.Square = types.popLsb(&bb_king);

    return @intCast(@max(@abs(@as(types.Value, k1.rank().index()) - @as(types.Value, k2.rank().index())), @abs(@as(types.Value, k1.file().index()) - @as(types.Value, k2.file().index()))));
}

fn evaluateShannonColor(pos: position.Position, col: types.Color) types.Value {
    const bb_us: types.Bitboard = pos.bb_colors[col.index()];
    const bb_them: types.Bitboard = pos.bb_colors[col.invert().index()];

    const bb_us_pawn: types.Bitboard = bb_us & pos.bb_pieces[types.PieceType.pawn.index()];

    // Compute pawn malus
    const malus_doubled_pawn: types.Value = computeDoubledPawns(bb_us_pawn);
    const malus_blocked_pawn: types.Value = computeBlockedPawns(bb_us_pawn, col, bb_us | bb_them);
    const malus_isolated_pawn: types.Value = computeIsolatedPawns(bb_us_pawn);

    // var move_list: std.ArrayListUnmanaged(types.Move) = .empty;
    // defer move_list.deinit(std.heap.c_allocator);
    // var pos_tmp = pos;
    // pos_tmp.generateLegalMoves(std.heap.c_allocator, col, &move_list);
    // const mobility: types.Value = @intCast(move_list.items.len);
    const mobility: types.Value = 0;

    return 20_000 * @as(types.Value, @popCount(pos.bb_pieces[types.PieceType.king.index()] & bb_us)) +
        900 * @as(types.Value, @popCount(pos.bb_pieces[types.PieceType.queen.index()] & bb_us)) +
        500 * @as(types.Value, @popCount(pos.bb_pieces[types.PieceType.rook.index()] & bb_us)) +
        300 * @as(types.Value, @popCount(pos.bb_pieces[types.PieceType.bishop.index()] & bb_us)) +
        300 * @as(types.Value, @popCount(pos.bb_pieces[types.PieceType.knight.index()] & bb_us)) +
        100 * @as(types.Value, @popCount(pos.bb_pieces[types.PieceType.pawn.index()] & bb_us)) +
        10 * mobility -
        50 * (malus_doubled_pawn + malus_blocked_pawn + malus_isolated_pawn);
}

pub fn evaluateShannon(pos: position.Position) types.Value {
    return evaluateShannonColor(pos, pos.state.turn) - evaluateShannonColor(pos, pos.state.turn.invert());
}

pub fn evaluateTable(pos: position.Position) types.Value {
    var score: types.Value = pos.score_material_w - pos.score_material_b;

    // Compute score based on the endgame condition
    // Once ennemy has less pieces our king attacks the other one
    // King, seven pawns a rook and a bishop
    const endgame: bool = (if (pos.state.turn.isWhite()) pos.score_material_b else pos.score_material_w) <= tables.material[types.PieceType.king.index()] + 7 * tables.material[types.PieceType.pawn.index()] + tables.material[types.PieceType.rook.index()] + tables.material[types.PieceType.bishop.index()];
    if (endgame) {
        score += if (pos.state.turn.isWhite()) distanceKings(pos) else -distanceKings(pos);
        if (pos.score_material_w > pos.score_material_b) {
            score += -pos.score_king_b;
        } else if (pos.score_material_w < pos.score_material_b) {
            score += pos.score_king_w;
        }
        score += pos.score_eg;
    } else {
        score += pos.score_mg;
    }

    const bb_white: types.Bitboard = pos.bb_colors[types.Color.white.index()];
    const bb_black: types.Bitboard = pos.bb_colors[types.Color.black.index()];
    const bb_all: types.Bitboard = bb_white | bb_black;

    // Evaluate king pseudo legal moveset
    // Malus for mg bonus for eg

    const moveset_white_king = tables.getAttacks(types.PieceType.bishop, types.Color.white, @enumFromInt(types.lsb(bb_white & (pos.bb_pieces[types.PieceType.king.index()]))), bb_all) & ~bb_white;
    const moveset_black_king = tables.getAttacks(types.PieceType.bishop, types.Color.black, @enumFromInt(types.lsb(bb_black & (pos.bb_pieces[types.PieceType.king.index()]))), bb_all) & ~bb_black;

    if (endgame) {
        score += @as(types.Value, @popCount(moveset_white_king)) - @as(types.Value, @popCount(moveset_black_king));
    } else {
        score -= @as(types.Value, @popCount(moveset_white_king)) - @as(types.Value, @popCount(moveset_black_king));
    }

    // Evaluate sliders pseudo legal moveset
    var white_sliders_diag: types.Bitboard = bb_white & (pos.bb_pieces[types.PieceType.bishop.index()] | pos.bb_pieces[types.PieceType.queen.index()]);
    var white_sliders_orth: types.Bitboard = bb_white & (pos.bb_pieces[types.PieceType.rook.index()] | pos.bb_pieces[types.PieceType.queen.index()]);

    var black_sliders_diag: types.Bitboard = bb_black & (pos.bb_pieces[types.PieceType.bishop.index()] | pos.bb_pieces[types.PieceType.queen.index()]);
    var black_sliders_orth: types.Bitboard = bb_black & (pos.bb_pieces[types.PieceType.rook.index()] | pos.bb_pieces[types.PieceType.queen.index()]);

    var moveset_white_diag: types.Bitboard = 0;
    var moveset_white_orth: types.Bitboard = 0;

    var moveset_black_diag: types.Bitboard = 0;
    var moveset_black_orth: types.Bitboard = 0;
    while (white_sliders_diag != 0) {
        const sq: types.Square = types.popLsb(&white_sliders_diag);
        moveset_white_diag |= tables.getAttacks(types.PieceType.bishop, types.Color.white, sq, bb_all) & ~bb_white;
    }

    while (white_sliders_orth != 0) {
        const sq: types.Square = types.popLsb(&white_sliders_orth);
        moveset_white_orth |= tables.getAttacks(types.PieceType.rook, types.Color.white, sq, bb_all) & ~bb_white;
    }

    while (black_sliders_diag != 0) {
        const sq: types.Square = types.popLsb(&black_sliders_diag);
        moveset_black_diag |= tables.getAttacks(types.PieceType.bishop, types.Color.black, sq, bb_all) & ~bb_black;
    }

    while (black_sliders_orth != 0) {
        const sq: types.Square = types.popLsb(&black_sliders_orth);
        moveset_black_orth |= tables.getAttacks(types.PieceType.rook, types.Color.black, sq, bb_all) & ~bb_black;
    }

    score += 5 * (@as(types.Value, @popCount(moveset_white_diag)) + @as(types.Value, @popCount(moveset_white_orth)));
    score -= 5 * (@as(types.Value, @popCount(moveset_black_diag)) + @as(types.Value, @popCount(moveset_black_orth)));

    const bb_white_pawn_: types.Bitboard = bb_white & pos.bb_pieces[types.PieceType.pawn.index()];
    const bb_black_pawn_: types.Bitboard = bb_black & pos.bb_pieces[types.PieceType.pawn.index()];

    score -=
        50 * (computeIsolatedPawns(bb_white_pawn_) - computeIsolatedPawns(bb_black_pawn_)) +
        20 * (computeDoubledPawns(bb_white_pawn_) - computeDoubledPawns(bb_black_pawn_)) +
        10 * (computeBlockedPawns(bb_white_pawn_, types.Color.white, bb_all) - computeBlockedPawns(bb_black_pawn_, types.Color.black, bb_all));

    var bb_white_pawn: types.Bitboard = bb_white_pawn_;
    while (bb_white_pawn != 0) {
        const sq: types.Square = types.popLsb(&bb_white_pawn);
        if (tables.passed_pawn[types.Color.white.index()][sq.index()] & bb_black_pawn_ == 0) {
            score += tables.passed_pawn_table[sq.rank().relativeRank(types.Color.white).index()];
        }
    }

    var bb_black_pawn: types.Bitboard = bb_black_pawn_;
    while (bb_black_pawn != 0) {
        const sq: types.Square = types.popLsb(&bb_black_pawn);
        if (tables.passed_pawn[types.Color.black.index()][sq.index()] & bb_white_pawn_ == 0) {
            score -= tables.passed_pawn_table[sq.rank().relativeRank(types.Color.black).index()];
        }
    }

    return if (pos.state.turn.isWhite()) score else -score;
}
