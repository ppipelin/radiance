//! This module provides functions types for pieces, colors and bitboards related components

const position = @import("position.zig");
const std = @import("std");
const tables = @import("tables.zig");

pub const major = 4;
pub const minor = 0;
pub const patch = 0;

pub fn computeVersion() []const u8 {
    if (minor == 0 and patch == 0) {
        return std.fmt.comptimePrint("{d}", .{major});
    } else if (patch == 0) {
        return std.fmt.comptimePrint("{d}.{d}", .{ major, minor });
    } else {
        return std.fmt.comptimePrint("{d}.{d}.{d}", .{ major, minor, patch });
    }
}

////// Chess //////

pub const board_size: comptime_int = 8;
pub const board_size2 = board_size * board_size;

// zig fmt: off
pub const square_to_str = [_][]const u8{
    "a1", "b1", "c1", "d1", "e1", "f1", "g1", "h1",
    "a2", "b2", "c2", "d2", "e2", "f2", "g2", "h2",
    "a3", "b3", "c3", "d3", "e3", "f3", "g3", "h3",
    "a4", "b4", "c4", "d4", "e4", "f4", "g4", "h4",
    "a5", "b5", "c5", "d5", "e5", "f5", "g5", "h5",
    "a6", "b6", "c6", "d6", "e6", "f6", "g6", "h6",
    "a7", "b7", "c7", "d7", "e7", "f7", "g7", "h7",
    "a8", "b8", "c8", "d8", "e8", "f8", "g8", "h8",
    "none"
};
// zig fmt: on

pub const Square = enum(u8) {
    // zig fmt: off
    a1, b1, c1, d1, e1, f1, g1, h1,
    a2, b2, c2, d2, e2, f2, g2, h2,
    a3, b3, c3, d3, e3, f3, g3, h3,
    a4, b4, c4, d4, e4, f4, g4, h4,
    a5, b5, c5, d5, e5, f5, g5, h5,
    a6, b6, c6, d6, e6, f6, g6, h6,
    a7, b7, c7, d7, e7, f7, g7, h7,
    a8, b8, c8, d8, e8, f8, g8, h8,
    none,
    // zig fmt: on

    pub inline fn inc(self: *Square) *Square {
        self.* = @enumFromInt(@intFromEnum(self.*) + 1);
        return self;
    }

    pub inline fn add(self: Square, d: Direction) Square {
        return @enumFromInt(@intFromEnum(self) + @intFromEnum(d));
    }

    pub inline fn sub(self: Square, d: Direction) Square {
        return @enumFromInt(@intFromEnum(self) - @intFromEnum(d));
    }

    pub inline fn rank(self: Square) Rank {
        return @enumFromInt(@intFromEnum(self) >> 3);
    }

    pub inline fn file(self: Square) File {
        return @enumFromInt(@intFromEnum(self) & 0b111);
    }

    pub inline fn diagonal(self: Square) u4 {
        return 7 + @as(u4, self.rank().index()) - @as(u4, self.file().index());
    }

    pub inline fn antiDiagonal(self: Square) u4 {
        return @as(u4, self.rank().index()) + @as(u4, self.file().index());
    }

    pub inline fn index(self: Square) u8 {
        return @intFromEnum(self);
    }

    pub inline fn relativeSquare(self: Square, c: Color) Square {
        std.debug.assert(self != Square.none);
        if (c.isWhite()) {
            return self;
        } else {
            return @enumFromInt(@as(u8, self.rank().relativeRank(c).index()) * board_size + @as(u8, self.file().index()));
        }
    }

    pub inline fn sqToBB(self: Square) Bitboard {
        const sq: u6 = @truncate(@intFromEnum(self));
        return intToBB(sq);
    }

    pub inline fn intToBB(sq: u6) Bitboard {
        return @shlExact(@as(Bitboard, 1), sq);
    }

    pub inline fn str(self: Square) []const u8 {
        return square_to_str[self.index()];
    }
};

