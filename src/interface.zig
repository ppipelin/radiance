const position = @import("position.zig");
const std = @import("std");
const types = @import("types.zig");

var g_stop = false;

// A list to keep track of the position states along the setup moves (from the
// start position to the position just before the search starts).
// Needed by 'draw by repetition' detection. Use a std::deque because pointers to
// elements are not invalidated upon list resizing.
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
        // TODO Remove spaces at the begining
        const token: ?[]const u8 = tokens.next();

        if (token == null) {
            break;
        }
        const primary_token: []const u8 = token.?;

        var existing_command: bool = false;

        if (std.mem.eql(u8, "quit", primary_token) or std.mem.eql(u8, "exit", primary_token)) {
            existing_command = true;
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
