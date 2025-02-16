const position = @import("position.zig");
const std = @import("std");
const types = @import("types.zig");

pub fn perft(allocator: std.mem.Allocator, stdout: anytype, pos: *position.Position, depth: u8, verbose: bool) !u64 {
    var nodes: u64 = 0;
    var move_list: std.ArrayListUnmanaged(types.Move) = .empty;
    defer move_list.deinit(allocator);

    if (depth == 0) {
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

        try pos.unMovePiece(move);
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