pub const Direction = enum(i32) {
    north = board_size,
    south = -board_size,
    // south = -@intFromEnum(Direction.north),
    east = 1,
    west = -1,
    // west = -@intFromEnum(Direction.east),

    north_east = 9,
    south_east = -7,
    north_west = 7,
    south_west = -9,

    // north_east = @intFromEnum(Direction.north) + @intFromEnum(Direction.east),
    // south_east = @intFromEnum(Direction.south) + @intFromEnum(Direction.east),
    // north_west = @intFromEnum(Direction.north) + @intFromEnum(Direction.west),
    // south_west = @intFromEnum(Direction.south) + @intFromEnum(Direction.west),

    // double push
    north_north = 16,
    south_south = -16,
    // north_north = @intFromEnum(Direction.north) * 2,
    // south_south = @intFromEnum(Direction.south) * 2,

    pub inline fn index(self: Direction) i8 {
        return @intFromEnum(self);
    }

    pub inline fn relativeDir(self: Direction, c: Color) Direction {
        return if (c.isWhite()) self else @enumFromInt(-self.index());
    }
};

pub const File = enum(u3) {
    fa,
    fb,
    fc,
    fd,
    fe,
    ff,
    fg,
    fh,

    pub inline fn index(self: File) u3 {
        return @intFromEnum(self);
    }
};

pub const Rank = enum(u3) {
    r1,
    r2,
    r3,
    r4,
    r5,
    r6,
    r7,
    r8,

    pub inline fn index(self: Rank) u3 {
        return @intFromEnum(self);
    }

    pub inline fn relativeRank(self: Rank, c: Color) Rank {
        return if (c.isWhite()) self else @enumFromInt(Rank.r8.index() - self.index());
    }
};

pub const PieceType = enum(u3) {
    none,
    pawn,
    knight,
    bishop,
    rook,
    queen,
    king,

    pub inline fn nb() comptime_int {
        return 7;
    }

    pub inline fn index(self: PieceType) u3 {
        return @intFromEnum(self);
    }

    pub inline fn isSliding(self: PieceType) bool {
        return self == PieceType.bishop or self == PieceType.rook or self == PieceType.queen;
    }

    pub inline fn isSlidingDiag(self: PieceType) bool {
        return self == PieceType.bishop or self == PieceType.queen;
    }

    pub inline fn isSlidingOrth(self: PieceType) bool {
        return self == PieceType.rook or self == PieceType.queen;
    }

    pub inline fn pieceTypeToPiece(self: PieceType, color: Color) Piece {
        std.debug.assert(self != PieceType.none);
        return switch (self) {
            PieceType.pawn => if (color.isWhite()) Piece.w_pawn else Piece.b_pawn,
            PieceType.knight => if (color.isWhite()) Piece.w_knight else Piece.b_knight,
            PieceType.bishop => if (color.isWhite()) Piece.w_bishop else Piece.b_bishop,
            PieceType.rook => if (color.isWhite()) Piece.w_rook else Piece.b_rook,
            PieceType.queen => if (color.isWhite()) Piece.w_queen else Piece.b_queen,
            PieceType.king => if (color.isWhite()) Piece.w_king else Piece.b_king,
            else => Piece.none,
        };
    }
};

pub const Piece = enum(u8) {
    none = ' ',
    b_pawn = 'p',
    b_knight = 'n',
    b_bishop = 'b',
    b_rook = 'r',
    b_queen = 'q',
    b_king = 'k',
    w_pawn = 'P',
    w_knight = 'N',
    w_bishop = 'B',
    w_rook = 'R',
    w_queen = 'Q',
    w_king = 'K',

    pub inline fn nb() comptime_int {
        return 13;
    }

    pub inline fn index(self: Piece) u8 {
        return switch (self) {
            .none => 0,
            .b_pawn => 1,
            .b_knight => 2,
            .b_bishop => 3,
            .b_rook => 4,
            .b_queen => 5,
            .b_king => 6,
            .w_pawn => 7,
            .w_knight => 8,
            .w_bishop => 9,
            .w_rook => 10,
            .w_queen => 11,
            .w_king => 12,
        };
    }

    pub inline fn value(self: Piece) u8 {
        return @intFromEnum(self);
    }

    pub inline fn pieceToPieceType(self: Piece) PieceType {
        return switch (self) {
            Piece.b_pawn, Piece.w_pawn => PieceType.pawn,
            Piece.b_knight, Piece.w_knight => PieceType.knight,
            Piece.b_bishop, Piece.w_bishop => PieceType.bishop,
            Piece.b_rook, Piece.w_rook => PieceType.rook,
            Piece.b_queen, Piece.w_queen => PieceType.queen,
            Piece.b_king, Piece.w_king => PieceType.king,
            else => PieceType.none,
        };
    }

    pub inline fn pieceToColor(self: Piece) Color {
        std.debug.assert(self != Piece.none);
        return @enumFromInt(@intFromBool(self.value() < 'a'));
    }

    /// Find char c in arr
    pub inline fn firstIndex(c: u8) !Piece {
        for (std.enums.values(Piece)) |i| {
            if (i.value() == c) {
                return i;
            }
        }
        return error.UnknownPiece;
    }
};

