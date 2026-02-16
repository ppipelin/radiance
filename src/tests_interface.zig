const evaluate = @import("evaluate.zig");
const interface = @import("interface.zig");
const position = @import("position.zig");
const search = @import("search.zig");
const std = @import("std");
const tables = @import("tables.zig");
const types = @import("types.zig");

const allocator = std.testing.allocator;

test "start_fen" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    const input =
        \\position startpos
        \\d
    ;

    var stdin = std.Io.Reader.fixed(input);

    var output: [4096]u8 = undefined;
    var stdout = std.Io.Writer.fixed(&output);

    try interface.loop(allocator, &stdin, &stdout);

    try std.testing.expectStringStartsWith(stdout.buffer,
        \\ +---+---+---+---+---+---+---+---+
        \\ | r | n | b | q | k | b | n | r | 8
        \\ +---+---+---+---+---+---+---+---+
        \\ | p | p | p | p | p | p | p | p | 7
        \\ +---+---+---+---+---+---+---+---+
        \\ |   |   |   |   |   |   |   |   | 6
        \\ +---+---+---+---+---+---+---+---+
        \\ |   |   |   |   |   |   |   |   | 5
        \\ +---+---+---+---+---+---+---+---+
        \\ |   |   |   |   |   |   |   |   | 4
        \\ +---+---+---+---+---+---+---+---+
        \\ |   |   |   |   |   |   |   |   | 3
        \\ +---+---+---+---+---+---+---+---+
        \\ | P | P | P | P | P | P | P | P | 2
        \\ +---+---+---+---+---+---+---+---+
        \\ | R | N | B | Q | K | B | N | R | 1
        \\ +---+---+---+---+---+---+---+---+
        \\   A   B   C   D   E   F   G   H
        \\
        \\White to move
        \\fen: rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
    );
}

test "kiwipete" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    const input =
        \\position fen r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq -
        \\d
    ;

    var stdin = std.Io.Reader.fixed(input);

    var output: [4096]u8 = undefined;
    var stdout = std.Io.Writer.fixed(&output);

    try interface.loop(allocator, &stdin, &stdout);

    try std.testing.expectStringStartsWith(stdout.buffer,
        \\ +---+---+---+---+---+---+---+---+
        \\ | r |   |   |   | k |   |   | r | 8
        \\ +---+---+---+---+---+---+---+---+
        \\ | p |   | p | p | q | p | b |   | 7
        \\ +---+---+---+---+---+---+---+---+
        \\ | b | n |   |   | p | n | p |   | 6
        \\ +---+---+---+---+---+---+---+---+
        \\ |   |   |   | P | N |   |   |   | 5
        \\ +---+---+---+---+---+---+---+---+
        \\ |   | p |   |   | P |   |   |   | 4
        \\ +---+---+---+---+---+---+---+---+
        \\ |   |   | N |   |   | Q |   | p | 3
        \\ +---+---+---+---+---+---+---+---+
        \\ | P | P | P | B | B | P | P | P | 2
        \\ +---+---+---+---+---+---+---+---+
        \\ | R |   |   |   | K |   |   | R | 1
        \\ +---+---+---+---+---+---+---+---+
        \\   A   B   C   D   E   F   G   H
        \\
        \\White to move
        \\fen: r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1
    );
}

test "start_fenWithSpaces" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    const input =
        \\    position     startpos
        \\d
    ;

    var stdin = std.Io.Reader.fixed(input);

    var output: [4096]u8 = undefined;
    var stdout = std.Io.Writer.fixed(&output);

    try interface.loop(allocator, &stdin, &stdout);

    try std.testing.expectStringStartsWith(stdout.buffer,
        \\ +---+---+---+---+---+---+---+---+
        \\ | r | n | b | q | k | b | n | r | 8
        \\ +---+---+---+---+---+---+---+---+
        \\ | p | p | p | p | p | p | p | p | 7
        \\ +---+---+---+---+---+---+---+---+
        \\ |   |   |   |   |   |   |   |   | 6
        \\ +---+---+---+---+---+---+---+---+
        \\ |   |   |   |   |   |   |   |   | 5
        \\ +---+---+---+---+---+---+---+---+
        \\ |   |   |   |   |   |   |   |   | 4
        \\ +---+---+---+---+---+---+---+---+
        \\ |   |   |   |   |   |   |   |   | 3
        \\ +---+---+---+---+---+---+---+---+
        \\ | P | P | P | P | P | P | P | P | 2
        \\ +---+---+---+---+---+---+---+---+
        \\ | R | N | B | Q | K | B | N | R | 1
        \\ +---+---+---+---+---+---+---+---+
        \\   A   B   C   D   E   F   G   H
        \\
        \\White to move
        \\fen: rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
    );
}

