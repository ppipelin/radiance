const position = @import("position.zig");
const std = @import("std");
const types = @import("types.zig");

pub fn perft(allocator: std.mem.Allocator, pos: *position.Position, depth: u8, verbose: bool) !u64 {
    var nodes: u64 = 0;
    var move_list: std.ArrayListUnmanaged(types.Move) = .empty;
    defer move_list.deinit(allocator);

    if (depth == 0) {
        return 1;
    }

    pos.generateLegalMoves(pos.state.turn, &move_list, allocator);

    if (depth == 1)
        return move_list.items.len;

    const stdout = std.io.getStdOut().writer();
    for (move_list.items) |move| {
        var s: position.State = position.State{};

        try pos.movePiece(move, &s);

        if (perft(allocator, pos, depth - 1, false)) |nodes_number| {
            nodes += nodes_number;
            if (verbose) {
                move.printUCI(stdout);
                try stdout.print(", {} : {}\n", .{ move.getFlags(), nodes_number });
            }
        } else |err| return err;

        if (pos.unMovePiece(move, false)) {} else |err| return err;
    }
    return nodes;
}
