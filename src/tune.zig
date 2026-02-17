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

fn eval(book: []const Triplet) !f32 {
    var difference: f32 = 0;
    for (book) |triplet| {
        var s: position.State = position.State{};
        const pos: position.Position = try position.Position.setFen(&s, triplet[0]);
        const multiply: types.Value = if (pos.state.turn == .white) 1 else -1;
        // std.debug.print("eval {}, sigm {}, real {}, error^2 {d:.2}, fen {s}\n", .{ multiply * evaluate.evaluateTable(pos), sigmoid(@floatFromInt(multiply * evaluate.evaluateTable(pos))), triplet[1].index(), std.math.pow(f32, sigmoid(@floatFromInt(multiply * evaluate.evaluateTable(pos))) - triplet[1].index(), 2), triplet[0] });
        difference += std.math.pow(f32, sigmoid(@floatFromInt(multiply * evaluate.evaluateTable(pos))) - triplet[1].index(), 2);
    }
    // std.debug.print("mean difference {}\n", .{difference / @as(f32, @floatFromInt(book.len))});
    return difference;
}

fn updateVariable(variable_new: []const types.Value) void {
    for (variable_new, 0..) |variable_current, i| {
        variable.tunables[i].default = variable_current;
    }
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

fn computeDelta(rand: std.Random, deltas: []f32, magnitude: f32) !void {
    for (deltas) |*current_delta| {
        if (rand.boolean()) {
            current_delta.* = magnitude;
        } else {
            current_delta.* = -magnitude;
        }
    }
}

fn applyDelta(variable_new: []types.Value, deltas: []const f32) void {
    for (variable_new, 0..) |*variable_current, i| {
        variable_current.* +|= @intFromFloat(std.math.clamp(deltas[i], std.math.minInt(types.Value), std.math.maxInt(types.Value)));
    }
}

fn applyDeltaNegative(variable_new: []types.Value, deltas: []const f32) void {
    for (variable_new, 0..) |*variable_current, i| {
        variable_current.* -|= @intFromFloat(std.math.clamp(deltas[i], std.math.minInt(types.Value), std.math.maxInt(types.Value)));
    }
}

pub fn run(allocator: std.mem.Allocator, stdout: *std.Io.Writer, iterations: usize) !void {
    var book: std.ArrayList(Triplet) = try readBook(allocator);
    defer book.deinit(allocator);

    // Set vars
    var initial: [variable.tunables.len]types.Value = undefined;
    variable.getValues(&initial);

    var initial_delta_plus = initial;
    var initial_delta_minus = initial;
    var delta: [variable.tunables.len]f32 = @splat(0);

    // Fit parameters
    const batch: usize = 1e6;
    const print_step: usize = 10;
    var plateau_counter: usize = 0;

    // Hyper parameters
    const alpha: f32 = 0.602; // Learning rate decay
    const gamma: f32 = 0.101; // Perturbation decay

    const a: f32 = 1.5; // Learning rate scale, chosen such as (a/(A+1)^alpha * 30) is the smallest variation in first iterations after A
    const c: f32 = 5; // Perturbation scale 1-10% range of parameters
    const A: f32 = 0.1 * @as(f32, @floatFromInt(iterations)); // Stability delay, should remain < 10% of iterations

    updateVariable(&initial);
    const initial_eval: f32 = try eval(book.items[0..batch]);
    try stdout.print("Initial error: {d}\n", .{initial_eval});

    var prng = std.Random.DefaultPrng.init(seed: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :seed seed;
    });
    const rand = prng.random();

    for (0..iterations) |k_| {
        const k: f32 = @floatFromInt(k_);
        const ak = a / std.math.pow(f32, k + 1 + A, alpha);
        const ck = c / std.math.pow(f32, k + 1, gamma);

        try computeDelta(rand, &delta, 2 * ck);

        initial_delta_plus = initial;
        initial_delta_minus = initial;

        applyDelta(&initial_delta_plus, delta[0..]);
        updateVariable(&initial_delta_plus);
        const v1: f32 = try eval(book.items[0..batch]);

        applyDeltaNegative(&initial_delta_minus, delta[0..]);
        updateVariable(&initial_delta_minus);
        const v2: f32 = try eval(book.items[0..batch]);

        const match: f32 = v1 - v2;

        for (&initial, 0..) |*param, i| {
            if (delta[i] == 0)
                break;
            const variation: types.Value = @intFromFloat(@max(@min(ak * (match / delta[i]), std.math.maxInt(types.Value)), std.math.minInt(types.Value)));
            if (variation == 0)
                // continue;
                break;

            plateau_counter = 0;

            param.* -|= variation;
            if (k_ % print_step == 0 and i == 0)
                std.debug.print("variation {}\n", .{variation});
        }

        if (k > A)
            plateau_counter += 1;

        // std.debug.print("mean {d:.3}\n", .{(v1 + v2) / 2.0});
        if (k_ % print_step == 0)
            std.debug.print("mean {d}\n", .{(v1 + v2) / 2.0});

        // Break if 50 iterations without improvements
        if (plateau_counter >= 50) {
            break;
        }
    }

    const final_eval: f32 = try eval(book.items[0..batch]);

    try stdout.print("Error went from {d} to {d}\n", .{ initial_eval, final_eval });

    try stdout.print("Found variables:\n", .{});
    for (initial) |param| {
        try stdout.print("{:>4}, ", .{param});
    }
    try stdout.print("\n", .{});
}
