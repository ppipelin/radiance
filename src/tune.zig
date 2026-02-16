const evaluate = @import("evaluate.zig");
const position = @import("position.zig");
const std = @import("std");
const types = @import("types.zig");
const tables = @import("tables.zig");

const Tuple = std.meta.Tuple;
const Triplet = Tuple(&.{ []const u8, Wdl });

const Wdl = enum(u2) {
    loss,
    draw,
    win,

    pub fn init(value: f16) Wdl {
        if (std.math.approxEqAbs(f16, 1.0, value, 1e-6))
            return .win;
        if (std.math.approxEqAbs(f16, 0.0, value, 1e-6))
            return .loss;
        return .draw;
    }

    pub inline fn index(self: Wdl) f16 {
        switch (self) {
            .loss => return 0.0,
            .draw => return 0.5,
            .win => return 1.0,
        }
    }

    pub fn fromInteger(value: types.Value) Wdl {
        if (value > 0)
            return .win;
        if (value < 0)
            return .loss;
        return .draw;
    }
};

fn readBook(allocator: std.mem.Allocator) !std.ArrayList(Triplet) {
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

    var list: std.ArrayList(Triplet) = .empty;

    var it = std.mem.splitScalar(u8, buffer[0..len], '\n');
    while (it.next()) |token| {
        if (std.mem.endsWith(u8, token[0..(token.len - 1)], "]")) {
            const wdl = try std.fmt.parseFloat(f16, token[(token.len - 5)..(token.len - 2)]);
            std.debug.print("wdl {}\n", .{wdl});
            const copy = try allocator.dupe(u8, token[0..(token.len - 7)]);
            try list.append(allocator, .{ copy, Wdl.init(wdl) });
        }
    }
    return list;
}

fn sigmoid(value: f32) f32 {
    // const lambda: types.Value = 1.0;
    const lambda: f32 = 0.5;
    return @divTrunc(1.0, 1.0 + @exp(lambda * -value));
}

fn eval(book: std.ArrayList(Triplet)) !void {
    var difference: f32 = 0;
    for (book.items) |triplet| {
        var s: position.State = position.State{};
        const pos: position.Position = try position.Position.setFen(&s, triplet[0]);
        difference += std.math.pow(f32, sigmoid(@floatFromInt(evaluate.evaluateTable(pos))) - triplet[1].index(), 2);
    }
    std.debug.print("mean difference {}\n", .{difference / @as(f32, @floatFromInt(book.items.len))});
}

pub fn run(allocator: std.mem.Allocator, stdout: *std.Io.Writer) !void {
    try stdout.print("begin tune\n", .{});
    var book: std.ArrayList(Triplet) = try readBook(allocator);
    defer book.deinit(allocator);

    for (book.items) |fen| {
        std.debug.print("{s}, {}\n", .{ fen[0], fen[1] });
    }
    try eval(book);
}
