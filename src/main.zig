const interface = @import("interface.zig");
const magic = @import("magic.zig");
const position = @import("position.zig");
const search = @import("search.zig");
const std = @import("std");
const tables = @import("tables.zig");
const types = @import("types.zig");

pub fn main() !void {
    const allocator = std.heap.c_allocator;
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var stdout_buffer: [16 * 1024]u8 = undefined;
    var stdout_writer: std.fs.File.Writer = std.fs.File.stdout().writer(&stdout_buffer); // Can use &.{} for no buffer
    const stdout: *std.Io.Writer = &stdout_writer.interface;

    try stdout.print("Radiance {s} by Paul-Elie Pipelin (ppipelin)\n", .{types.computeVersion()});
    try stdout.flush();

    var stdin_buffer: [16 * 1024]u8 = undefined;
    var stdin_reader: std.fs.File.Reader = std.fs.File.stdin().reader(&stdin_buffer); // Can use &.{} for no buffer
    const stdin: *std.Io.Reader = &stdin_reader.interface;

    const args = try std.process.argsAlloc(allocator);

    if (args.len > 1 and std.mem.eql(u8, args[1], "compute")) {
        var iterations: u64 = 1;
        if (args.len > 2) {
            iterations = try std.fmt.parseInt(u64, args[2], 10);
        }
        magic.compute(iterations);
    } else if (args.len > 1 and std.mem.eql(u8, args[1], "bench")) {
        try interface.cmd_bench(allocator, stdout);
    } else if (args.len > 1 and std.mem.eql(u8, args[1], "see")) {
        var state = position.State{};
        // const pos: position.Position = try position.Position.setFen(&state, "1k1r4/1pp4p/p7/4q3/8/P5P1/1PP4P/2K1R3 w - - 0 1"); // early exit
        // const pos: position.Position = try position.Position.setFen(&state, "1k1r4/1pp4p/p7/4p3/8/P5P1/1PP4P/2K1R3 w");
        // const pos: position.Position = try position.Position.setFen(&state, "3k4/8/6rn/8/6p1/5P1P/4Q3/3K2R1 w"); // gain knight with second pawn
        // const pos: position.Position = try position.Position.setFen(&state, "3k4/8/6rn/8/6p1/5P1P/8/3K2R1 w"); // gain knight with second pawn (no queen)
        const pos: position.Position = try position.Position.setFen(&state, "3k4/8/6rn/8/6p1/5P2/4Q3/3K2R1 w");
        // const pos: position.Position = try position.Position.setFen(&state, "3k4/8/6rn/8/6p1/5P2/8/3K2R1 w"); // no queen lose
        pos.printDebug();
        // const see = search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "e1e5"), 0);
        // const see = search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "f3g4"), 1000);
        // const see = search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "g1g4"), 0);
        const see = search.seeGreaterEqual(pos, try types.Move.initFromStr(pos, "g1g4"), -158);
        std.debug.print("see {}\n", .{see});
    } else {
        try interface.loop(allocator, stdin, stdout);
    }

    try stdout.flush();
}
