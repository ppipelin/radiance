const evaluate = @import("evaluate.zig");
const interface = @import("interface.zig");
const position = @import("position.zig");
const Search = @import("Search.zig");
const std = @import("std");
const types = @import("types.zig");

var io: std.Io = undefined;
var allocator: std.mem.Allocator = undefined;
var buffer: [2048]u8 = undefined;
var stdout_discard: std.Io.Writer.Discarding = undefined;

/// Thread pointer to make sure there is no lost mutexes on reallocations
pub var threads: std.ArrayListUnmanaged(*Thread) = .empty;

const ThreadState = enum(u8) {
    wait,
    search,
    reset,
    terminate,
};

pub const ThreadData = struct {
    stdout: *std.Io.Writer,
    pos: *position.Position,
    states: interface.StateList,
    limits: interface.Limits = .{},
    eval: *const fn (pos: *const position.Position) types.Value = evaluate.evaluateTable,
    options: std.StringArrayHashMapUnmanaged(interface.Option) = .empty,
};

pub fn init(io_: std.Io, allocator_: std.mem.Allocator) !void {
    io = io_;
    allocator = allocator_;
    stdout_discard = .init(&buffer);
    threads = .empty;
    try setThreads(1);
}

/// Allows to add thread while previous search running
pub fn setThreads(threads_nb: usize) !void {
    try threads.ensureTotalCapacity(allocator, threads_nb);

    var count: usize = threads.items.len;
    while (threads.items.len < threads_nb) {
        try addThread(count);
        count += 1;
    }

    while (threads.items.len > threads_nb)
        try removeThread();

    // go infinite for them and stop using variable ?
}

pub fn deinit() !void {
    try terminateThreads();
    threads.deinit(allocator);
}

// const Thread = std.Thread;
const Thread = struct {
    thread: std.Thread = undefined,
    thread_idx: usize = 0,
    search: Search = .{},

    state: ThreadState = .wait,
    mutex: std.Io.Mutex = .init,
    cond: std.Io.Condition = .init,
    data: ThreadData = undefined,

    fn terminateThread(self: *Thread) !void {
        self.search.should_stop = true;
        // self.state = .terminate;
        // self.cond.signal(io);
        try self.changeState(.terminate);
        self.thread.join();
    }

    fn loop(self: *Thread) !void {
        while (true) {
            try self.mutex.lock(io);
            // Sleep until work arrives
            while (self.state == .wait) {
                try self.cond.wait(io, &self.mutex);
            }

            const state: ThreadState = self.state;
            self.mutex.unlock(io);

            if (state == .terminate)
                break;

            switch (state) {
                .search => {
                    self.search.limits = self.data.limits;

                    var local_states: interface.StateList = .empty;
                    defer local_states.deinit(allocator);
                    const local_pos: *position.Position = try self.data.pos.clone(allocator, self.data.states, &local_states);
                    defer allocator.destroy(local_pos);
                    try self.search.iterativeDeepening(io, allocator, self.data.stdout, local_pos, self.thread_idx, self.data.eval, self.data.options);
                    try self.data.stdout.flush();
                },
                .reset => {
                    self.search.histories = .{};
                },
                else => {},
            }

            // Completed search, back to wait state if terminate wasn't requested earlier
            try self.mutex.lock(io);
            if (self.state != .terminate) {
                self.state = .wait;
                self.cond.signal(io);
            }
            self.mutex.unlock(io);
        }
    }

    pub fn changeState(self: *Thread, state: ThreadState) !void {
        try self.mutex.lock(io);
        self.state = state;
        self.cond.signal(io);
        self.mutex.unlock(io);
    }
};

pub fn addThread(thread_idx: usize) !void {
    const current_thread = try allocator.create(Thread);
    current_thread.* = .{}; // Initialization
    current_thread.thread_idx = thread_idx;
    current_thread.thread = try std.Thread.spawn(
        .{ .stack_size = 64 * 1024 * 1024 },
        Thread.loop,
        .{current_thread},
    );
    try threads.append(allocator, current_thread);
}

/// Terminate thread without interrupting search
pub fn removeThread() !void {
    const last_thread: *Thread = threads.pop() orelse return error.RemoveNullThread;
    try last_thread.terminateThread();
    allocator.destroy(last_thread);
}

pub fn terminateThreads() !void {
    stopSearchs() catch unreachable;
    for (threads.items) |thread| {
        try thread.terminateThread();
        allocator.destroy(thread);
    }
    threads.clearRetainingCapacity();
}

pub fn finishSearchs() !void {
    for (threads.items) |thread| {
        try thread.mutex.lock(io);
        while (thread.state == .search) {
            try thread.cond.wait(io, &thread.mutex);
        }
        thread.mutex.unlock(io);
    }
}

pub fn stopSearchs() !void {
    interface.g_stop.store(true, .release);
    for (threads.items) |thread| {
        thread.search.should_stop = true;
        try thread.changeState(.wait);
    }
}

pub fn reset() !void {
    for (threads.items) |thread| {
        // try thread.changeState(.reset);
        thread.search.histories = .{};
    }
}

pub fn startThinking(data: ThreadData) !void {
    interface.g_stop.store(false, .release);

    for (threads.items) |thread| {
        thread.data = data;
        if (thread.thread_idx != 0) {
            thread.data.stdout = &stdout_discard.writer;
        }
        try thread.changeState(.search);
    }
}
