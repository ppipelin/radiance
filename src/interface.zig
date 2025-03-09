const position = @import("position.zig");
const search = @import("search.zig");
const std = @import("std");
const types = @import("types.zig");

var g_stop = false;

const StateList = std.ArrayListUnmanaged(position.State);

const allocator = std.heap.c_allocator;

pub fn loop(stdin: anytype, stdout: anytype) !void {
    var states: StateList = .empty;
    defer states.deinit(allocator);

    states.append(allocator, position.State{}) catch unreachable;
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
                \\uciok
                \\
            , .{types.computeVersion()});
        }

        if (std.mem.eql(u8, "ucinewgame", primary_token)) {
            existing_command = true;
            pos = try position.Position.setFen(&states.items[states.items.len - 1], position.start_fen);
        }

        if (std.mem.eql(u8, "position", primary_token)) {
            existing_command = true;
            const tmp_position: position.Position = pos;
            const tmp_states: StateList = try states.clone(allocator);
            if (cmd_position(&pos, &tokens, &states)) {} else |err| {
                try stdout.print("Command position failed with error {}\n", .{err});
                pos = tmp_position;
                states = tmp_states;
                pos.state = &states.items[states.items.len - 1];
            }
        }

        if (std.mem.eql(u8, "go", primary_token)) {
            existing_command = true;
            const tmp_position: position.Position = pos;
            const tmp_states: StateList = try states.clone(allocator);
            if (cmd_go(stdout, &pos, &tokens, &states)) {} else |err| {
                try stdout.print("Command go failed with error {}\n", .{err});
                pos = tmp_position;
                states = tmp_states;
                pos.state = &states.items[states.items.len - 1];
            }
        }

        if (std.mem.eql(u8, "isready", primary_token)) {
            existing_command = true;
            try stdout.print("readyok\n", .{});
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
    states.clearAndFree(allocator);
    states.append(allocator, position.State{}) catch unreachable;
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
            states.append(allocator, position.State{}) catch unreachable;
            try pos.movePiece(try types.Move.initFromStr(pos.*, token.?), &states.items[states.items.len - 1]);
        }
    }
}

fn cmd_go(stdout: anytype, pos: *position.Position, tokens: anytype, states: *StateList) !void {
    _ = states;
    var limits: types.Limits = types.Limits{};
    var token: ?[]const u8 = tokens.next();
    g_stop = false;

    limits.start = types.now();

    while (token != null) : (token = tokens.next()) {
        // Needs to be the last command on the line
        if (std.mem.eql(u8, "searchmoves", token.?)) {
            // TODO
            break;
        } else if (std.mem.eql(u8, "wtime", token.?)) {
            limits.time[types.Color.white.index()] = try std.fmt.parseInt(types.TimePoint, tokens.next().?, 10);
        } else if (std.mem.eql(u8, "btime", token.?)) {
            limits.time[types.Color.black.index()] = try std.fmt.parseInt(types.TimePoint, tokens.next().?, 10);
        } else if (std.mem.eql(u8, "winc", token.?)) {
            limits.inc[types.Color.white.index()] = try std.fmt.parseInt(types.TimePoint, tokens.next().?, 10);
        } else if (std.mem.eql(u8, "binc", token.?)) {
            limits.time[types.Color.black.index()] = try std.fmt.parseInt(types.TimePoint, tokens.next().?, 10);
        } // else if (std.mem.eql(u8, "movestogo", token.?)) {
        //     limits.movestogo = try std.fmt.parseInt(u8, tokens.next().?, 10);
        // }
        else if (std.mem.eql(u8, "depth", token.?)) {
            limits.depth = try std.fmt.parseInt(u8, tokens.next().?, 10);
        } // else if (std.mem.eql(u8, "nodes", token.?)) {
        //     limits.nodes = try std.fmt.parseInt(u32, tokens.next().?, 10);
        // }
        else if (std.mem.eql(u8, "movetime", token.?)) {
            limits.movetime = try std.fmt.parseInt(types.TimePoint, tokens.next().?, 10);
        } // else if (std.mem.eql(u8, "mate", token.?)) {
        //     limits.mate = try std.fmt.parseInt(types.TimePoint, tokens.next().?, 10);
        // }
        else if (std.mem.eql(u8, "perft", token.?)) {
            limits.perft = try std.fmt.parseInt(u8, tokens.next().?, 10);
        } else if (std.mem.eql(u8, "infinite", token.?)) {
            limits.infinite = true;
        } // else if (std.mem.eql(u8, "ponder", token.?)) {
        // }
    }

    var t = try std.time.Timer.start();
    if (limits.perft > 0) {
        const nodes = try search.perft(allocator, stdout, pos, limits.perft, true);
        const nodes_f: f64 = @floatFromInt(nodes);
        const time_f: f64 = @floatFromInt(t.read());

        try stdout.print("info nodes {} time {} ({d:.1} Mnps)\n", .{ nodes, std.fmt.fmtDuration(t.read()), (nodes_f / (time_f / 1000.0)) });
    } else {
        try stdout.print("limits {}", .{limits});
    }
}
