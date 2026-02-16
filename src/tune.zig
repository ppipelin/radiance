const std = @import("std");

const Tuple = std.meta.Tuple;

fn readBook(allocator: std.mem.Allocator) !std.ArrayList([]const u8) {
    // const file = try std.fs.cwd().openFile("data/E12.33-1M-D12-Resolved.book", .{ .mode = .read_only });
    // defer file.close();

    // std.debug.print("file {}\n", .{file});

    // var buffer: [1024]u8 = undefined;
    // var reader: std.Io.Reader = file.reader(&buffer).interface;

    // const data = try reader.readAlloc(allocator, 1);
    // defer allocator.free(data);
    // std.debug.print("Read {d} bytes\n", .{data.len});

    const file_handle = std.os.windows.kernel32.CreateFileW(
        std.unicode.utf8ToUtf16LeStringLiteral("data/E12.33-1M-D12-Resolved.book"),
        // std.unicode.utf8ToUtf16LeStringLiteral("data/test.txt"),
        std.os.windows.GENERIC_READ,
        std.os.windows.FILE_SHARE_READ | std.os.windows.FILE_SHARE_WRITE, // Allow others to access
        null,
        std.os.windows.OPEN_EXISTING,
        std.os.windows.FILE_ATTRIBUTE_NORMAL,
        null,
    );

    var buffer: [10_000]u8 = undefined;

    const len = try std.os.windows.ReadFile(file_handle, &buffer, null);

    var list: std.ArrayList([]const u8) = .empty;

    var it = std.mem.splitScalar(u8, buffer[0..len], '\n');
    while (it.next()) |token| {
        if (std.mem.endsWith(u8, token[0..(token.len - 1)], "]")) {
            const wdl = try std.fmt.parseFloat(f16, token[(token.len - 5)..(token.len - 2)]);
            std.debug.print("wdl {}\n", .{wdl});
            const copy = try allocator.dupe(u8, token[0..(token.len - 7)]);
            try list.append(allocator, copy);
        }
    }
    return list;
}

pub fn run(allocator: std.mem.Allocator, stdout: *std.Io.Writer) !void {
    try stdout.print("begin tune\n", .{});
    const book = try readBook(allocator);
    for (book.items) |fen| {
        std.debug.print("{s}\n", .{fen});
    }
}
