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

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Radiance {s} by Paul-Elie Pipelin (ppipelin)\n", .{types.computeVersion()});

    var stdin = std.io.getStdIn().reader();

    const args = try std.process.argsAlloc(allocator);

    if (args.len > 1 and std.mem.eql(u8, args[1], "compute")) {
        var iterations: u64 = 1;
        if (args.len > 2) {
            iterations = try std.fmt.parseInt(u64, args[2], 10);
        }
        magic.compute(allocator, iterations);
    } else if (args.len > 1 and std.mem.eql(u8, args[1], "bench")) {
        try interface.cmd_bench(allocator, &stdout);
    } else {
        try interface.loop(allocator, &stdin, &stdout);
    }
}
