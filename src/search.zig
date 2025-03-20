const interface = @import("interface.zig");
const position = @import("position.zig");
const std = @import("std");
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
    move_count: u16 = 0,
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

    if (depth == 0) {
        return 1;
    }

    pos.generateLegalMoves(allocator, pos.state.turn, &move_list);

    if (depth == 1)
        return move_list.items.len;

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
            const score: types.Value = try abSearch(allocator, NodeType.root, ss, pos, eval, alpha, beta, current_depth);
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
        try info(stdout, current_depth, root_moves.items[0].score);
    }

    // Even if outofTime we keep a better move if there is one
    const move = root_moves.items[0].pv.items[0];

    for (root_moves.items) |*root_move| {
        root_move.pv.deinit(allocator);
    }

    return move;
}

fn abSearch(allocator: std.mem.Allocator, comptime nodetype: NodeType, ss: [*]Stack, pos: *position.Position, eval: *const fn (pos: position.Position) types.Value, alpha_: types.Value, beta: types.Value, current_depth: u8) !types.Value {
    const pv_node: bool = nodetype != NodeType.non_pv;
    const root_node: bool = nodetype == NodeType.root;

    var alpha = alpha_;

    if (current_depth <= 0) {
        return eval(pos.*);
        // return quiesce<pvNode ? PV : NonPV>(ss, b, e, alpha, beta);
    }

    // Initialize data
    var s: position.State = position.State{};
    var pv: [200]types.Move = [_]types.Move{.none} ** 200;
    var score: types.Value = -types.value_none;
    var best_score: types.Value = -types.value_none;

    interface.nodes_searched += 1;

    // Initialize node
    ss[0].move_count = 0;
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
        // order moves
    }

    // Loop over all legal moves
    for (move_list.items) |move| {
        score = -types.value_none;
        move_count += 1;
        ss[0].move_count = move_count;
        if (pv_node) {
            // TODO putting (ss + 1)[0].pv[0] to .none should suffice ?
            (ss + 1)[0].pv = null;
        }

        // Key key = b.m_s->materialKey;

        try pos.movePiece(move, &s);

        (ss + 1)[0].pv = &pv;
        (ss + 1)[0].pv.?[0] = types.Move.none;

        if (false and pos.state.repetition < 0) {
            score = types.value_draw;
        } else {
            if (score == -types.value_none) {
                // // LMR before full
                // if (depth >= 2 && moveCount > 3 && !move.isCapture() && !move.isPromotion() && !b.inCheck(b.isWhiteTurn()))
                // {
                //   // Reduced LMR
                //   UInt d = std::max<Int>(Int(1), Int(depth) - 4);
                //   score = -abSearch<NonPV>(ss + 1, b, e, -(alpha + 1), -alpha, d - 1);
                //   // Failed so roll back to full-depth null window
                //   if (score > alpha && depth > d)
                //   {
                //     score = -abSearch<NonPV>(ss + 1, b, e, -(alpha + 1), -alpha, depth - 1);
                //   }
                // }
                // // In case non PV search are called without LMR, null window search at current depth
                // else if (!pv_node or move_count > 1) {
                //     score = -try abSearch(allocator, NodeType.non_pv, ss + 1, pos, eval, -(alpha + 1), -alpha, current_depth - 1);
                // }
                // Full-depth search
                // if (pv_node and (move_count == 1 or score > alpha)) {
                score = -try abSearch(allocator, NodeType.pv, ss + 1, pos, eval, -beta, -alpha, current_depth - 1);
                // }
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
                    for ((ss + 1)[0].pv.?) |pv_move| {
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
                update_pv(ss[0].pv.?, move, (ss + 1)[0].pv.?);
            }

            // Fail high
            if (score >= beta) {
                // transposition
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

fn update_pv(pv: []types.Move, move: types.Move, childPv: []types.Move) void {
    pv[0] = move;
    for (childPv, 1..) |new_move, i| {
        pv[i] = new_move;
        if (new_move == types.Move.none)
            break;
    }
}

fn info(stdout: anytype, depth: u16, score: types.Value) !void {
    try stdout.print("info depth {} nodes {} nps {} time {} score cp {} pv ", .{ depth, interface.nodes_searched, 0, 0, score });
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
