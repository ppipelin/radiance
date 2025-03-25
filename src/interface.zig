const evaluate = @import("evaluate.zig");
const position = @import("position.zig");
const search = @import("search.zig");
const std = @import("std");
const types = @import("types.zig");

pub var g_stop = false;
pub var limits: Limits = Limits{};
pub var remaining: types.TimePoint = 0;
pub var increment: types.TimePoint = 0;
pub var nodes_searched: u64 = 0;
pub var transposition_used: u64 = 0;

const StateList = std.ArrayListUnmanaged(position.State);

pub const Limits = struct {
    movestogo: u8 = 0,
    depth: u8 = 99,
    mate: u8 = 0,
    perft: u8 = 0,
    infinite: bool = false,
    nodes: u32 = 0,
    time: [types.Color.nb()]types.TimePoint = [_]types.TimePoint{0} ** types.Color.nb(),
    inc: [types.Color.nb()]types.TimePoint = [_]types.TimePoint{0} ** types.Color.nb(),
    start: types.TimePoint = 0,
    movetime: types.TimePoint = 0,
};

const Option = struct {
    default_value: []const u8 = "",
    current_value: []const u8 = "",
    type: []const u8 = "",
    min: u16 = 0,
    max: u16 = 0,
    idx: usize = 0, // Order of Option in the OptionsMap

    pub inline fn initCombo(default: []const u8, current: []const u8) Option {
        return Option{ .type = "combo", .default_value = default, .current_value = current };
    }

    pub inline fn initSpin(v: []const u8, min: u16, max: u16) Option {
        return Option{ .type = "spin", .default_value = v, .current_value = v, .max = max, .min = min };
    }
};

fn initOptions(allocator: std.mem.Allocator, options: *std.StringArrayHashMapUnmanaged(Option)) !void {
    try options.put(allocator, "Threads", Option.initSpin("1", 1, 1));
    try options.put(allocator, "Hash", Option.initSpin("256", 0, 4096));
    try options.put(allocator, "Search", Option.initCombo("NegamaxAlphaBeta var NegamaxAlphaBeta var Minimax var Random", "NegamaxAlphaBeta"));
    try options.put(allocator, "Evaluation", Option.initCombo("PSQ var PSQ var Shannon", "PSQ"));
}

pub fn printOptions(writer: anytype, options: std.StringArrayHashMapUnmanaged(Option)) void {
    const keys = options.keys();
    for (keys) |key| {
        const option: Option = options.get(key).?;
        writer.print("option name {s} type {s} default {s} ", .{ key, option.type, option.default_value }) catch unreachable;
        if (std.mem.eql(u8, key, "spin")) {
            writer.print("min {} max {}", .{ option.min, option.max }) catch unreachable;
        }
        writer.print("\n", .{}) catch unreachable;
    }
}

