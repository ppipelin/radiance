const interface = @import("interface.zig");
const position = @import("position.zig");
const std = @import("std");
const tables = @import("tables.zig");
const types = @import("types.zig");

var root_moves: std.ArrayListUnmanaged(RootMove) = .empty;

const NodeType = enum {
    non_pv,
    pv,
    root,
};

const RootMove = struct {
    score: types.Value = -types.value_infinite,
    previous_score: types.Value = -types.value_infinite,
    average_score: types.Value = -types.value_infinite,
    pv: std.ArrayListUnmanaged(types.Move) = .empty,

    fn sort(context: void, a: RootMove, b: RootMove) bool {
        _ = context;
        if (a.score == b.score)
            return a.previous_score > b.previous_score;

        return a.score > b.score;
    }
};

const Stack = struct {
    // pv: [200]types.Move = [_]types.Move{.none} ** 200,
    pv: ?*[200]types.Move = null,
    killers: [2]?types.Move = [_]?types.Move{ null, null },
    ply: u8 = 0,
};

inline fn elapsed(limits: interface.Limits) types.TimePoint {
    return (types.now() - limits.start);
}

inline fn outOfTime(limits: interface.Limits) bool {
    if (interface.g_stop)
        return true;
    if (limits.infinite or interface.remaining == 0) return false;

    const remaining_float: f128 = @floatFromInt(interface.remaining);
    const increment_float: f128 = @floatFromInt(interface.increment);
    const remaining_computed: types.TimePoint = @intFromFloat(@min(remaining_float * 0.95, remaining_float / 30.0 + increment_float));
    return elapsed(limits) > remaining_computed;
}

pub fn perft(allocator: std.mem.Allocator, stdout: anytype, pos: *position.Position, depth: u8, is_960: bool, verbose: bool) !u64 {
    var nodes: u64 = 0;
    var move_list: std.ArrayListUnmanaged(types.Move) = .empty;
    defer move_list.deinit(allocator);

    if (depth == 0 or interface.g_stop) {
        return 1;
    }

    pos.generateLegalMoves(allocator, types.GenerationType.all, pos.state.turn, &move_list, is_960);

    if (depth == 1) {
        if (verbose) {
            try types.Move.displayMoves(stdout, move_list);
        }
        return move_list.items.len;
    }

    for (move_list.items) |move| {
        var s: position.State = position.State{};

        try pos.movePiece(move, &s);

        const nodes_number = try (perft(allocator, stdout, pos, depth - 1, is_960, false));
        nodes += nodes_number;
        if (verbose) {
            try move.printUCI(stdout);
            try stdout.print(", {} : {}\n", .{ move.getFlags(), nodes_number });
        }

        try pos.unMovePiece(move);
    }
    return nodes;
}

pub fn perftTest(allocator: std.mem.Allocator, pos: *position.Position, depth: u8, is_960: bool) !u64 {
    var nodes: u64 = 0;
    var move_list: std.ArrayListUnmanaged(types.Move) = .empty;
    defer move_list.deinit(allocator);

    if (depth == 0) {
        return 1;
    }

    pos.generateLegalMoves(allocator, types.GenerationType.all, pos.state.turn, &move_list, is_960);

    if (depth == 1)
        return move_list.items.len;

    for (move_list.items) |move| {
        var s: position.State = position.State{};

        var fen_before: [90]u8 = undefined;
        const fen_before_c = pos.getFen(&fen_before);
        const score_before = [_]types.Value{ pos.score_material_w, pos.score_material_b };
        const key_before = pos.state.material_key;

        try pos.movePiece(move, &s);

        const nodes_number = try (perftTest(allocator, pos, depth - 1, is_960));
        nodes += nodes_number;

        try pos.unMovePiece(move);

        var fen_after: [90]u8 = undefined;
        const fen_after_c = pos.getFen(&fen_after);
        const score_after = [_]types.Value{ pos.score_material_w, pos.score_material_b };
        const key_after = pos.state.material_key;

        if (!std.mem.eql(u8, fen_before_c, fen_after_c)) {
            return error.DifferentFen;
        }

        if (score_before[0] != score_after[0] or score_before[1] != score_after[1]) {
            return error.DifferentScore;
        }

        if (key_before != key_after) {
            return error.DifferentKey;
        }
    }
    return nodes;
}

