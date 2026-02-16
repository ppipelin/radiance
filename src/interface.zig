const evaluate = @import("evaluate.zig");
const position = @import("position.zig");
const search = @import("search.zig");
const std = @import("std");
const types = @import("types.zig");
const variable = @import("variable.zig");

pub var g_stop = false;
pub var search_thread: ?std.Thread = null;
pub var limits: Limits = Limits{};
pub var remaining: types.TimePoint = 0;
pub var increment: types.TimePoint = 0;
pub var nodes_searched: u64 = 0;
pub var seldepth: u64 = 0;
pub var transposition_used: u64 = 0;

const StateList = std.ArrayListUnmanaged(position.State);

pub const Limits = struct {
    movestogo: u8 = 0,
    depth: u8 = 99,
    mate: u8 = 0,
    perft: u8 = 0,
    infinite: bool = false,
    nodes: u32 = 0,
    time: [types.Color.nb()]types.TimePoint = @splat(0),
    inc: [types.Color.nb()]types.TimePoint = @splat(0),
    start: types.TimePoint = 0,
    movetime: types.TimePoint = 0,
};

pub const Option = struct {
    default_value: []const u8 = "",
    current_value: []const u8 = "",
    type: []const u8 = "",
    min: i32 = 0,
    max: i32 = 0,
    idx: usize = 0, // Order of Option in the OptionsMap

    pub inline fn initCombo(allocator: std.mem.Allocator, default: []const u8, current: []const u8) !Option {
        return Option{ .type = "combo", .default_value = try allocator.dupe(u8, default), .current_value = try allocator.dupe(u8, current) };
    }

    pub inline fn initSpin(allocator: std.mem.Allocator, v: []const u8, min: i32, max: i32) !Option {
        return Option{ .type = "spin", .default_value = try allocator.dupe(u8, v), .current_value = try allocator.dupe(u8, v), .max = max, .min = min };
    }

    pub inline fn initCheck(allocator: std.mem.Allocator, default: []const u8, current: []const u8) !Option {
        return Option{ .type = "check", .default_value = try allocator.dupe(u8, default), .current_value = try allocator.dupe(u8, current) };
    }
};

pub fn initOptions(allocator: std.mem.Allocator, options: *std.StringArrayHashMapUnmanaged(Option)) !void {
    try options.put(allocator, "Hash", try Option.initSpin(allocator, "256", 0, 65535));
    try options.put(allocator, "Threads", try Option.initSpin(allocator, "1", 1, 1));
    try options.put(allocator, "Evaluation", try Option.initCombo(allocator, "PSQ var PSQ var Shannon", "PSQ"));
    try options.put(allocator, "Search", try Option.initCombo(allocator, "NegamaxAlphaBeta var NegamaxAlphaBeta var Random", "NegamaxAlphaBeta"));
    try options.put(allocator, "UCI_Chess960", try Option.initCheck(allocator, "false", "false"));
    for (variable.tunables) |tunable| {
        const min: i32 = @intCast(tunable.min orelse std.math.minInt(types.Value));
        const max: i32 = @intCast(tunable.max orelse std.math.maxInt(types.Value));

        var buffer: [32]u8 = undefined;
        const slice = try std.fmt.bufPrint(&buffer, "{d}", .{tunable.default});

        try options.put(allocator, tunable.name, try Option.initSpin(allocator, slice, min, max));
    }
}

pub fn deinitOptions(allocator: std.mem.Allocator, options: *std.StringArrayHashMapUnmanaged(Option)) void {
    const keys = options.keys();
    for (keys) |key| {
        const option: Option = options.get(key).?;
        allocator.free(option.current_value);
        allocator.free(option.default_value);
    }
    options.deinit(allocator);
}

pub fn printOptions(writer: *std.Io.Writer, options: std.StringArrayHashMapUnmanaged(Option)) void {
    const keys = options.keys();
    for (keys) |key| {
        const option: Option = options.get(key).?;
        writer.print("option name {s} type {s} default {s} ", .{ key, option.type, option.default_value }) catch unreachable;
        if (std.ascii.eqlIgnoreCase(option.type, "spin")) {
            writer.print("min {} max {}", .{ option.min, option.max }) catch unreachable;
        }
        writer.print("\n", .{}) catch unreachable;
    }
}