test "ErrorFenPosition" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    const input =
        \\position fen kiwi
        \\d
    ;

    var stdin = std.Io.Reader.fixed(input);

    var output: [4096]u8 = undefined;
    var stdout = std.Io.Writer.fixed(&output);

    try interface.loop(allocator, &stdin, &stdout);

    try std.testing.expectStringStartsWith(stdout.buffer,
        \\Command position failed with error error.UnknownPiece, reset to startpos
        \\ +---+---+---+---+---+---+---+---+
        \\ | r | n | b | q | k | b | n | r | 8
        \\ +---+---+---+---+---+---+---+---+
        \\ | p | p | p | p | p | p | p | p | 7
        \\ +---+---+---+---+---+---+---+---+
        \\ |   |   |   |   |   |   |   |   | 6
        \\ +---+---+---+---+---+---+---+---+
        \\ |   |   |   |   |   |   |   |   | 5
        \\ +---+---+---+---+---+---+---+---+
        \\ |   |   |   |   |   |   |   |   | 4
        \\ +---+---+---+---+---+---+---+---+
        \\ |   |   |   |   |   |   |   |   | 3
        \\ +---+---+---+---+---+---+---+---+
        \\ | P | P | P | P | P | P | P | P | 2
        \\ +---+---+---+---+---+---+---+---+
        \\ | R | N | B | Q | K | B | N | R | 1
        \\ +---+---+---+---+---+---+---+---+
        \\   A   B   C   D   E   F   G   H
        \\
        \\White to move
        \\fen: rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
    );
}

test "ErrorUnknownPosition" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    const input =
        \\position rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
        \\d
    ;

    var stdin = std.Io.Reader.fixed(input);

    var output: [4096]u8 = undefined;
    var stdout = std.Io.Writer.fixed(&output);

    try interface.loop(allocator, &stdin, &stdout);

    try std.testing.expectStringStartsWith(stdout.buffer,
        \\Command position failed with error error.UnknownPositionArgument, reset to startpos
        \\ +---+---+---+---+---+---+---+---+
        \\ | r | n | b | q | k | b | n | r | 8
        \\ +---+---+---+---+---+---+---+---+
        \\ | p | p | p | p | p | p | p | p | 7
        \\ +---+---+---+---+---+---+---+---+
        \\ |   |   |   |   |   |   |   |   | 6
        \\ +---+---+---+---+---+---+---+---+
        \\ |   |   |   |   |   |   |   |   | 5
        \\ +---+---+---+---+---+---+---+---+
        \\ |   |   |   |   |   |   |   |   | 4
        \\ +---+---+---+---+---+---+---+---+
        \\ |   |   |   |   |   |   |   |   | 3
        \\ +---+---+---+---+---+---+---+---+
        \\ | P | P | P | P | P | P | P | P | 2
        \\ +---+---+---+---+---+---+---+---+
        \\ | R | N | B | Q | K | B | N | R | 1
        \\ +---+---+---+---+---+---+---+---+
        \\   A   B   C   D   E   F   G   H
        \\
        \\White to move
        \\fen: rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
    );
}

test "SearchLeak" {
    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    const input =
        \\position kiwi
        \\eval
        \\go depth 8
    ;

    var stdin = std.Io.Reader.fixed(input);

    var output: [4096]u8 = undefined;
    var stdout = std.Io.Writer.fixed(&output);

    try interface.loop(allocator, &stdin, &stdout);
}

test "SearchLeakNoInterface" {
    var output: [4096]u8 = undefined;
    var stdout = std.Io.Writer.fixed(&output);

    tables.initAll(allocator);
    defer tables.deinitAll(allocator);

    var options: std.StringArrayHashMapUnmanaged(interface.Option) = .empty;
    defer interface.deinitOptions(allocator, &options);
    try interface.initOptions(allocator, &options);

    var s: position.State = position.State{};
    var pos: position.Position = try position.Position.setFen(&s, position.start_fen);
    var move: types.Move = .none;
    var limits = interface.limits;
    limits.depth = 8;
    move = try search.iterativeDeepening(allocator, &stdout, &pos, limits, evaluate.evaluateShannon, options);
    move = try search.iterativeDeepening(allocator, &stdout, &pos, limits, evaluate.evaluateTable, options);
    try stdout.print("bestmove ", .{});
    try move.printUCI(&stdout);
    try stdout.print("\n", .{});
    try pos.moveNull(&s);
}

// test "Bench" {
//     tables.initAll(allocator);
//     defer tables.deinitAll(allocator);

//     const input =
//         \\bench
//     ;

//     var stdin = std.Io.Reader.fixed(input);

//     var output: [131072]u8 = undefined;
//     var stdout = std.Io.Writer.fixed(&output);

//     try interface.loop(allocator, &stdin, &stdout);
// }