pub fn searchRandom(allocator: std.mem.Allocator, pos: *position.Position, is_960: bool) !types.Move {
    var move_list: std.ArrayListUnmanaged(types.Move) = .empty;
    defer move_list.deinit(allocator);

    pos.updateAttacked();
    pos.generateLegalMoves(allocator, types.GenerationType.all, pos.state.turn, &move_list, is_960);

    if (move_list.items.len == 0)
        return error.MoveAfterCheckmate;
    var prng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();
    const len: u8 = @intCast(move_list.items.len);
    return move_list.items[rand.intRangeAtMost(u8, 0, len - 1)];
}

pub fn iterativeDeepening(allocator: std.mem.Allocator, stdout: anytype, pos: *position.Position, limits: interface.Limits, eval: *const fn (pos: position.Position) types.Value, options: std.StringArrayHashMapUnmanaged(interface.Option)) !types.Move {
    const is_960: bool = std.mem.eql(u8, options.get("UCI_Chess960").?.current_value, "true");

    if (limits.movetime > 0) {
        interface.remaining = limits.movetime * 30;
    } else {
        interface.remaining = if (pos.state.turn.isWhite()) limits.time[types.Color.white.index()] else limits.time[types.Color.black.index()];
        interface.increment = if (pos.state.turn.isWhite()) limits.inc[types.Color.white.index()] else limits.inc[types.Color.black.index()];
    }

    var stack: [200 + 10]Stack = [_]Stack{.{}} ** (200 + 10);
    var pv: [200]types.Move = [_]types.Move{.none} ** 200; // useless
    var ss: [*]Stack = &stack;
    ss = ss + 7;

    tables.transposition_table.clearRetainingCapacity();

    for (0..200) |i| {
        ss[i].ply = @intCast(i);
    }
    ss[0].pv = &pv;

    var move_list: std.ArrayListUnmanaged(types.Move) = .empty;
    defer move_list.deinit(allocator);

    pos.updateAttacked();
    pos.generateLegalMoves(allocator, types.GenerationType.all, pos.state.turn, &move_list, is_960);

    const root_moves_len: usize = move_list.items.len;
    if (root_moves_len == 0) {
        return error.Checkmated;
    } else if (root_moves_len == 1) {
        return move_list.items[0];
    }

    // Order moves
    pos.orderMoves(&move_list, types.Move.none);

    try root_moves.ensureTotalCapacity(allocator, root_moves_len);
    defer root_moves.clearAndFree(allocator);
    root_moves.clearRetainingCapacity();

    // limits.searchmoves here

    for (move_list.items) |move| {
        var pv_rm: std.ArrayListUnmanaged(types.Move) = .empty;
        try pv_rm.ensureTotalCapacity(allocator, 200);
        pv_rm.appendAssumeCapacity(move);
        root_moves.appendAssumeCapacity(RootMove{ .pv = pv_rm });
    }

    interface.nodes_searched = 0;
    interface.seldepth = 0;
    interface.transposition_used = 0;

    var current_depth: u8 = 1;
    while (current_depth <= limits.depth) : (current_depth += 1) {
        // Some variables have to be reset
        for (root_moves.items) |*root_move| {
            root_move.previous_score = root_move.score;
            root_move.score = -types.value_infinite;
        }

        // Reset aspiration window starting size
        const prev: types.Value = root_moves.items[0].average_score;
        var delta: types.Value = @intCast(@abs(@divTrunc(prev, 2)) + 10);
        var alpha: types.Value = @max(prev -| delta, -types.value_infinite);
        var beta: types.Value = @min(prev +| delta, types.value_infinite);
        var failed_high_cnt: u32 = 0;

        // Aspiration window
        // Disable by alpha = -types.value_infinite; beta = types.value_infinite;
        // alpha = -types.value_infinite; beta = types.value_infinite;
        while (true) {
            const score: types.Value = try abSearch(allocator, NodeType.root, ss, pos, limits, eval, alpha, beta, current_depth, is_960, false);
            if (current_depth > 1 and outOfTime(limits))
                break;

            // In case of failing low/high increase aspiration window and re-search, otherwise exit the loop.
            if (score <= alpha) {
                beta = @divTrunc(alpha + beta, 2);
                alpha = @max(score -| delta, -types.value_infinite);
                failed_high_cnt = 0;
            } else if (score >= beta) {
                beta = @min(score +| delta, types.value_infinite);
                failed_high_cnt += 1;
            } else {
                break;
            }

            std.sort.insertion(RootMove, root_moves.items, {}, RootMove.sort);

            delta +|= @divTrunc(delta, 3);
        }

        // Even if outofTime we keep a better move if there is one
        std.sort.insertion(RootMove, root_moves.items, {}, RootMove.sort);

        if (current_depth > 1 and outOfTime(limits)) {
            break;
        }

        try stdout.print("info failedHighCnt {} alpha {} beta {}\n", .{ failed_high_cnt, alpha, beta });
        try info(stdout, limits, current_depth, root_moves.items[0].score, options);
    }

    // Even if outofTime we keep a better move if there is one
    const move = root_moves.items[0].pv.items[0];

    for (root_moves.items) |*root_move| {
        root_move.pv.deinit(allocator);
    }

    return move;
}