pub fn loop(allocator: std.mem.Allocator, stdin: anytype, stdout: anytype) !void {
    var options: std.StringArrayHashMapUnmanaged(Option) = .empty;
    defer options.deinit(allocator);
    try initOptions(allocator, &options);

    var states: StateList = .empty;
    try states.ensureTotalCapacity(allocator, 1024); // Necessary because extending invalidates pointers
    defer states.deinit(allocator);

    states.appendAssumeCapacity(position.State{});
    var pos: position.Position = try position.Position.setFen(&states.items[states.items.len - 1], position.start_fen);

    var alloc = std.heap.ArenaAllocator.init(allocator);
    defer alloc.deinit();
    while (true) {
        const line = try stdin.readUntilDelimiterOrEofAlloc(alloc.allocator(), '\n', 4096);
        if (line == null) {
            break;
        }
        const tline: []const u8 = std.mem.trim(u8, line.?, " \r");

        var tokens = std.mem.tokenizeScalar(u8, tline, ' ');
        const token: ?[]const u8 = tokens.next();
        if (token == null) {
            break;
        }
        const primary_token: []const u8 = token.?;

        var existing_command: bool = false;

        if (std.mem.eql(u8, "quit", primary_token) or std.mem.eql(u8, "exit", primary_token)) {
            existing_command = true;
            g_stop = true;
            break;
        }

        if (std.mem.eql(u8, "stop", primary_token)) {
            existing_command = true;
            g_stop = true;
            try stdout.print("Stopped search\n", .{});
        }

        if (std.mem.eql(u8, "license", primary_token) or std.mem.eql(u8, "--license", primary_token)) {
            existing_command = true;
            try stdout.print(
                \\Radiance is chess engine for playing and analyzing.
                \\It is released as free software licensed under the GNU GPLv3 License.
                \\Radiance is normally used with a graphical user interface (GUI) and supports Universal Chess Interface (UCI) protocol to communicate with a GUI, an API, etc.
                \\Read the README.md or LICENSE.md for further information.
                \\
            , .{});
        }

        if (std.mem.eql(u8, "uci", primary_token)) {
            existing_command = true;
            try stdout.print(
                \\id name Radiance {s}
                \\id author Paul-Elie Pipelin (ppipelin)
                \\
            , .{types.computeVersion()});
            printOptions(stdout, options);
            try stdout.print(
                \\uciok
                \\
            , .{});
        }

        if (std.mem.eql(u8, "ucinewgame", primary_token)) {
            existing_command = true;
            pos = try position.Position.setFen(&states.items[states.items.len - 1], position.start_fen);
        }

        if (std.mem.eql(u8, "position", primary_token)) {
            existing_command = true;
            cmd_position(&pos, &tokens, &states) catch |err| {
                try stdout.print("Command position failed with error {}, reset to startpos\n", .{err});
                states.clearRetainingCapacity();
                states.appendAssumeCapacity(position.State{});
                pos = try position.Position.setFen(&states.items[states.items.len - 1], position.start_fen);
            };
        }

        if (std.mem.eql(u8, "go", primary_token)) {
            existing_command = true;
            cmd_go(allocator, stdout, &pos, &tokens, &states, &options) catch |err| {
                try stdout.print("Command go failed with error {}, reset to startpos\n", .{err});
                states.clearRetainingCapacity();
                states.appendAssumeCapacity(position.State{});
                pos = try position.Position.setFen(&states.items[states.items.len - 1], position.start_fen);
            };
        }

        if (std.mem.eql(u8, "isready", primary_token)) {
            existing_command = true;
            try stdout.print("readyok\n", .{});
        }

        if (std.mem.eql(u8, "setoption", primary_token)) {
            existing_command = true;
            var tmp_options: std.StringArrayHashMapUnmanaged(Option) = try options.clone(allocator);
            defer tmp_options.deinit(allocator);
            cmd_setoption(allocator, &tokens, &options) catch |err| {
                try stdout.print("Command setoption failed with error {}\n", .{err});
                options.deinit(allocator);
                options = try tmp_options.clone(allocator);
            };
        }

        if (std.mem.eql(u8, "ponderhit", primary_token)) {
            existing_command = true;
            try stdout.print("UCI - Received ponderhit\n", .{});
        }

        if (std.mem.eql(u8, "d", primary_token)) {
            existing_command = true;
            pos.print(stdout);
        }

        if (std.mem.eql(u8, "eval", primary_token)) {
            existing_command = true;
            try stdout.print("UCI - Received eval\n", .{});
        }

        if (!existing_command) {
            try stdout.print(
                \\Commands:
                \\  license
                \\  uci
                \\  isready
                \\  setoption name <id> [value <x>]
                \\  ucinewgame
                \\  position [fen <string> | startpos | kiwi | lasker] [moves <string>...]
                \\  go [movetime <int> | [wtime <int>] [btime <int>] [winc <int>] [binc <int>] | depth <int> | infinite | perft <int>]
                \\  stop
                \\  ponderhit
                \\  d
                \\  eval
                \\  quit
                \\
            , .{});
        }
    }
}