pub const Color = enum(u1) {
    black,
    white,

    pub inline fn nb() comptime_int {
        return 2;
    }

    pub inline fn index(self: Color) u1 {
        return @intFromEnum(self);
    }

    pub inline fn invert(self: Color) Color {
        return @enumFromInt(@intFromEnum(self) ^ 1);
    }

    pub inline fn isWhite(self: Color) bool {
        return self == Color.white;
    }
};

/// Chess move described like in https://www.chessprogramming.org/Encoding_Moves
// Packed Struct makes it fit into a 16-bit integer.
pub const Move = packed struct {
    flags: u4 = MoveFlags.quiet.index(),
    from: u6,
    to: u6,

    /// A none Move
    pub const none: Move = .{
        .from = 0,
        .to = 0,
    };

    pub inline fn init(flags: MoveFlags, from: Square, to: Square) Move {
        return Move{ .flags = flags.index(), .from = @truncate(from.index()), .to = @truncate(to.index()) };
    }

    pub inline fn initFromStr(pos: position.Position, str: []const u8) !Move {
        if ((str[0] - 'a' >= board_size or str[1] - '1' >= board_size or str[2] - 'a' >= board_size or str[3] - '1' >= board_size))
            return error.MoveBeyondBoard;

        var from: Square = @enumFromInt((str[0] - 'a') + (str[1] - '1') * board_size);
        var to: Square = @enumFromInt((str[2] - 'a') + (str[3] - '1') * board_size);
        const from_piece: Piece = pos.board[from.index()];
        const to_piece: Piece = pos.board[to.index()];

        var flags: u4 = 0;
        if (to_piece != Piece.none)
            flags |= MoveFlags.capture.index();

        if (str.len == 5) {
            // The promotion piece character must be lowercased
            const c: u8 = std.ascii.toLower(str[4]);
            flags |= 0b1000;
            switch (c) {
                'n' => flags |= 0x0,
                'b' => flags |= 0x1,
                'r' => flags |= 0x2,
                'q' => flags |= 0x3,
                else => return error.UnknownPromotion,
            }
        }

        // In Chess960, castling is still indicated using the standard UCI move format
        // (e.g., e1g1 for kingside castling or e1c1 for queenside castling)
        if (from_piece.pieceToPieceType() == PieceType.king) {
            if (from == Square.e1.relativeSquare(pos.state.turn) and to == Square.g1.relativeSquare(pos.state.turn)) {
                flags = MoveFlags.oo.index();
            } else if (from == Square.e1.relativeSquare(pos.state.turn) and to == Square.c1.relativeSquare(pos.state.turn)) {
                flags = MoveFlags.ooo.index();
            }
        } else if (from_piece.pieceToPieceType() == PieceType.pawn) {
            if (from.file() != to.file()) {
                if (to_piece == Piece.none) {
                    flags |= MoveFlags.en_passant.index();
                }
            } else if (@abs(@as(i16, from.index()) - @as(i16, to.index())) == board_size * 2) {
                flags = MoveFlags.double_push.index();
            }
        }

        return Move.init(@enumFromInt(flags), from, to);
    }

    pub inline fn getFlags(self: Move) MoveFlags {
        return @enumFromInt(self.flags);
    }

    pub inline fn getFrom(self: Move) Square {
        return @enumFromInt(self.from);
    }

    pub inline fn getTo(self: Move) Square {
        return @enumFromInt(self.to);
    }

    pub inline fn isCastle(self: Move) bool {
        return self.flags ^ 0x2 <= 1;
    }

    pub inline fn isCapture(self: Move) bool {
        return (self.flags == 4) or (self.flags == 5) or (self.flags >= 12 and self.flags <= 15);
    }

    pub inline fn isEnPassant(self: Move) bool {
        return self.flags == 5;
    }

    pub inline fn isPromotion(self: Move) bool {
        return (self.flags >> 3) > 0;
    }

    pub inline fn equalsTo(self: Move, other: Move) bool {
        return self.from == other.from and self.to == other.to;
    }

    pub inline fn generateMove(allocator: std.mem.Allocator, comptime flag: MoveFlags, from: Square, to_: Bitboard, list: *std.ArrayListUnmanaged(Move)) void {
        var to: Bitboard = to_;
        // Only Square.none is out of u6
        while (to != 0) {
            list.append(allocator, Move.init(flag, from, popLsb(&to))) catch unreachable;
        }
    }

    pub inline fn generateMovePromotion(allocator: std.mem.Allocator, comptime flag: MoveFlags, from: Square, to_: Bitboard, list: *std.ArrayListUnmanaged(Move)) void {
        var to = to_;
        // Only Square.none is out of u6
        while (to != 0) {
            const sq: Square = popLsb(&to);
            if (flag == MoveFlags.capture) {
                list.append(allocator, Move.init(MoveFlags.prc_knight, from, sq)) catch unreachable;
                list.append(allocator, Move.init(MoveFlags.prc_bishop, from, sq)) catch unreachable;
                list.append(allocator, Move.init(MoveFlags.prc_rook, from, sq)) catch unreachable;
                list.append(allocator, Move.init(MoveFlags.prc_queen, from, sq)) catch unreachable;
            } else {
                list.append(allocator, Move.init(MoveFlags.pr_knight, from, sq)) catch unreachable;
                list.append(allocator, Move.init(MoveFlags.pr_bishop, from, sq)) catch unreachable;
                list.append(allocator, Move.init(MoveFlags.pr_rook, from, sq)) catch unreachable;
                list.append(allocator, Move.init(MoveFlags.pr_queen, from, sq)) catch unreachable;
            }
        }
    }

    pub inline fn generateMoveFrom(allocator: std.mem.Allocator, comptime flag: MoveFlags, from_: Bitboard, to: Square, list: *std.ArrayListUnmanaged(Move)) void {
        var from: Bitboard = from_;
        // Only Square.none is out of u6
        while (from != 0) {
            list.append(allocator, Move.init(flag, popLsb(&from), to)) catch unreachable;
        }
    }

    pub inline fn generateMoveFromPromotion(allocator: std.mem.Allocator, comptime flag: MoveFlags, from_: Bitboard, to: Square, list: *std.ArrayListUnmanaged(Move)) void {
        var from: Bitboard = from_;
        // Only Square.none is out of u6
        while (from != 0) {
            const sq: Square = popLsb(&from);
            if (flag == MoveFlags.capture) {
                list.append(allocator, Move.init(MoveFlags.prc_knight, sq, to)) catch unreachable;
                list.append(allocator, Move.init(MoveFlags.prc_bishop, sq, to)) catch unreachable;
                list.append(allocator, Move.init(MoveFlags.prc_rook, sq, to)) catch unreachable;
                list.append(allocator, Move.init(MoveFlags.prc_queen, sq, to)) catch unreachable;
            } else {
                list.append(allocator, Move.init(MoveFlags.pr_knight, sq, to)) catch unreachable;
                list.append(allocator, Move.init(MoveFlags.pr_bishop, sq, to)) catch unreachable;
                list.append(allocator, Move.init(MoveFlags.pr_rook, sq, to)) catch unreachable;
                list.append(allocator, Move.init(MoveFlags.pr_queen, sq, to)) catch unreachable;
            }
        }
    }

    pub inline fn displayMoves(writer: anytype, list: std.ArrayListUnmanaged(Move)) !void {
        writer.print("Number of moves: {d}\n", .{list.items.len}) catch unreachable;
        for (list.items) |item| {
            try item.printUCI(writer);
            writer.print(", {}\n", .{item.getFlags()}) catch unreachable;
        }
    }

    pub fn printUCI(self: Move, writer: anytype) !void {
        try writer.print("{s}{s}", .{ self.getFrom().str(), self.getTo().str() });
        if (self.isPromotion()) {
            try writer.print("{c}", .{prom_move_type_string[self.flags][0]});
        }
    }

    pub fn printUCIDebug(self: Move) void {
        const writer = std.io.getStdErr().writer();
        self.printUCI(writer) catch unreachable;
    }
};