fn abSearch(allocator: std.mem.Allocator, comptime nodetype: NodeType, ss: [*]Stack, pos: *position.Position, limits: interface.Limits, eval: *const fn (pos: position.Position) types.Value, alpha_: types.Value, beta_: types.Value, current_depth: u8, is_960: bool, is_nmr: bool) !types.Value {
    const pv_node: bool = nodetype != NodeType.non_pv;
    const root_node: bool = nodetype == NodeType.root;

    var alpha = alpha_;
    var beta = beta_;

    interface.nodes_searched += 1;

    // Quiescence search at depth 0 and razoring for non_pv where material difference is more than q+r+b
    // const razoring_threshold = (tables.material[types.PieceType.queen.index()] + tables.material[types.PieceType.rook.index()] + tables.material[types.PieceType.bishop.index()]);
    // const razoring: bool = (if (pos.state.turn.isWhite()) pos.score_material_b - pos.score_material_w else pos.score_material_w - pos.score_material_b) >= razoring_threshold;
    // or (!pv_node and razoring)
    if (current_depth <= 0) {
        // return eval(pos.*);
        return quiesce(allocator, if (pv_node) NodeType.pv else NodeType.non_pv, ss, pos, limits, eval, alpha, beta, is_nmr);
    }

    // Initialize data
    var s: position.State = position.State{};
    var pv: [200]types.Move = [_]types.Move{.none} ** 200;
    var score: types.Value = -types.value_none;
    var best_score: types.Value = -types.value_none;

    // Initialize node
    var move_count: u16 = 0;

    // Pruning
    if (@popCount(pos.state.checkers) == 0) {
        const static_eval: types.Value = eval(pos.*);

        // Reverse Futility Pruning
        if (!pv_node and current_depth <= 8 and beta < types.value_mate_in_max_depth) {
            const futility_margin: types.Value = @as(types.Value, current_depth) * 80;
            if (static_eval - futility_margin >= beta)
                return beta;
        }

        // Null move pruning
        if (!is_nmr and current_depth >= 3 and !pos.endgame(pos.state.turn.invert()) and static_eval > beta) {
            const tapered: u8 = @intCast(@min(@divTrunc(static_eval - beta, 200), 6));
            const r: u8 = tapered + @divTrunc(current_depth, 3) + 5;
            try pos.moveNull(&s);
            const null_score: types.Value = -try abSearch(allocator, NodeType.non_pv, ss + 1, pos, limits, eval, -beta, -beta + 1, current_depth -| r, is_960, true);
            try pos.unMoveNull();
            if (current_depth > 1 and outOfTime(limits))
                return -types.value_none;

            // Do not return unproven mate
            if (null_score >= beta and null_score < types.value_mate_in_max_depth) {
                return null_score;
            }
        }
    }

    var move_list: std.ArrayListUnmanaged(types.Move) = .empty;
    defer move_list.deinit(allocator);

    if (root_node) {
        for (root_moves.items) |root_move| {
            try move_list.append(allocator, root_move.pv.items[0]);
        }
    } else {
        pos.generateLegalMoves(allocator, types.GenerationType.all, pos.state.turn, &move_list, is_960);
        var pv_move: types.Move = types.Move.none;
        if (root_moves.items[0].pv.items.len > ss[0].ply) {
            pv_move = root_moves.items[0].pv.items[ss[0].ply];
        }
        pos.orderMoves(&move_list, pv_move);
    }

    // Loop over all legal moves
    for (move_list.items) |move| {
        if (is_nmr and pos.board[move.getTo().index()].pieceToPieceType() == types.PieceType.king) {
            return -types.value_mate;
        }
        score = -types.value_none;
        move_count += 1;
        if (pv_node) {
            ss[1].pv = null;
        }

        const key: tables.Key = pos.state.material_key;

        try pos.movePiece(move, &s);

        ss[1].pv = &pv;
        ss[1].pv.?[0] = types.Move.none;

        if (pos.state.repetition < 0) {
            score = types.value_draw;
        } else {
            const found: ?std.meta.Tuple(&[_]type{ types.Value, u8, types.Move, types.TableBound }) = tables.transposition_table.get(key);
            if (found != null) {
                var tt_eval = found.?[0];
                if (score > types.value_mate_in_max_depth) {
                    tt_eval -= ss[0].ply;
                } else if (score < types.value_mated_in_max_depth) {
                    tt_eval += ss[0].ply;
                }

                if (!is_nmr and !pv_node and found.?[1] > current_depth - 1) {
                    switch (found.?[3]) {
                        .exact => score = tt_eval,
                        .lowerbound => alpha = @max(alpha, score),
                        .upperbound => beta = @min(beta, score),
                    }
                    if (alpha >= beta) {
                        score = tt_eval;
                    }
                }
                interface.transposition_used += 1;
            }

            if (score == -types.value_none) {
                // Passed pawns moves are not reduced
                const from_piece: types.Piece = pos.board[move.getFrom().index()];
                var is_passed_pawn: bool = false;
                if (from_piece.pieceToPieceType() == types.PieceType.pawn) {
                    const bb_them_pawn: types.Bitboard = pos.bb_colors[pos.state.turn.invert().index()] & pos.bb_pieces[types.PieceType.pawn.index()];
                    is_passed_pawn = (tables.passed_pawn[pos.state.turn.index()][move.getFrom().index()] & bb_them_pawn) == 0;
                }

                // LMR before full
                if (current_depth >= 2 and move_count > 3 and pos.state.checkers == 0 and !move.isCapture() and !move.isPromotion() and !is_passed_pawn) {
                    // Reduced LMR
                    const d: u8 = @max(1, current_depth -| 4);
                    score = -try abSearch(allocator, NodeType.non_pv, ss + 1, pos, limits, eval, -(alpha + 1), -alpha, d - 1, is_960, false);
                    // Failed so roll back to full-depth null window
                    if (score > alpha and current_depth > d) {
                        score = -try abSearch(allocator, NodeType.non_pv, ss + 1, pos, limits, eval, -(alpha + 1), -alpha, current_depth - 1, is_960, false);
                    }
                }
                // In case non PV search are called without LMR, null window search at current depth
                else if (!pv_node or move_count > 1) {
                    score = -try abSearch(allocator, NodeType.non_pv, ss + 1, pos, limits, eval, -(alpha + 1), -alpha, current_depth - 1, is_960, false);
                }
                // Full-depth search
                if (pv_node and (move_count == 1 or score > alpha)) {
                    score = -try abSearch(allocator, NodeType.pv, ss + 1, pos, limits, eval, -beta, -alpha, current_depth - 1 + @intFromBool(pos.state.checkers != 0), is_960, false);
                    // Let's assert we don't store draw (repetition)
                    if (score != types.value_draw) {
                        if (found == null or found.?[1] <= current_depth - 1) {
                            const tt_flag: types.TableBound = if (score >= beta) .lowerbound else if (alpha != alpha_) .exact else .upperbound;

                            try tables.transposition_table.put(allocator, key, .{ score, current_depth - 1, move, tt_flag });
                        }
                    }
                }
            }
        }

        // Undo move
        try pos.unMovePiece(move);

        // Useless ?
        if (current_depth > 1 and outOfTime(interface.limits))
            return -types.value_none;

        if (root_node) {
            for (root_moves.items) |*root_move| {
                if (root_move.pv.items[0] != move)
                    continue;

                root_move.average_score = if (root_move.average_score == -types.value_infinite) score else @divTrunc(score +| root_move.average_score, 2);

                if (move_count == 1 or score > alpha) {
                    root_move.score = score;

                    // New principal variation to update for current root move
                    root_move.pv.shrinkRetainingCapacity(1);
                    for (ss[1].pv.?) |pv_move| {
                        if (pv_move == types.Move.none) {
                            break;
                        }
                        root_move.pv.appendAssumeCapacity(pv_move);
                    }
                } else {
                    root_move.score = -types.value_infinite;
                }
                break;
            }
        }

        // Update ss->pv
        if (score > best_score) {
            best_score = score;
            if (score > alpha) {
                if (pv_node and !root_node) // Update pv even in fail-high case
                {
                    update_pv(ss[0].pv.?, move, ss[1].pv.?);
                }

                // Fail high
                if (score >= beta) {
                    if (score != types.value_draw) {
                        const found: ?std.meta.Tuple(&[_]type{ types.Value, u8, types.Move, types.TableBound }) = tables.transposition_table.get(key);
                        if (found == null or found.?[1] <= current_depth - 1) {
                            try tables.transposition_table.put(allocator, key, .{ score, current_depth - 1, move, .lowerbound });
                        }
                    }
                    break;
                } else {
                    alpha = score; // Update alpha! Always alpha < beta
                }
            }
        }
    }

    if (move_list.items.len == 0) {
        if (pos.state.checkers != 0)
            return -types.value_mate + @as(types.Value, ss[0].ply);
        return types.value_stalemate;
    }

    return best_score;
}

