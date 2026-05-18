const interface = @import("interface.zig");
const position = @import("position.zig");
const Search = @import("Search.zig");
const std = @import("std");
const types = @import("types.zig");

var io: std.Io = undefined;
var allocator: std.mem.Allocator = undefined;
var buffer: [2048]u8 = undefined;
var stdout_helper: std.Io.Writer.Discarding = undefined;

pub var threads: std.ArrayListUnmanaged(Thread) = .empty;

pub fn init(io_: std.Io, allocator_: std.mem.Allocator) !void {
    io = io_;
    allocator = allocator_;
    stdout_helper = .init(&buffer);
    threads = .empty;
}

pub fn deinit() void {
    terminateThreads();
    threads.deinit(allocator);
}

// const Thread = std.Thread;
const Thread = struct {
    thread: std.Thread = undefined,
    stopping: bool = false,
    pos: *position.Position = undefined,
    states: interface.StateList = .empty,
    search: Search = .{},

    inline fn clearThread(self: *Thread) void {
        allocator.destroy(self.pos);
        self.states.deinit(allocator);
    }

    fn terminateThread(self: *Thread) void {
        self.thread.join();
        self.clearThread();
    }
};

pub fn addThread(stdout: *std.Io.Writer, noalias pos: *position.Position, states: interface.StateList, limits: interface.Limits, eval: *const fn (pos: *const position.Position) types.Value, options: std.StringArrayHashMapUnmanaged(interface.Option)) !void {
    const current_thread: *Thread = threads.addOneAssumeCapacity();
    current_thread.* = .{}; // Initialization
    current_thread.pos = try pos.clone(allocator, states, &current_thread.states);
    current_thread.search.limits = limits;
    current_thread.thread = std.Thread.spawn(
        .{ .stack_size = 64 * 1024 * 1024 },
        Search.iterativeDeepening,
        .{ &current_thread.search, io, allocator, stdout, current_thread.pos, threads.items.len - 1, eval, options },
    ) catch |err| {
        try stdout.print("Could not spawn thread! With error {}\n", .{err});
        return;
    };
}

/// Has to be followed by clearThreads()
pub fn finishThreads() void {
    for (threads.items) |*thread| {
        thread.thread.join();
    }
}

/// Has to be preceded by finishThreads()
pub fn clearThreads() void {
    for (threads.items) |*thread| {
        thread.clearThread();
    }
    threads.clearRetainingCapacity();
}

pub fn terminateThreads() void {
    for (threads.items) |*thread| {
        thread.terminateThread();
    }
    threads.clearRetainingCapacity();
}

pub fn startThinking(stdout: *std.Io.Writer, noalias pos: *position.Position, states: interface.StateList, limits: interface.Limits, eval: *const fn (pos: *const position.Position) types.Value, options: std.StringArrayHashMapUnmanaged(interface.Option)) !void {
    terminateThreads();

    interface.g_stop.store(false, .release);

    const threads_nb: usize = @intCast(try std.fmt.parseInt(u128, options.get("Threads").?.current_value, 10));
    try threads.ensureTotalCapacity(allocator, threads_nb);

    // Start main thread
    try addThread(stdout, pos, states, limits, eval, options);

    if (threads_nb == 1)
        return;

    // Start helper threads if multi-threaded
    for (1..threads_nb) |_| {
        // go infinite for them and stop using variable ?
        try addThread(&stdout_helper.writer, pos, states, limits, eval, options);
    }
}
