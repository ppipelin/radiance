const interface = @import("interface.zig");
const std = @import("std");
const tables = @import("tables.zig");

test "start_fen" {
    tables.initAll(std.testing.allocator);
    defer tables.deinitAll(std.testing.allocator);

    const input =
        \\position startpos
        \\d
    ;

    var fbs_r = std.io.fixedBufferStream(input);
    var stdin = fbs_r.reader();

    var output: [4096]u8 = undefined;
    var fbs_w = std.io.fixedBufferStream(&output);
    var stdout = fbs_w.writer();

    try interface.loop(std.testing.allocator, &stdin, &stdout);

    try std.testing.expectStringStartsWith(fbs_w.getWritten(),
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
    tables.initAll(std.testing.allocator);
    defer tables.deinitAll(std.testing.allocator);

    const input =
        \\position fen r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq -
        \\d
    ;

    var fbs_r = std.io.fixedBufferStream(input);
    var stdin = fbs_r.reader();

    var output: [4096]u8 = undefined;
    var fbs_w = std.io.fixedBufferStream(&output);
    var stdout = fbs_w.writer();

    try interface.loop(std.testing.allocator, &stdin, &stdout);

    try std.testing.expectStringStartsWith(fbs_w.getWritten(),
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
    tables.initAll(std.testing.allocator);
    defer tables.deinitAll(std.testing.allocator);

    const input =
        \\    position     startpos
        \\d
    ;

    var fbs_r = std.io.fixedBufferStream(input);
    var stdin = fbs_r.reader();

    var output: [4096]u8 = undefined;
    var fbs_w = std.io.fixedBufferStream(&output);
    var stdout = fbs_w.writer();

    try interface.loop(std.testing.allocator, &stdin, &stdout);

    try std.testing.expectStringStartsWith(fbs_w.getWritten(),
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
    tables.initAll(std.testing.allocator);
    defer tables.deinitAll(std.testing.allocator);

    const input =
        \\position fen kiwi
        \\d
    ;

    var fbs_r = std.io.fixedBufferStream(input);
    var stdin = fbs_r.reader();

    var output: [4096]u8 = undefined;
    var fbs_w = std.io.fixedBufferStream(&output);
    var stdout = fbs_w.writer();

    try interface.loop(std.testing.allocator, &stdin, &stdout);

    try std.testing.expectStringStartsWith(fbs_w.getWritten(),
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
    tables.initAll(std.testing.allocator);
    defer tables.deinitAll(std.testing.allocator);

    const input =
        \\position rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
        \\d
    ;

    var fbs_r = std.io.fixedBufferStream(input);
    var stdin = fbs_r.reader();

    var output: [4096]u8 = undefined;
    var fbs_w = std.io.fixedBufferStream(&output);
    var stdout = fbs_w.writer();

    try interface.loop(std.testing.allocator, &stdin, &stdout);

    try std.testing.expectStringStartsWith(fbs_w.getWritten(),
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