fn quiesce(allocator: std.mem.Allocator, comptime nodetype: NodeType, ss: [*]Stack, pos: *position.Position, limits: interface.Limits, eval: *const fn (pos: position.Position) types.Value, alpha_: types.Value, beta: types.Value, is_nmr: bool) !types.Value {
    const pv_node: bool = nodetype == NodeType.pv;

    var alpha = alpha_;

    interface.nodes_searched += 1;
    if (interface.seldepth < ss[0].ply + 1) {
        interface.seldepth = ss[0].ply + 1;
    }

    // In order to get the quiescence search to terminate, plies are usually restricted to moves that deal directly with the threat,
    // such as moves that capture and recapture (often called a 'capture search') in chess
    const stand_pat: types.Value = eval(pos.*);
    if (stand_pat >= beta)
        return beta;

    // Initialize data
    var s: position.State = position.State{};
    var pv: [200]types.Move = [_]types.Move{.none} ** 200;
    var score: types.Value = -types.value_none;

    // Initialize node
    if (pv_node) {
        ss[1].pv = &pv;
        ss[0].pv.?[0] = types.Move.none;
    }

    var move_list_capture: std.ArrayListUnmanaged(types.Move) = .empty;
    defer move_list_capture.deinit(allocator);
    pos.generateLegalCaptures(allocator, pos.state.turn, &move_list_capture);
    pos.orderMoves(&move_list_capture, types.Move.none);

    // Delta pruning
    const margin: types.Value = 200;

    if (!pos.endgame(pos.state.turn)) {
        var best_capture: types.Value = tables.material[types.PieceType.queen.index()];
        for (move_list_capture.items) |move| {
            if (move.isPromotion()) {
                best_capture += tables.material[types.PieceType.queen.index()] - tables.material[types.PieceType.pawn.index()];
                break;
            }
        }

        // if ((if (pos.state.turn.isWhite()) pos.score_material_w - pos.score_material_b else pos.score_material_b - pos.score_material_w) +| best_capture < (alpha -| margin))
        if (stand_pat +| best_capture < (alpha -| margin))
            return alpha;
    }

    if (alpha < stand_pat)
        alpha = stand_pat;
    if (outOfTime(limits))
        return alpha;

    // Loop over all legal captures
    for (move_list_capture.items) |move| {
        if (is_nmr and pos.board[move.getTo().index()].pieceToPieceType() == types.PieceType.king) {
            return -types.value_mate;
        }

        // Delta pruning inside
        // if (!pos.endgame(pos.state.turn)) {
        //     var capture_value: types.Value = pos.board[move.getTo().index()].pieceToPieceType().index();
        //     if (move.isPromotion())
        //         capture_value += tables.material[types.PieceType.queen.index()] - 100;
        //     if ((if (pos.state.turn.isWhite()) pos.score_material_w - pos.score_material_b else pos.score_material_b - pos.score_material_w) +| capture_value < alpha -| margin)
        //         continue;
        // }

        try pos.movePiece(move, &s);

        if (pos.state.repetition < 0) {
            score = types.value_draw;
        } else {
            score = -try quiesce(allocator, nodetype, ss + 1, pos, limits, eval, -beta, -alpha, false);
        }

        try pos.unMovePiece(move);

        if (score >= beta) {
            // beta cutoff
            return beta;
        }
        if (score > alpha) {
            // Update pv even in fail-high case
            if (pv_node)
                update_pv(ss[0].pv.?, move, ss[1].pv.?);
            // alpha acts like max in MiniMax
            alpha = score;
        }

        if (outOfTime(limits))
            break;
    }

    return alpha;
}