fn cmd_setoption(allocator: std.mem.Allocator, tokens: anytype, options: *std.StringArrayHashMapUnmanaged(Option)) !void {
    var token: ?[]const u8 = tokens.next();
    var name: []const u8 = undefined;
    var value: []const u8 = undefined;

    if (token == null) {
        return;
    }

    // Consume the "name" token
    token = tokens.next();
    if (token == null) {
        return;
    }

    var list: std.ArrayListUnmanaged(u8) = .empty;
    defer list.deinit(allocator);

    // Read the option name (can contain spaces)
    while (token != null and !std.mem.eql(u8, "value", token.?)) : (token = tokens.next()) {
        if (list.items.len != 0)
            try list.append(allocator, ' ');
        try list.appendSlice(allocator, token.?);
    }
    name = try list.toOwnedSlice(allocator);

    // Consume the "value" token
    token = tokens.next();
    if (token == null) {
        return;
    }

    // Read the option value (can contain spaces)
    while (token != null) : (token = tokens.next()) {
        if (list.items.len != 0)
            try list.append(allocator, ' ');
        try list.appendSlice(allocator, token.?);
    }
    value = try list.toOwnedSlice(allocator);

    if (options.contains(name)) {
        var option = options.get(name).?;
        option.current_value = value;
        try options.put(allocator, name, option);
    } else {
        return error.UnknownOption;
    }
}

fn cmd_position(pos: *position.Position, tokens: anytype, states: *StateList) !void {
    var fen: []const u8 = position.start_fen;
    var token: ?[]const u8 = tokens.next();
    var tokens_rest: ?[]const u8 = null;

    if (token == null) {
        return;
    }

    if (std.mem.eql(u8, "startpos", token.?)) {} else if (std.mem.eql(u8, "kiwi", token.?)) {
        fen = position.kiwi_fen;
    } else if (std.mem.eql(u8, "lasker", token.?)) {
        fen = position.lasker_fen;
    } else if (std.mem.eql(u8, "fen", token.?)) {
        var tokens_split = std.mem.splitSequence(u8, tokens.rest(), " moves ");
        token = tokens_split.next();
        fen = token.?;
        tokens_rest = tokens_split.next();
    } else {
        return error.UnknownPositionArgument;
    }

    // Drop the first state and create a new one
    states.clearRetainingCapacity();
    states.appendAssumeCapacity(position.State{});
    pos.* = try position.Position.setFen(&states.items[states.items.len - 1], fen);

    token = tokens.next();
    if (token != null and std.mem.eql(u8, "moves", token.?)) {
        tokens_rest = tokens.rest();
    }

    token = tokens.next();
    if (tokens_rest != null) {
        var tokens_rest_iterator = std.mem.tokenizeScalar(u8, tokens_rest.?, ' ');

        token = tokens_rest_iterator.next();

        while (token != null) : (token = tokens_rest_iterator.next()) {
            states.appendAssumeCapacity(position.State{});
            try pos.movePiece(try types.Move.initFromStr(pos.*, token.?), &states.items[states.items.len - 1]);
        }
    }
}

