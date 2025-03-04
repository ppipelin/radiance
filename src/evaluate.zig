const position = @import("position.zig");
const types = @import("types.zig");

inline fn computeDoubledPawns(us_bb_pawn: types.Bitboard) types.Value {
    var doubled_pawns: types.Value = 0;
    for (types.mask_file) |mask| {
        if (@popCount(mask & us_bb_pawn) > 1)
            doubled_pawns += 1;
    }
    return doubled_pawns;
}

inline fn computeBlockedPawns(us_bb_pawn: types.Bitboard, col: types.Color, blockers: types.Bitboard) types.Value {
    if (col.isWhite()) {
        return @popCount((us_bb_pawn <<| types.board_size) & blockers);
    } else {
        return @popCount((us_bb_pawn >> types.board_size) & blockers);
    }
}

inline fn computeIsolatedPawns(us_bb_pawn: types.Bitboard) types.Value {
    const left_neighbors = (us_bb_pawn & ~types.mask_file[types.File.fh.index()]) >> 1;
    const right_neighbors = (us_bb_pawn & ~types.mask_file[types.File.fa.index()]) << 1;
    var adjacent_pawns = left_neighbors | right_neighbors;

    for (types.mask_file) |mask| {
        if ((mask & adjacent_pawns) > 1)
            adjacent_pawns |= mask;
    }

    return @popCount(us_bb_pawn & ~adjacent_pawns);
}

fn evaluateShannonColor(pos: position.Position, col: types.Color) types.Value {
    const us_bb: types.Bitboard = pos.bb_colors[col.index()];
    const them_bb: types.Bitboard = pos.bb_colors[col.invert().index()];

    const us_bb_pawn: types.Bitboard = us_bb & pos.bb_pieces[types.PieceType.pawn.index()];

    // Compute pawn malus
    const malus_doubled_pawn: types.Value = computeDoubledPawns(us_bb_pawn);
    const malus_blocked_pawn: types.Value = computeBlockedPawns(us_bb_pawn, col, us_bb | them_bb);
    const malus_isolated_pawn: types.Value = computeIsolatedPawns(us_bb_pawn);

    // var move_list: std.ArrayListUnmanaged(types.Move) = .empty;
    // defer move_list.deinit(std.heap.c_allocator);
    // var pos_tmp = pos;
    // pos_tmp.generateLegalMoves(std.heap.c_allocator, col, &move_list);
    // const mobility: types.Value = @intCast(move_list.items.len);
    const mobility: types.Value = 0;

    return 20_000 * @as(types.Value, @popCount(pos.bb_pieces[types.PieceType.king.index()] & us_bb)) +
        900 * @as(types.Value, @popCount(pos.bb_pieces[types.PieceType.queen.index()] & us_bb)) +
        500 * @as(types.Value, @popCount(pos.bb_pieces[types.PieceType.rook.index()] & us_bb)) +
        300 * @as(types.Value, @popCount(pos.bb_pieces[types.PieceType.bishop.index()] & us_bb)) +
        300 * @as(types.Value, @popCount(pos.bb_pieces[types.PieceType.knight.index()] & us_bb)) +
        100 * @as(types.Value, @popCount(pos.bb_pieces[types.PieceType.pawn.index()] & us_bb)) +
        10 * mobility -
        50 * (malus_doubled_pawn + malus_blocked_pawn + malus_isolated_pawn);
}

pub fn evaluateShannon(pos: position.Position) types.Value {
    return evaluateShannonColor(pos, pos.state.turn) - evaluateShannonColor(pos, pos.state.turn.invert());
}

pub fn evaluateTable(pos: position.Position) types.Value {
    _ = pos;
    return 0;
}
