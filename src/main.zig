const position = @import("position.zig");
const search = @import("search.zig");
const std = @import("std");
const tables = @import("tables.zig");
const types = @import("types.zig");

pub fn main() !void {
    tables.initAll(std.heap.c_allocator);
    defer tables.deinitAll(std.heap.c_allocator);

    const stdout = std.io.getStdOut().writer();

    var state: position.State = position.State{};
    var pos = position.Position.setFen(&state, position.kiwipete);
    pos.debugPrint();

    var t = try std.time.Timer.start();

    // var list = std.ArrayList(types.Move).init(std.heap.page_allocator);
    // defer list.deinit();
    // pos.generateLegalMoves(pos.state.turn, &list);
    // types.Move.displayMoves(stdout, list);

    // std.debug.print("Perft 1: {}\n\n", .{try search.perft(std.heap.c_allocator, &pos, 1, true)});
    // std.debug.print("Perft 2: {}\n\n", .{try search.perft(std.heap.c_allocator, &pos, 2, true)});
    // std.debug.print("Perft 3: {}\n\n", .{try search.perft(std.heap.c_allocator, &pos, 3, true)});
    std.debug.print("Perft 4: {}\n\n", .{try search.perft(std.heap.c_allocator, &pos, 4, true)});
    // std.debug.print("Perft 5: {}\n\n", .{try search.perft(std.heap.c_allocator, &pos, 5, true)});
    // std.debug.print("Perft 6: {}\n\n", .{try search.perft(std.heap.c_allocator, &pos, 6, true)});

    try stdout.print("Time: {}\n", .{std.fmt.fmtDuration(t.read())});
}