fn cmd_go(allocator: std.mem.Allocator, stdout: anytype, pos: *position.Position, tokens: anytype, states: *StateList, options: *std.StringArrayHashMapUnmanaged(Option)) !void {
    _ = states;
    limits = Limits{};
    var token: ?[]const u8 = tokens.next();
    g_stop = false;

    limits.start = types.now();

    while (token != null) : (token = tokens.next()) {
        // Needs to be the last command on the line
        if (std.mem.eql(u8, "searchmoves", token.?)) {
            // TODO
            break;
        } else if (std.mem.eql(u8, "wtime", token.?)) {
            token = tokens.next();
            if (token == null) {
                return error.MissingParameter;
            }
            limits.time[types.Color.white.index()] = try std.fmt.parseInt(types.TimePoint, token.?, 10);
        } else if (std.mem.eql(u8, "btime", token.?)) {
            token = tokens.next();
            if (token == null) {
                return error.MissingParameter;
            }
            limits.time[types.Color.black.index()] = try std.fmt.parseInt(types.TimePoint, token.?, 10);
        } else if (std.mem.eql(u8, "winc", token.?)) {
            token = tokens.next();
            if (token == null) {
                return error.MissingParameter;
            }
            limits.inc[types.Color.white.index()] = try std.fmt.parseInt(types.TimePoint, token.?, 10);
        } else if (std.mem.eql(u8, "binc", token.?)) {
            token = tokens.next();
            if (token == null) {
                return error.MissingParameter;
            }
            limits.inc[types.Color.black.index()] = try std.fmt.parseInt(types.TimePoint, token.?, 10);
        } else if (std.mem.eql(u8, "movestogo", token.?)) {
            token = tokens.next();
            if (token == null) {
                return error.MissingParameter;
            }
            limits.movestogo = try std.fmt.parseInt(u8, token.?, 10);
        } else if (std.mem.eql(u8, "depth", token.?)) {
            token = tokens.next();
            if (token == null) {
                return error.MissingParameter;
            }
            limits.depth = try std.fmt.parseInt(u8, token.?, 10);
        } else if (std.mem.eql(u8, "nodes", token.?)) {
            token = tokens.next();
            if (token == null) {
                return error.MissingParameter;
            }
            limits.nodes = try std.fmt.parseInt(u32, token.?, 10);
        } else if (std.mem.eql(u8, "movetime", token.?)) {
            token = tokens.next();
            if (token == null) {
                return error.MissingParameter;
            }
            limits.movetime = try std.fmt.parseInt(types.TimePoint, token.?, 10);
        } else if (std.mem.eql(u8, "mate", token.?)) {
            token = tokens.next();
            if (token == null) {
                return error.MissingParameter;
            }
            limits.mate = try std.fmt.parseInt(u8, token.?, 10);
        } else if (std.mem.eql(u8, "perft", token.?)) {
            token = tokens.next();
            if (token == null) {
                return error.MissingParameter;
            }
            limits.perft = try std.fmt.parseInt(u8, token.?, 10);
        } else if (std.mem.eql(u8, "infinite", token.?)) {
            limits.infinite = true;
        } else if (std.mem.eql(u8, "ponder", token.?)) {}
    }

    var t = try std.time.Timer.start();
    if (limits.perft > 0) {
        const nodes = try search.perft(allocator, stdout, pos, limits.perft, true);
        const nodes_f: f64 = @floatFromInt(nodes);
        const time_f: f64 = @floatFromInt(t.read());

        try stdout.print("info nodes {} time {} ({d:.1} Mnps)\n", .{ nodes, std.fmt.fmtDuration(t.read()), (nodes_f / (time_f / 1000.0)) });
    } else {
        const evaluation_mode: []const u8 = options.get("Evaluation").?.current_value;

        const search_mode: []const u8 = options.get("Search").?.current_value;
        if (std.mem.eql(u8, search_mode, "Random")) {
            try stdout.print("bestmove ", .{});
            try (try search.searchRandom(allocator, pos)).printUCI(stdout);
            try stdout.print("\n", .{});
        } else if (std.mem.eql(u8, search_mode, "NegamaxAlphaBeta")) {
            var move: types.Move = .none;
            if (std.mem.eql(u8, evaluation_mode, "Shannon")) {
                move = try search.iterativeDeepening(allocator, stdout, pos, limits, evaluate.evaluateShannon);
            } else if (std.mem.eql(u8, evaluation_mode, "PSQ")) {
                move = try search.iterativeDeepening(allocator, stdout, pos, limits, evaluate.evaluateTable);
            }
            try stdout.print("bestmove ", .{});
            try move.printUCI(stdout);
            try stdout.print("\n", .{});
        } else {
            try stdout.print("Search mode {s} not implemented\n", .{search_mode});
        }
    }
}