pub fn loop(allocator: std.mem.Allocator, stdin: *std.Io.Reader, stdout: *std.Io.Writer) !void {
    var options: std.StringArrayHashMapUnmanaged(Option) = .empty;
    defer deinitOptions(allocator, &options);
    try initOptions(allocator, &options);

    var states: StateList = .empty;
    try states.ensureTotalCapacity(allocator, 1024); // Necessary because extending invalidates pointers
    defer states.deinit(allocator);

    states.appendAssumeCapacity(position.State{});
    var pos: position.Position = try position.Position.setFen(&states.items[0], position.start_fen);

    while (true) {
        const line: []u8 = try stdin.takeDelimiter('\n') orelse break;

        const tline: []const u8 = std.mem.trim(u8, line, " \r");

        var tokens = std.mem.tokenizeScalar(u8, tline, ' ');
        const token: []const u8 = tokens.next() orelse break;

        const primary_token: []const u8 = token;

        var existing_command: bool = false;

        if (std.ascii.eqlIgnoreCase("quit", primary_token) or std.ascii.eqlIgnoreCase("exit", primary_token)) {
            existing_command = true;
            g_stop = true;
            break;
        }

        if (std.ascii.eqlIgnoreCase("stop", primary_token)) {
            existing_command = true;
            g_stop = true;
            try stdout.print("Stopped search\n", .{});
        }

        if (std.ascii.eqlIgnoreCase("license", primary_token) or std.ascii.eqlIgnoreCase("--license", primary_token)) {
            existing_command = true;
            try stdout.print(
                \\Radiance is chess engine for playing and analyzing.
                \\It is released as free software licensed under the GNU GPLv3 License.
                \\Radiance is normally used with a graphical user interface (GUI) and supports Universal Chess Interface (UCI) protocol to communicate with a GUI, an API, etc.
                \\Read the README.md or LICENSE.md for further information.
                \\
            , .{});
        }

        if (std.ascii.eqlIgnoreCase("uci", primary_token)) {
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

        if (std.ascii.eqlIgnoreCase("ucinewgame", primary_token)) {
            existing_command = true;
            pos = try position.Position.setFen(&states.items[0], position.start_fen);
        }

        if (std.ascii.eqlIgnoreCase("position", primary_token)) {
            existing_command = true;
            cmd_position(&pos, &tokens, &states) catch |err| {
                try stdout.print("Command position failed with error {}, reset to startpos\n", .{err});
                states.clearRetainingCapacity();
                states.appendAssumeCapacity(position.State{});
                pos = try position.Position.setFen(&states.items[0], position.start_fen);
            };
        }

        if (std.ascii.eqlIgnoreCase("go", primary_token)) {
            existing_command = true;

            if (search_thread != null) {
                g_stop = true;
                search_thread.?.join();
                search_thread = null;
            }

            search_thread = std.Thread.spawn(
                .{ .stack_size = 64 * 1024 * 1024 },
                cmd_go,
                .{ allocator, stdout, &pos, &tokens, options },
            ) catch |err| {
                try stdout.print("Could not spawn thread! With error {}\n", .{err});
                states.clearRetainingCapacity();
                states.appendAssumeCapacity(position.State{});
                pos = try position.Position.setFen(&states.items[0], position.start_fen);
                return;
            };
        }

        if (std.ascii.eqlIgnoreCase("bench", primary_token)) {
            existing_command = true;
            try cmd_bench(allocator, stdout);
        }

        if (std.ascii.eqlIgnoreCase("isready", primary_token)) {
            existing_command = true;
            try stdout.print("readyok\n", .{});
        }

        if (std.ascii.eqlIgnoreCase("setoption", primary_token)) {
            existing_command = true;
            var tmp_options: std.StringArrayHashMapUnmanaged(Option) = try options.clone(allocator);
            defer tmp_options.deinit(allocator);
            cmd_setoption(allocator, &tokens, &options) catch |err| {
                try stdout.print("Command setoption failed with error {}\n", .{err});
                options.deinit(allocator);
                options = try tmp_options.clone(allocator);
            };
        }

        if (std.ascii.eqlIgnoreCase("ponderhit", primary_token)) {
            existing_command = true;
            try stdout.print("UCI - Received ponderhit\n", .{});
        }

        if (std.ascii.eqlIgnoreCase("d", primary_token)) {
            existing_command = true;
            pos.print(stdout);
        }

        if (std.ascii.eqlIgnoreCase("eval", primary_token)) {
            existing_command = true;
            const evaluation_mode: []const u8 = options.get("Evaluation").?.current_value;
            if (std.ascii.eqlIgnoreCase(evaluation_mode, "Shannon")) {
                try stdout.print("Eval Shannon: {}\n", .{evaluate.evaluateShannon(pos)});
            } else if (std.ascii.eqlIgnoreCase(evaluation_mode, "PSQ")) {
                try stdout.print("Eval Table: {}\n", .{evaluate.evaluateTable(pos)});
            }
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

        try stdout.flush();
    }
    if (search_thread != null) {
        g_stop = true;
        search_thread.?.join();
        search_thread = null;
    }
}

fn cmd_setoption(allocator: std.mem.Allocator, tokens: anytype, options: *std.StringArrayHashMapUnmanaged(Option)) !void {
    var name: []const u8 = undefined;
    var value: []const u8 = undefined;

    // Consume the "name" token
    if (tokens.next() == null) {
        return;
    }

    var list: std.ArrayListUnmanaged(u8) = .empty;
    defer list.deinit(allocator);

    // Read the option name (can contain spaces) until value
    while (tokens.next()) |token_in| {
        std.debug.print("token_in {s}\n", .{token_in});
        if (std.ascii.eqlIgnoreCase("value", token_in))
            break;
        if (list.items.len != 0)
            try list.append(allocator, ' ');
        try list.appendSlice(allocator, token_in);
    }
    name = try list.toOwnedSlice(allocator);

    // Read the option value (can contain spaces)
    while (tokens.next()) |token_in| {
        if (list.items.len != 0)
            try list.append(allocator, ' ');
        try list.appendSlice(allocator, token_in);
    }
    value = try list.toOwnedSlice(allocator);

    if (options.contains(name)) {
        var option = options.get(name).?;
        option.current_value = value;
        if (std.ascii.eqlIgnoreCase(option.type, "spin")) {
            const value_parsed = try std.fmt.parseInt(i64, value, 10);
            if (value_parsed > option.max) {
                return error.UpperBoundBreached;
            } else if (value_parsed < option.min) {
                return error.LowerBoundBreached;
            }

            // If option name is tunable edit variable.tunables
            // tunables are only spin
            inline for (&variable.tunables) |*tunable| {
                if (std.ascii.eqlIgnoreCase(tunable.name, name)) {
                    tunable.default = @intCast(value_parsed);
                }
            }
        }

        try options.put(allocator, name, option);
    } else {
        return error.UnknownOption;
    }
}

fn cmd_position(noalias pos: *position.Position, tokens: anytype, noalias states: *StateList) !void {
    var fen: []const u8 = position.start_fen;
    var token: ?[]const u8 = tokens.next();
    var tokens_rest: ?[]const u8 = null;

    if (token == null) {
        return;
    }

    if (std.ascii.eqlIgnoreCase("startpos", token.?)) {} else if (std.ascii.eqlIgnoreCase("kiwi", token.?)) {
        fen = position.kiwi_fen;
    } else if (std.ascii.eqlIgnoreCase("lasker", token.?)) {
        fen = position.lasker_fen;
    } else if (std.ascii.eqlIgnoreCase("fen", token.?)) {
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
    if (token != null and std.ascii.eqlIgnoreCase("moves", token.?)) {
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

fn cmd_go(allocator: std.mem.Allocator, stdout: *std.Io.Writer, noalias pos: *position.Position, tokens: anytype, options: std.StringArrayHashMapUnmanaged(Option)) !void {
    limits = Limits{};
    g_stop = false;

    limits.start = types.now();

    while (tokens.next()) |token_name| {
        // Needs to be the last command on the line
        if (std.ascii.eqlIgnoreCase("searchmoves", token_name)) {
            // TODO
            break;
        } else if (std.ascii.eqlIgnoreCase("wtime", token_name)) {
            if (tokens.next()) |token_value| {
                limits.time[types.Color.white.index()] = try std.fmt.parseInt(types.TimePoint, token_value, 10);
            } else {
                return error.MissingParameter;
            }
        } else if (std.ascii.eqlIgnoreCase("btime", token_name)) {
            if (tokens.next()) |token_value| {
                limits.time[types.Color.black.index()] = try std.fmt.parseInt(types.TimePoint, token_value, 10);
            } else {
                return error.MissingParameter;
            }
        } else if (std.ascii.eqlIgnoreCase("winc", token_name)) {
            if (tokens.next()) |token_value| {
                std.debug.print("token value {s}\n", .{token_value});
                limits.inc[types.Color.white.index()] = try std.fmt.parseInt(types.TimePoint, token_value, 10);
            } else {
                return error.MissingParameter;
            }
        } else if (std.ascii.eqlIgnoreCase("binc", token_name)) {
            if (tokens.next()) |token_value| {
                limits.inc[types.Color.black.index()] = try std.fmt.parseInt(types.TimePoint, token_value, 10);
            } else {
                return error.MissingParameter;
            }
        } else if (std.ascii.eqlIgnoreCase("movestogo", token_name)) {
            if (tokens.next()) |token_value| {
                limits.movestogo = try std.fmt.parseInt(u8, token_value, 10);
            } else {
                return error.MissingParameter;
            }
        } else if (std.ascii.eqlIgnoreCase("depth", token_name)) {
            if (tokens.next()) |token_value| {
                limits.depth = try std.fmt.parseInt(u8, token_value, 10);
            } else {
                return error.MissingParameter;
            }
        } else if (std.ascii.eqlIgnoreCase("nodes", token_name)) {
            if (tokens.next()) |token_value| {
                limits.nodes = try std.fmt.parseInt(u32, token_value, 10);
            } else {
                return error.MissingParameter;
            }
        } else if (std.ascii.eqlIgnoreCase("movetime", token_name)) {
            if (tokens.next()) |token_value| {
                limits.movetime = try std.fmt.parseInt(types.TimePoint, token_value, 10);
            } else {
                return error.MissingParameter;
            }
        } else if (std.ascii.eqlIgnoreCase("mate", token_name)) {
            if (tokens.next()) |token_value| {
                limits.mate = try std.fmt.parseInt(u8, token_value, 10);
            } else {
                return error.MissingParameter;
            }
        } else if (std.ascii.eqlIgnoreCase("perft", token_name)) {
            if (tokens.next()) |token_value| {
                limits.perft = try std.fmt.parseInt(u8, token_value, 10);
            } else {
                return error.MissingParameter;
            }
        } else if (std.ascii.eqlIgnoreCase("infinite", token_name)) {
            limits.infinite = true;
        } else if (std.ascii.eqlIgnoreCase("ponder", token_name)) {}
    }

    const is_960: bool = std.ascii.eqlIgnoreCase(options.get("UCI_Chess960").?.current_value, "true");

    var t = try std.time.Timer.start();
    if (limits.perft > 0) {
        const nodes = if (is_960) try search.perft(allocator, stdout, pos, limits.perft, true, true) else try search.perft(allocator, stdout, pos, limits.perft, false, true);
        const nodes_f: f64 = @floatFromInt(nodes);
        const time_f: f64 = @floatFromInt(t.read());
        try stdout.print("info nodes {} time {D} ({d:.1} Mnps)\n", .{ nodes, t.read(), (nodes_f / (time_f / 1000.0)) });
        try stdout.flush();
    } else {
        const evaluation_mode: []const u8 = options.get("Evaluation").?.current_value;

        const search_mode: []const u8 = options.get("Search").?.current_value;
        if (std.ascii.eqlIgnoreCase(search_mode, "Random")) {
            try stdout.print("bestmove ", .{});
            if (is_960) {
                try (try search.searchRandom(pos, true)).printUCI(stdout);
            } else {
                try (try search.searchRandom(pos, false)).printUCI(stdout);
            }
            try stdout.print("\n", .{});
        } else if (std.ascii.eqlIgnoreCase(search_mode, "NegamaxAlphaBeta")) {
            var move: types.Move = .none;
            if (std.ascii.eqlIgnoreCase(evaluation_mode, "Materialist")) {
                move = try search.iterativeDeepening(allocator, stdout, pos, limits, evaluate.evaluateMaterialist, options);
            } else if (std.ascii.eqlIgnoreCase(evaluation_mode, "Shannon")) {
                move = try search.iterativeDeepening(allocator, stdout, pos, limits, evaluate.evaluateShannon, options);
            } else if (std.ascii.eqlIgnoreCase(evaluation_mode, "PSQ")) {
                move = try search.iterativeDeepening(allocator, stdout, pos, limits, evaluate.evaluateTable, options);
            }
            try stdout.print("bestmove ", .{});
            try move.printUCI(stdout);
            try stdout.print("\n", .{});
        } else {
            try stdout.print("Search mode {s} not implemented\n", .{search_mode});
        }

        try stdout.flush();
    }
}

pub fn cmd_bench(allocator: std.mem.Allocator, stdout: *std.Io.Writer) anyerror!void {
    var t = try std.time.Timer.start();

    var list: std.ArrayListUnmanaged([]const u8) = .empty;
    defer list.deinit(allocator);

    try list.append(allocator, "fen rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");
    try list.append(allocator, "fen r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 10");
    try list.append(allocator, "fen 8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 11");
    try list.append(allocator, "fen 4rrk1/pp1n3p/3q2pQ/2p1pb2/2PP4/2P3N1/P2B2PP/4RRK1 b - - 7 19");
    try list.append(allocator, "fen rq3rk1/ppp2ppp/1bnpb3/3N2B1/3NP3/7P/PPPQ1PP1/2KR3R w - - 7 14 moves d4e6");
    try list.append(allocator, "fen r1bq1r1k/1pp1n1pp/1p1p4/4p2Q/4Pp2/1BNP4/PPP2PPP/3R1RK1 w - - 2 14 moves g2g4");
    try list.append(allocator, "fen r3r1k1/2p2ppp/p1p1bn2/8/1q2P3/2NPQN2/PPP3PP/R4RK1 b - - 2 15");
    try list.append(allocator, "fen r1bbk1nr/pp3p1p/2n5/1N4p1/2Np1B2/8/PPP2PPP/2KR1B1R w kq - 0 13");
    try list.append(allocator, "fen r1bq1rk1/ppp1nppp/4n3/3p3Q/3P4/1BP1B3/PP1N2PP/R4RK1 w - - 1 16");
    try list.append(allocator, "fen 4r1k1/r1q2ppp/ppp2n2/4P3/5Rb1/1N1BQ3/PPP3PP/R5K1 w - - 1 17");
    try list.append(allocator, "fen 2rqkb1r/ppp2p2/2npb1p1/1N1Nn2p/2P1PP2/8/PP2B1PP/R1BQK2R b KQ - 0 11");
    try list.append(allocator, "fen r1bq1r1k/b1p1npp1/p2p3p/1p6/3PP3/1B2NN2/PP3PPP/R2Q1RK1 w - - 1 16");
    try list.append(allocator, "fen 3r1rk1/p5pp/bpp1pp2/8/q1PP1P2/b3P3/P2NQRPP/1R2B1K1 b - - 6 22");
    try list.append(allocator, "fen r1q2rk1/2p1bppp/2Pp4/p6b/Q1PNp3/4B3/PP1R1PPP/2K4R w - - 2 18");
    try list.append(allocator, "fen 4k2r/1pb2ppp/1p2p3/1R1p4/3P4/2r1PN2/P4PPP/1R4K1 b - - 3 22");
    try list.append(allocator, "fen 3q2k1/pb3p1p/4pbp1/2r5/PpN2N2/1P2P2P/5PP1/Q2R2K1 b - - 4 26");
    try list.append(allocator, "fen 6k1/6p1/6Pp/ppp5/3pn2P/1P3K2/1PP2P2/3N4 b - - 0 1");
    try list.append(allocator, "fen 3b4/5kp1/1p1p1p1p/pP1PpP1P/P1P1P3/3KN3/8/8 w - - 0 1");
    try list.append(allocator, "fen 2K5/p7/7P/5pR1/8/5k2/r7/8 w - - 0 1 moves g5g6 f3e3 g6g5 e3f3");
    try list.append(allocator, "fen 8/6pk/1p6/8/PP3p1p/5P2/4KP1q/3Q4 w - - 0 1");
    try list.append(allocator, "fen 7k/3p2pp/4q3/8/4Q3/5Kp1/P6b/8 w - - 0 1");
    try list.append(allocator, "fen 8/2p5/8/2kPKp1p/2p4P/2P5/3P4/8 w - - 0 1");
    try list.append(allocator, "fen 8/1p3pp1/7p/5P1P/2k3P1/8/2K2P2/8 w - - 0 1");
    try list.append(allocator, "fen 8/pp2r1k1/2p1p3/3pP2p/1P1P1P1P/P5KR/8/8 w - - 0 1");
    try list.append(allocator, "fen 8/3p4/p1bk3p/Pp6/1Kp1PpPp/2P2P1P/2P5/5B2 b - - 0 1");
    try list.append(allocator, "fen 5k2/7R/4P2p/5K2/p1r2P1p/8/8/8 b - - 0 1");
    try list.append(allocator, "fen 6k1/6p1/P6p/r1N5/5p2/7P/1b3PP1/4R1K1 w - - 0 1");
    try list.append(allocator, "fen 1r3k2/4q3/2Pp3b/3Bp3/2Q2p2/1p1P2P1/1P2KP2/3N4 w - - 0 1");
    try list.append(allocator, "fen 6k1/4pp1p/3p2p1/P1pPb3/R7/1r2P1PP/3B1P2/6K1 w - - 0 1");
    try list.append(allocator, "fen 8/3p3B/5p2/5P2/p7/PP5b/k7/6K1 w - - 0 1");
    try list.append(allocator, "fen 5rk1/q6p/2p3bR/1pPp1rP1/1P1Pp3/P3B1Q1/1K3P2/R7 w - - 93 90");
    try list.append(allocator, "fen 4rrk1/1p1nq3/p7/2p1P1pp/3P2bp/3Q1Bn1/PPPB4/1K2R1NR w - - 40 21");
    try list.append(allocator, "fen r3k2r/3nnpbp/q2pp1p1/p7/Pp1PPPP1/4BNN1/1P5P/R2Q1RK1 w kq - 0 16");
    try list.append(allocator, "fen 3Qb1k1/1r2ppb1/pN1n2q1/Pp1Pp1Pr/4P2p/4BP2/4B1R1/1R5K b - - 11 40");
    try list.append(allocator, "fen 4k3/3q1r2/1N2r1b1/3ppN2/2nPP3/1B1R2n1/2R1Q3/3K4 w - - 5 1");
    try list.append(allocator, "fen 3r4/4bpk1/5Np1/1p2Pp2/1P3P2/2PpKP2/7P/3R4 b - - 5 38");
    try list.append(allocator, "fen r1b2rk1/pp2nppp/8/8/3q4/1P6/P2NBPPP/R2QK2R b KQ - 0 14");
    try list.append(allocator, "fen r3r1k1/1ppb1p1p/p2p2p1/4nN1q/PP2P3/2P1P1R1/2BQ2PP/5RK1 w - - 0 25");
    try list.append(allocator, "fen r1b1k2r/5ppp/1b2pn2/2Bpq3/8/P3P3/3N1PPP/R1Q1KB1R b KQkq - 0 16");
    try list.append(allocator, "fen 1k1r3r/3n2pp/p2P1p2/1p2n3/P1pB4/6PP/1PK3B1/3R3R w - - 0 27");
    try list.append(allocator, "fen r5k1/2q2ppp/1np2p2/1p6/1P1P1B2/1BP2b1P/4RPP1/3Q2K1 b - - 0 20");
    try list.append(allocator, "fen r1bqkbnr/pp1ppppp/2n5/1B6/3pP3/5N2/PPP2PPP/RNBQK2R b KQkq - 1 4");
    try list.append(allocator, "fen r1bq1r2/p6k/Pp1p3n/2pnpp1Q/4N2N/3B3P/1PP3P1/R4RK1 w - - 0 23");
    try list.append(allocator, "fen r1b2rk1/4pp1p/6pb/p1N5/2QN4/2P4P/Pq3PP1/R2R2K1 w - - 0 19");
    try list.append(allocator, "fen r1r3k1/pb3pbp/1q1Bp1p1/3pP3/2p2P2/Q1P5/PP4PP/2KR1B1R b - - 0 19");
    try list.append(allocator, "fen 4k3/6R1/8/4B1P1/5PK1/8/6r1/8 w - - 3 62");

    for (list.items) |fen| {
        var options: std.StringArrayHashMapUnmanaged(Option) = .empty;
        defer deinitOptions(allocator, &options);
        try initOptions(allocator, &options);

        var states: StateList = .empty;
        try states.ensureTotalCapacity(allocator, 1024); // Necessary because extending invalidates pointers
        defer states.deinit(allocator);

        states.appendAssumeCapacity(position.State{});
        var tokens_fen = std.mem.tokenizeScalar(u8, fen, ' ');
        var pos: position.Position = undefined;
        try cmd_position(&pos, &tokens_fen, &states);

        const input = "depth 13";
        var tokens = std.mem.tokenizeScalar(u8, input, ' ');

        try cmd_go(allocator, stdout, &pos, &tokens, options);
    }

    stdout.print("Time elapsed: {D}\n", .{t.read()}) catch unreachable;
}
