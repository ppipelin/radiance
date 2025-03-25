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

pub fn perft(allocator: std.mem.Allocator, stdout: anytype, pos: *position.Position, depth: u8, verbose: bool) !u64 {
    var nodes: u64 = 0;
    var move_list: std.ArrayListUnmanaged(types.Move) = .empty;
    defer move_list.deinit(allocator);

    if (depth == 0 or interface.g_stop) {
        return 1;
    }

    pos.generateLegalMoves(allocator, pos.state.turn, &move_list);

    if (depth == 1) {
        if (verbose) {
            try types.Move.displayMoves(stdout, move_list);
        }
        return move_list.items.len;
    }

    for (move_list.items) |move| {
        var s: position.State = position.State{};

        try pos.movePiece(move, &s);

        const nodes_number = try (perft(allocator, stdout, pos, depth - 1, false));
        nodes += nodes_number;
        if (verbose) {
            try move.printUCI(stdout);
            try stdout.print(", {} : {}\n", .{ move.getFlags(), nodes_number });
        }

        try pos.unMovePiece(move, false);
    }
    return nodes;
}

pub fn perftTest(allocator: std.mem.Allocator, pos: *position.Position, depth: u8) !u64 {
    var nodes: u64 = 0;
    var move_list: std.ArrayListUnmanaged(types.Move) = .empty;
    defer move_list.deinit(allocator);

    if (depth == 0) {
        return 1;
    }

    pos.generateLegalMoves(allocator, pos.state.turn, &move_list);

    if (depth == 1)
        return move_list.items.len;

    for (move_list.items) |move| {
        var s: position.State = position.State{};

        var fen_before: [90]u8 = undefined;
        const fen_before_c = pos.getFen(&fen_before);
        const score_before = [_]types.Value{ pos.score_material_w, pos.score_material_b };
        const key_before = pos.state.material_key;

        try pos.movePiece(move, &s);

        const nodes_number = try (perftTest(allocator, pos, depth - 1));
        nodes += nodes_number;

        try pos.unMovePiece(move, false);

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

pub fn searchRandom(allocator: std.mem.Allocator, pos: *position.Position) !types.Move {
    var move_list: std.ArrayListUnmanaged(types.Move) = .empty;
    defer move_list.deinit(allocator);
    pos.generateLegalMoves(allocator, pos.state.turn, &move_list);

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

pub fn iterativeDeepening(allocator: std.mem.Allocator, stdout: anytype, pos: *position.Position, limits: interface.Limits, eval: *const fn (pos: position.Position) types.Value) !types.Move {
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

    pos.generateLegalMoves(allocator, pos.state.turn, &move_list);

    const root_moves_len: usize = move_list.items.len;
    if (root_moves_len == 0) {
        return error.Checkmated;
    } else if (root_moves_len == 1) {
        return move_list.items[0];
    }

    // Order moves
    pos.orderMoves(&move_list, types.Move.none);

    try root_moves.ensureTotalCapacity(allocator, root_moves_len);
    root_moves.clearRetainingCapacity();

    // limits.searchmoves here

    for (move_list.items) |move| {
        var pv_rm: std.ArrayListUnmanaged(types.Move) = .empty;
        try pv_rm.ensureTotalCapacity(allocator, 200);
        pv_rm.appendAssumeCapacity(move);
        root_moves.appendAssumeCapacity(RootMove{ .pv = pv_rm });
    }

    interface.nodes_searched = 0;
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
            const score: types.Value = try abSearch(allocator, NodeType.root, ss, pos, limits, eval, alpha, beta, current_depth);
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
        try info(stdout, limits, current_depth, root_moves.items[0].score);
    }

    // Even if outofTime we keep a better move if there is one
    const move = root_moves.items[0].pv.items[0];

    for (root_moves.items) |*root_move| {
        root_move.pv.deinit(allocator);
    }

    return move;
}

fn abSearch(allocator: std.mem.Allocator, comptime nodetype: NodeType, ss: [*]Stack, pos: *position.Position, limits: interface.Limits, eval: *const fn (pos: position.Position) types.Value, alpha_: types.Value, beta: types.Value, current_depth: u8) !types.Value {
    const pv_node: bool = nodetype != NodeType.non_pv;
    const root_node: bool = nodetype == NodeType.root;

    var alpha = alpha_;

    interface.nodes_searched += 1;

    if (current_depth <= 0) {
        // return eval(pos.*);
        return quiesce(allocator, if (pv_node) NodeType.pv else NodeType.non_pv, ss, pos, limits, eval, alpha, beta);
    }

    // Initialize data
    var s: position.State = position.State{};
    var pv: [200]types.Move = [_]types.Move{.none} ** 200;
    var score: types.Value = -types.value_none;
    var best_score: types.Value = -types.value_none;

    // Initialize node
    var move_count: u16 = 0;

    var move_list: std.ArrayListUnmanaged(types.Move) = .empty;
    defer move_list.deinit(allocator);

    if (root_node) {
        for (root_moves.items) |root_move| {
            try move_list.append(allocator, root_move.pv.items[0]);
        }
        // TODO: compute checkers
    } else {
        pos.generateLegalMoves(allocator, pos.state.turn, &move_list);
        var pv_move: types.Move = types.Move.none;
        if (root_moves.items[0].pv.items.len > ss[0].ply) {
            pv_move = root_moves.items[0].pv.items[ss[0].ply];
        }
        pos.orderMoves(&move_list, pv_move);
    }

    // Loop over all legal moves
    for (move_list.items) |move| {
        score = -types.value_none;
        move_count += 1;
        if (pv_node) {
            ss[1].pv = null;
        }

        const key: u64 = pos.state.material_key;

        try pos.movePiece(move, &s);

        ss[1].pv = &pv;
        ss[1].pv.?[0] = types.Move.none;

        if (pos.state.repetition < 0) {
            score = types.value_draw;
        } else {
            const found: ?std.meta.Tuple(&[_]type{ types.Value, u8, types.Move }) = tables.transposition_table.get(key);
            if (found != null and found.?[1] > current_depth - 1) {
                score = found.?[0];
                if (score > types.value_mate_in_max_depth) {
                    score -= ss[0].ply;
                } else if (score < types.value_mate_in_max_depth) {
                    score += ss[0].ply;
                }

                // Retrieved score doesn't meet the alpha beta requirements
                if (score < alpha or score >= beta) {
                    score = -types.value_none;
                } else {
                    interface.transposition_used += 1;
                }
            }

            if (score == -types.value_none) {
                // LMR before full
                if (current_depth >= 2 and move_count > 3 and !move.isCapture() and !move.isPromotion() and pos.state.checkers == 0) {
                    // Reduced LMR
                    const d: u8 = @max(1, current_depth -| 4);
                    score = -try abSearch(allocator, NodeType.non_pv, ss + 1, pos, limits, eval, -(alpha + 1), -alpha, d - 1);
                    // Failed so roll back to full-depth null window
                    if (score > alpha and current_depth > d) {
                        score = -try abSearch(allocator, NodeType.non_pv, ss + 1, pos, limits, eval, -(alpha + 1), -alpha, current_depth - 1);
                    }
                }
                // In case non PV search are called without LMR, null window search at current depth
                else if (!pv_node or move_count > 1) {
                    score = -try abSearch(allocator, NodeType.non_pv, ss + 1, pos, limits, eval, -(alpha + 1), -alpha, current_depth - 1);
                }
                // Full-depth search
                if (pv_node and (move_count == 1 or score > alpha)) {
                    score = -try abSearch(allocator, NodeType.pv, ss + 1, pos, limits, eval, -beta, -alpha, current_depth - 1);
                    // Let's assert we don't store draw (repetition)
                    if (score != types.value_draw) {
                        if (found == null or found.?[1] <= current_depth - 1) {
                            try tables.transposition_table.put(allocator, key, .{ score, current_depth - 1, move });
                        }
                    }
                }
            }
        }

        // Undo move
        try pos.unMovePiece(move, false);

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
            if (pv_node and !root_node) // Update pv even in fail-high case
            {
                update_pv(ss[0].pv.?, move, ss[1].pv.?);
            }

            // Fail high
            if (score >= beta) {
                if (score != types.value_draw) {
                    const found: ?std.meta.Tuple(&[_]type{ types.Value, u8, types.Move }) = tables.transposition_table.get(key);
                    if (found == null or found.?[1] <= current_depth - 1) {
                        try tables.transposition_table.put(allocator, key, .{ score, current_depth - 1, move });
                    }
                }
                break;
            } else {
                alpha = score; // Update alpha! Always alpha < beta
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

fn quiesce(allocator: std.mem.Allocator, comptime nodetype: NodeType, ss: [*]Stack, pos: *position.Position, limits: interface.Limits, eval: *const fn (pos: position.Position) types.Value, alpha_: types.Value, beta: types.Value) !types.Value {
    const pv_node: bool = nodetype == NodeType.pv;

    var alpha = alpha_;

    interface.nodes_searched += 1;

    // In order to get the quiescence search to terminate, plies are usually restricted to moves that deal directly with the threat,
    // such as moves that capture and recapture (often called a 'capture search') in chess
    const stand_pat: types.Value = eval(pos.*);
    if (stand_pat >= beta)
        return beta;
    if (alpha < stand_pat)
        alpha = stand_pat;
    if (outOfTime(limits))
        return alpha;

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

    // Loop over all legal captures
    for (move_list_capture.items) |move| {
        try pos.movePiece(move, &s);

        if (pos.state.repetition < 0) {
            score = types.value_draw;
        } else {
            score = -try quiesce(allocator, nodetype, ss + 1, pos, limits, eval, -beta, -alpha);
        }

        try pos.unMovePiece(move, false);

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

fn info(stdout: anytype, limits: interface.Limits, depth: u16, score: types.Value) !void {
    const time: u64 = @intCast(elapsed(limits));
    try stdout.print("info depth {} nodes {} nps {} time {} hash {} hashfull {} hashused {} score cp {} pv ", .{ depth, interface.nodes_searched, @divTrunc(interface.nodes_searched * 1000, @max(1, time)), time, tables.transposition_table.size, 0, interface.transposition_used, score });
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