pub const prom_move_type_string = [_][]const u8{ "", "", "", "", "", "", "", "", "n", "b", "r", "q", "n", "b", "r", "q" };

pub const MoveFlags = enum(u4) {
    quiet = 0b0000,
    double_push = 0b0001,
    oo = 0b0010,
    ooo = 0b0011,
    capture = 0b0100,
    en_passant = 0b0101,
    pr_knight = 0b1000,
    pr_bishop = 0b1001,
    pr_rook = 0b1010,
    pr_queen = 0b1011,
    prc_knight = 0b1100,
    prc_bishop = 0b1101,
    prc_rook = 0b1110,
    prc_queen = 0b1111,

    pub inline fn promoteType(self: MoveFlags) PieceType {
        std.debug.assert(self.index() >= 8);
        return switch (self) {
            MoveFlags.pr_knight, MoveFlags.prc_knight => PieceType.knight,
            MoveFlags.pr_bishop, MoveFlags.prc_bishop => PieceType.bishop,
            MoveFlags.pr_rook, MoveFlags.prc_rook => PieceType.rook,
            MoveFlags.pr_queen, MoveFlags.prc_queen => PieceType.queen,
            else => PieceType.none,
        };
    }

    pub inline fn index(self: MoveFlags) u4 {
        return @intFromEnum(self);
    }
};

