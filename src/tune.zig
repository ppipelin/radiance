const evaluate = @import("evaluate.zig");
const position = @import("position.zig");
const std = @import("std");
const types = @import("types.zig");
const tables = @import("tables.zig");
const variable = @import("variable.zig");

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

    var buffer: []u8 = try allocator.alloc(u8, 1_000_000 * 64);
    // var buffer: []u8 = try allocator.alloc(u8, 50 * 64);
    defer allocator.free(buffer);

    const len = try std.os.windows.ReadFile(file_handle, buffer, null);

    var list: std.ArrayList(Triplet) = .empty;

    var it = std.mem.splitScalar(u8, buffer[0..len], '\n');
    while (it.next()) |token| {
        if (std.mem.endsWith(u8, token[0..(token.len - 1)], "]")) {
            const wdl = try std.fmt.parseFloat(f16, token[(token.len - 5)..(token.len - 2)]);
            const copy = try allocator.dupe(u8, token[0..(token.len - 7)]);
            try list.append(allocator, .{ copy, Wdl.init(wdl) });
        }
    }
    return list;
}

fn sigmoid(value: f32) f32 {
    const lambda: types.Value = 1.0;
    // const lambda: f32 = 0.5;
    return 1.0 / (1.0 + @exp(lambda * -value / 100));
}

fn eval(book: std.ArrayList(Triplet)) !f32 {
    var difference: f32 = 0;
    for (book.items) |triplet| {
        var s: position.State = position.State{};
        const pos: position.Position = try position.Position.setFen(&s, triplet[0]);
        const multiply: types.Value = if (pos.state.turn == .white) 1 else -1;
        // std.debug.print("eval {}, sigm {}, real {}, error^2 {}\n", .{ multiply * evaluate.evaluateTable(pos), sigmoid(@floatFromInt(multiply * evaluate.evaluateTable(pos))), triplet[1].index(), std.math.pow(f32, sigmoid(@floatFromInt(multiply * evaluate.evaluateTable(pos))) - triplet[1].index(), 2) });
        difference += std.math.pow(f32, sigmoid(@floatFromInt(multiply * evaluate.evaluateTable(pos))) - triplet[1].index(), 2);
    }
    std.debug.print("mean difference {}\n", .{difference / @as(f32, @floatFromInt(book.items.len))});
    return difference;
}

fn updateVariable(variable_new: []const types.Value) void {
    variable.knight_mobility = variable_new[0];
    variable.bishop_mobility = variable_new[1];
    variable.rook_mobility = variable_new[2];
    variable.queen_mobility = variable_new[3];
    variable.king_mobility = variable_new[4];
    variable.pawn_threat_knight = variable_new[5];
    variable.pawn_threat_bishop = variable_new[6];
    variable.pawn_threat_rook = variable_new[7];
    variable.pawn_threat_queen = variable_new[8];
    variable.pawn_defend_king = variable_new[9];
    variable.pawn_isolated = variable_new[10];
    variable.pawn_doubled = variable_new[11];
    variable.pawn_blocked = variable_new[12];
    variable.pawn_protection = variable_new[13];
    variable.bishop_pair = variable_new[14];
    variable.rook_open_files = variable_new[15];
    variable.rook_semi_open_files = variable_new[16];
}

// fn perturbate(variable_new: []types.Value, magnitude: f32) !void {
//     // var prng = std.Random.DefaultPrng.init(@bitCast(std.time.microTimestamp()));
//     // prng.random()

//     var prng = std.Random.DefaultPrng.init(seed: {
//         var seed: u64 = undefined;
//         // get random seed from OS
//         try std.posix.getrandom(std.mem.asBytes(&seed));
//         break :seed seed;
//     });
//     const rand = prng.random();

//     for (variable_new) |*current_var| {
//         current_var.* += (rand.intRangeAtMost(types.Value, -1, 1) * magnitude);
//     }
// }

fn computeDelta(deltas: []types.Value, magnitude: types.Value) !void {
    var prng = std.Random.DefaultPrng.init(seed: {
        var seed: u64 = undefined;
        // get random seed from OS
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :seed seed;
    });
    const rand = prng.random();

    for (deltas) |*current_delta| {
        if (rand.boolean()) {
            current_delta.* += magnitude;
        } else {
            current_delta.* -= magnitude;
        }
    }
}

fn applyDelta(variable_new: []types.Value, deltas: []const types.Value) void {
    for (variable_new, 0..) |*variable_current, i| {
        variable_current.* += deltas[i];
    }
}

fn applyDeltaNegative(variable_new: []types.Value, deltas: []const types.Value) void {
    for (variable_new, 0..) |*variable_current, i| {
        variable_current.* -= deltas[i];
    }
}

pub fn run(allocator: std.mem.Allocator, stdout: *std.Io.Writer) !void {
    var book: std.ArrayList(Triplet) = try readBook(allocator);
    defer book.deinit(allocator);

    // Set vars
    var initial: [17]types.Value = .{ 5, 5, 5, 5, 5, 0, 0, 0, 0, 5, 30, 15, 10, 30, 10, 40, 20 };
    // var initial: [17]types.Value = .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
    var tmp: [17]types.Value = initial;
    var delta: [17]types.Value = @splat(0);

    const alpha: f32 = 0.602;
    const gamma: f32 = 0.101;

    const a: f32 = 0.1;
    const c: f32 = 1;
    const A: f32 = 1;

    for (0..2) |k_| {
        const k: f32 = @floatFromInt(k_);
        const ak = a / std.math.pow(f32, k + 1 + A, alpha);
        const ck = c / std.math.pow(f32, k + 1, gamma);

        const magnitude: types.Value = @intFromFloat(@max(@min(ck, std.math.maxInt(types.Value)), std.math.minInt(types.Value)));
        try computeDelta(&delta, magnitude);

        applyDelta(&tmp, delta[0..]);
        updateVariable(tmp[0..17]);
        const v1 = try eval(book);

        applyDeltaNegative(&tmp, delta[0..]);
        updateVariable(tmp[0..17]);
        const v2 = try eval(book);

        const match = v1 - v2;

        for (&initial, 0..) |*param, i| {
            const variation: types.Value = @intFromFloat(@max(@min(ak * match / (ck * @as(f32, @floatFromInt(delta[i]))), std.math.maxInt(types.Value)), std.math.minInt(types.Value)));
            param.* += variation;
        }
    }

    try stdout.print("Found variables:\n", .{});
    for (initial) |param| {
        try stdout.print("{}, ", .{param});
    }
    try stdout.print("\n", .{});
}
