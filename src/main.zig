const interface = @import("interface.zig");
const position = @import("position.zig");
const search = @import("search.zig");
const std = @import("std");
const tables = @import("tables.zig");
const types = @import("types.zig");

pub fn main() !void {
    tables.initAll(std.heap.c_allocator);
    defer tables.deinitAll(std.heap.c_allocator);

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Radiance {s} by Paul-Elie Pipelin (ppipelin)\n", .{types.computeVersion()});

    var stdin = std.io.getStdIn().reader();

    try interface.loop(std.heap.c_allocator, &stdin, &stdout);
}
