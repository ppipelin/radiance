const position = @import("position.zig");
const std = @import("std");
const types = @import("types.zig");

pub fn perft(allocator: std.mem.Allocator, pos: *position.Position, depth: u8, verbose: bool) !u64 {
    var nodes: u64 = 0;
    var move_list = std.ArrayList(types.Move).init(allocator);
    defer move_list.deinit();

    if (depth == 0) {
        return 1;
    }

    pos.generateLegalMoves(pos.state.turn, &move_list);

    if (depth == 1)
        return move_list.items.len;

    const stdout = std.io.getStdOut().writer();
    for (move_list.items) |move| {
        var s: position.State = position.State{};

        if (pos.movePiece(move, &s)) {} else |err| return err;

        if (perft(allocator, pos, depth - 1, false)) |nodes_number| {
            nodes += nodes_number;
            if (verbose) {
                move.printUCI(stdout);
                stdout.print(", {} : {}\n", .{ move.getFlags(), nodes_number }) catch unreachable;
            }
        } else |err| return err;

        if (pos.unMovePiece(move, false)) {} else |err| return err;
    }
    return nodes;
}
