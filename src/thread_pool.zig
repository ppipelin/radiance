const interface = @import("interface.zig");
const position = @import("position.zig");
const search = @import("search.zig");
const std = @import("std");
const types = @import("types.zig");

var io: std.Io = undefined;
var allocator: std.mem.Allocator = undefined;
var buffer: [2048]u8 = undefined;
var stdout_helper: std.Io.Writer.Discarding = undefined;

var threads: std.ArrayListUnmanaged(Thread) = .empty;

pub fn init(io_: std.Io, allocator_: std.mem.Allocator) !void {
    io = io_;
    allocator = allocator_;
    stdout_helper = .init(&buffer);
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

    fn terminateThread(self: *Thread) void {
        self.thread.join();
        allocator.destroy(self.pos);
        self.states.deinit(allocator);
    }
};

pub fn addThread(stdout: *std.Io.Writer, noalias pos: *position.Position, states: interface.StateList, limits: interface.Limits, eval: *const fn (pos: position.Position) types.Value, options: std.StringArrayHashMapUnmanaged(interface.Option)) !void {
    const current_thread: *Thread = threads.addOneAssumeCapacity();
    current_thread.* = .{}; // Initialization
    current_thread.pos = try pos.clone(allocator, states, &current_thread.states);
    current_thread.thread = std.Thread.spawn(
        .{ .stack_size = 64 * 1024 * 1024 },
        search.iterativeDeepening,
        .{ io, allocator, stdout, current_thread.pos, threads.items.len - 1, limits, eval, options },
    ) catch |err| {
        try stdout.print("Could not spawn thread! With error {}\n", .{err});
        return;
    };
}

pub fn terminateThreads() void {
    for (threads.items) |*thread| {
        thread.terminateThread();
    }
    threads.clearRetainingCapacity();
}

pub fn startThinking(stdout: *std.Io.Writer, noalias pos: *position.Position, states: interface.StateList, limits: interface.Limits, eval: *const fn (pos: position.Position) types.Value, options: std.StringArrayHashMapUnmanaged(interface.Option)) !void {
    terminateThreads();

    const threads_nb: usize = @intCast(try std.fmt.parseInt(u128, options.get("Threads").?.current_value, 10));
    try threads.ensureTotalCapacity(allocator, threads_nb);

    // return search.iterativeDeepening(io, allocator, stdout, pos, limits, eval, options);
    // Start main thread

    try addThread(stdout, pos, states, limits, eval, options);

    // Start helper threads if multi-threaded
    if (threads_nb == 1)
        return;

    for (1..threads_nb) |_| {
        // TODO: Permute rootmoves
        // 1 2 3 4
        // 2 1 3 4
        // 3 2 1 4
        // 4 2 3 1
        try addThread(&stdout_helper.writer, pos, states, limits, eval, options);
    }
    // go infinite for them and stop using variable ?
}
