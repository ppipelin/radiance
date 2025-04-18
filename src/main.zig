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

    magic.compute(allocator);
    std.debug.print("\n\nmagics found :\n", .{});
    for (0..types.board_size2) |i| {
        std.debug.print("{x}\n", .{magic.magics_bishop[i].magic});
    }

    for (0..types.board_size2) |i| {
        std.debug.print("{x}\n", .{magic.magics_rook[i].magic});
    }

    if (args.len > 1 and std.mem.eql(u8, args[1], "compute")) {
        magic.compute(allocator);
    } else {
        try interface.loop(allocator, &stdin, &stdout);
    }
}