fn update_pv(pv: []types.Move, move: types.Move, childPv: []types.Move) void {
    pv[0] = move;
    for (childPv, 1..) |new_move, i| {
        pv[i] = new_move;
        if (new_move == types.Move.none)
            break;
    }
}

fn info(stdout: anytype, limits: interface.Limits, depth: u16, score: types.Value, options: std.StringArrayHashMapUnmanaged(interface.Option)) !void {
    const time: u64 = @intCast(elapsed(limits));

    const hash_size: u16 = try std.fmt.parseInt(u16, options.get("Hash").?.current_value, 10);
    const hashfull: u128 = @divTrunc(@as(u128, tables.transposition_table.size) * (@sizeOf(tables.Key) + @sizeOf(std.meta.Tuple(&[_]type{ types.Value, u8, types.Move, types.TableBound })) + @sizeOf(u32)) * 1000, @as(u128, hash_size) * 1000000);

    try stdout.print("info depth {} seldepth {} nodes {} nps {} time {} hash {} hashfull {} hashused {} score cp {} pv ", .{ depth, interface.seldepth, interface.nodes_searched, @divTrunc(interface.nodes_searched * 1000, @max(1, time)), time, tables.transposition_table.size, hashfull, interface.transposition_used, score });
    try pvDisplay(stdout, root_moves.items[0].pv.items);
    try stdout.print("\n", .{});
}

fn pvDisplay(stdout: anytype, pv: []types.Move) !void {
    var cnt: usize = 0;
    while (cnt < pv.len and pv[cnt] != types.Move.none) : (cnt += 1) {
        try pv[cnt].printUCI(stdout);
        try stdout.print(" ", .{});
    }
}
