const interface = @import("interface.zig");
const magic = @import("magic.zig");
const position = @import("position.zig");
const search = @import("search.zig");
const std = @import("std");
const tables = @import("tables.zig");
const tune = @import("tune.zig");
const types = @import("types.zig");

pub fn main() !void {
    const allocator = std.heap.c_allocator;
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var stdout_buffer: [16 * 1024]u8 = undefined;
    var stdout_writer: std.fs.File.Writer = std.fs.File.stdout().writerStreaming(&stdout_buffer); // Can use &.{} for no buffer
    const stdout: *std.Io.Writer = &stdout_writer.interface;

    try stdout.print("Radiance {s} by Paul-Elie Pipelin (ppipelin)\n", .{types.computeVersion()});
    try stdout.flush();

    var stdin_buffer: [16 * 1024]u8 = undefined;
    var stdin_reader: std.fs.File.Reader = std.fs.File.stdin().readerStreaming(&stdin_buffer); // Can use &.{} for no buffer
    const stdin: *std.Io.Reader = &stdin_reader.interface;

    const args = try std.process.argsAlloc(allocator);

    if (args.len > 1 and std.ascii.eqlIgnoreCase(args[1], "compute")) {
        var iterations: u64 = 1;
        if (args.len > 2) {
            iterations = try std.fmt.parseInt(u64, args[2], 10);
        }
        magic.compute(iterations);
    } else if (args.len > 1 and std.ascii.eqlIgnoreCase(args[1], "tune")) {
        var iterations: u64 = 1;
        if (args.len > 2) {
            iterations = try std.fmt.parseInt(u64, args[2], 10);
        }
        try tune.run(allocator, stdout, iterations);
    } else if (args.len > 1 and std.ascii.eqlIgnoreCase(args[1], "bench")) {
        try interface.cmd_bench(allocator, stdout);
    } else {
        try interface.loop(allocator, stdin, stdout);
    }

    try stdout.flush();
}