pub const Value = i16;

pub const max_moves = 218;

pub const value_zero: Value = 0;
pub const value_draw: Value = 0;
pub const value_stalemate: Value = 0;

pub const value_mate: Value = 32000;
pub const value_infinite: Value = value_mate + 1;
pub const value_none: Value = value_mate + 2;

////// Interface //////

pub const TimePoint = i64; // A value in milliseconds

pub inline fn now() TimePoint {
    return std.time.milliTimestamp();
}

////// Bitboard //////

pub const Bitboard = u64;

pub const file: Bitboard = 0x0101010101010101; // A file
pub const rank: Bitboard = 0xFF; // First rank
pub const diagonal_clockwise: Bitboard = 0b1000000001000000001000000001000000001000000001000000001000000001;
pub const diagonal_counter_clockwise: Bitboard = 0b0000000100000010000001000000100000010000001000000100000010000000;

pub const mask_file = [_]Bitboard{ file, file << 1, file << 2, file << 3, file << 4, file << 5, file << 6, file << 7 };
pub const mask_rank = [_]Bitboard{ rank, rank << board_size * 1, rank << board_size * 2, rank << board_size * 3, rank << board_size * 4, rank << board_size * 5, rank << board_size * 6, rank << board_size * 7 };

pub const mask_diagonal = [_]Bitboard{
    0x80,               0x8040,             0x804020,
    0x80402010,         0x8040201008,       0x804020100804,
    0x80402010080402,   0x8040201008040201, 0x4020100804020100,
    0x2010080402010000, 0x1008040201000000, 0x804020100000000,
    0x402010000000000,  0x201000000000000,  0x100000000000000,
};

pub const mask_anti_diagonal = [_]Bitboard{
    0x1,                0x102,              0x10204,
    0x1020408,          0x102040810,        0x10204081020,
    0x1020408102040,    0x102040810204080,  0x204081020408000,
    0x408102040800000,  0x810204080000000,  0x1020408000000000,
    0x2040800000000000, 0x4080000000000000, 0x8000000000000000,
};

pub fn printBitboardDebug(b: Bitboard) void {
    var i: i32 = board_size2 - board_size;
    while (i >= 0) : (i -= board_size) {
        var j: i32 = 0;
        while (j < board_size) : (j += 1) {
            if ((b >> @intCast(i + j)) & 1 != 0) {
                std.debug.print("1 ", .{});
            } else {
                std.debug.print("0 ", .{});
            }
        }
        std.debug.print("\n", .{});
    }
    std.debug.print("\n", .{});
}

pub inline fn popcount(x: Bitboard) i32 {
    return @intCast(@popCount(x));
}

pub inline fn lsb(x: Bitboard) u7 {
    return @ctz(x);
}

pub inline fn popLsb(x: *Bitboard) Square {
    const l: u7 = lsb(x.*);
    x.* &= x.* - 1;
    return @enumFromInt(l);
}
