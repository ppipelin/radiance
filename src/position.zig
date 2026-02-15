const std = @import("std");
const tables = @import("tables.zig");
const types = @import("types.zig");

const Bitboard = types.Bitboard;
const Color = types.Color;
const Direction = types.Direction;
const File = types.File;
const GenerationType = types.GenerationType;
const Key = tables.Key;
const Move = types.Move;
const MoveFlags = types.MoveFlags;
const Piece = types.Piece;
const PieceType = types.PieceType;
const Rank = types.Rank;
const Square = types.Square;
const Value = types.Value;

pub const start_fen: []const u8 = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
pub const kiwi_fen: []const u8 = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq -";
pub const lasker_fen: []const u8 = "8/k7/3p4/p2P1p2/P2P1P2/8/8/K7 w - -";

const CastleInfo = enum(u4) {
    none,
    q,
    k,
    kq,
    Q,
    Qq,
    Qk,
    Qkq,
    K,
    Kq,
    Kk,
    Kkq,
    KQ,
    KQq,
    KQk,
    KQkq,

    pub inline fn index(self: CastleInfo) u4 {
        return @intFromEnum(self);
    }

    pub inline fn indexLsb(self: CastleInfo) u2 {
        return @truncate(types.lsb(self.index()));
    }

    pub inline fn relativeCastle(self: CastleInfo, col: Color) CastleInfo {
        return if (col.isWhite()) self else @enumFromInt(self.index() >> 2);
    }
};

pub const State = struct {
    turn: Color = Color.white,
    castle_info: CastleInfo = CastleInfo.none,
    repetition: i7 = 0, // Zero if no repetition, x positive if happened once x half moves ago, negative indicates repetition
    half_move: u8 = 0,
    full_move: u32 = 1,
    en_passant: Square = Square.none,
    checkers: Bitboard = 0,
    pinned: [Color.nb()]Bitboard = .{ 0, 0 },
    attacked: Bitboard = 0,
    attacked_horizontal: Bitboard = 0,
    last_captured_piece: Piece = Piece.none,
    material_key: Key = 0,
    previous: ?*State = null,
};

pub const Position = struct {
    // Board
    board: [types.board_size2]Piece = @splat(.none),

    // Bitboards
    bb_pieces: [PieceType.nb()]Bitboard = @splat(0),
    bb_colors: [Color.nb()]Bitboard = @splat(0),

    // Rook initial positions are recorded for 960
    rook_initial: [4]Square = [_]Square{ Square.none, Square.none, Square.none, Square.none },

    // Score
    score_mg: Value = 0,
    score_eg: Value = 0,
    score_king_w: Value = 0,
    score_king_b: Value = 0,
    score_material_w: Value = 0,
    score_material_b: Value = 0,

    state: *State = undefined,

    pub fn init(noalias state: *State) Position {
        state.* = State{};
        var pos: Position = Position{};

        pos.state = state;

        return pos;
    }

    /// Remove from board and bitboards
    pub inline fn remove(noalias self: *Position, p: Piece, sq: Square) void {
        self.board[sq.index()] = Piece.none;
        const removeFilter: Bitboard = ~sq.sqToBB();
        self.bb_pieces[p.pieceToPieceType().index()] &= removeFilter;
        self.bb_colors[p.pieceToColor().index()] &= removeFilter;

        if (p.pieceToColor().isWhite()) {
            self.score_mg -= tables.psq[p.pieceToPieceType().index()][0][sq.index() ^ 56];
            self.score_eg -= tables.psq[p.pieceToPieceType().index()][1][sq.index() ^ 56];
            self.score_material_w -= tables.material[p.pieceToPieceType().index()];
        } else {
            self.score_mg -= -tables.psq[p.pieceToPieceType().index()][0][sq.index()];
            self.score_eg -= -tables.psq[p.pieceToPieceType().index()][1][sq.index()];
            self.score_material_b -= tables.material[p.pieceToPieceType().index()];
        }
    }

    /// Add to board and bitboards
    pub inline fn add(noalias self: *Position, p: Piece, sq: Square) void {
        self.board[sq.index()] = p;
        const addFilter: Bitboard = sq.sqToBB();
        self.bb_pieces[p.pieceToPieceType().index()] |= addFilter;
        self.bb_colors[p.pieceToColor().index()] |= addFilter;

        if (p.pieceToColor().isWhite()) {
            self.score_mg += tables.psq[p.pieceToPieceType().index()][0][sq.index() ^ 56];
            self.score_eg += tables.psq[p.pieceToPieceType().index()][1][sq.index() ^ 56];
            self.score_material_w += tables.material[p.pieceToPieceType().index()];
            if (p.pieceToPieceType() == PieceType.king) {
                self.score_king_w = tables.psq[p.pieceToPieceType().index()][1][sq.index() ^ 56];
            }
        } else {
            self.score_mg += -tables.psq[p.pieceToPieceType().index()][0][sq.index()];
            self.score_eg += -tables.psq[p.pieceToPieceType().index()][1][sq.index()];
            self.score_material_b += tables.material[p.pieceToPieceType().index()];
            if (p.pieceToPieceType() == PieceType.king) {
                self.score_king_b = tables.psq[p.pieceToPieceType().index()][1][sq.index()];
            }
        }
    }

    inline fn removeAdd(noalias self: *Position, p: Piece, removeSq: Square, addSq: Square) void {
        if (removeSq == addSq)
            return;
        self.board[removeSq.index()] = Piece.none;
        self.board[addSq.index()] = p;
        const removeFilter: Bitboard = removeSq.sqToBB() | addSq.sqToBB();
        self.bb_pieces[p.pieceToPieceType().index()] ^= removeFilter;
        self.bb_colors[p.pieceToColor().index()] ^= removeFilter;

        // self.score_material unchanged
        if (p.pieceToColor().isWhite()) {
            self.score_mg -= tables.psq[p.pieceToPieceType().index()][0][removeSq.index() ^ 56];
            self.score_eg -= tables.psq[p.pieceToPieceType().index()][1][removeSq.index() ^ 56];
            self.score_mg += tables.psq[p.pieceToPieceType().index()][0][addSq.index() ^ 56];
            self.score_eg += tables.psq[p.pieceToPieceType().index()][1][addSq.index() ^ 56];
        } else {
            self.score_mg -= -tables.psq[p.pieceToPieceType().index()][0][removeSq.index()];
            self.score_eg -= -tables.psq[p.pieceToPieceType().index()][1][removeSq.index()];
            self.score_mg += -tables.psq[p.pieceToPieceType().index()][0][addSq.index()];
            self.score_eg += -tables.psq[p.pieceToPieceType().index()][1][addSq.index()];
        }
    }

    pub fn movePiece(noalias self: *Position, move: Move, noalias state: *State) !void {
        // Reset data and set as previous
        state.turn = self.state.turn;
        state.castle_info = self.state.castle_info;
        // Increment ply counters. In particular, half_move will be reset to zero later on in case of a capture or a pawn move.
        state.half_move = self.state.half_move + 1;
        state.full_move = self.state.full_move;
        state.en_passant = Square.none;
        state.checkers = self.state.checkers;
        state.pinned = self.state.pinned;
        state.last_captured_piece = Piece.none;
        state.material_key = self.state.material_key;
        state.previous = self.state;
        self.state = state;

        const from: Square = move.getFrom();
        var to: Square = move.getTo();
        var from_piece: Piece = self.board[from.index()];
        var to_piece: Piece = self.board[to.index()];

        if (from_piece == Piece.none) {
            return error.MoveNone;
        }

        // Remove last en_passant
        if (self.state.previous != null and self.state.previous.?.en_passant != Square.none) {
            self.state.material_key ^= tables.hash_en_passant[self.state.previous.?.en_passant.file().index()];
        }

        switch (from_piece.pieceToPieceType()) {
            // Disable castle if king/rook is moved
            PieceType.king => {
                if (from_piece.pieceToColor().isWhite()) {
                    self.state.castle_info = @enumFromInt(self.state.castle_info.index() & ~CastleInfo.KQ.index());
                    if (self.state.previous != null and self.state.previous.?.castle_info.index() & CastleInfo.K.index() > 0)
                        self.state.material_key ^= tables.hash_castling[CastleInfo.K.indexLsb()];
                    if (self.state.previous != null and self.state.previous.?.castle_info.index() & CastleInfo.Q.index() > 0)
                        self.state.material_key ^= tables.hash_castling[CastleInfo.Q.indexLsb()];
                } else {
                    self.state.castle_info = @enumFromInt(self.state.castle_info.index() & ~CastleInfo.kq.index());
                    if (self.state.previous != null and self.state.previous.?.castle_info.index() & CastleInfo.k.index() > 0)
                        self.state.material_key ^= tables.hash_castling[CastleInfo.k.indexLsb()];
                    if (self.state.previous != null and self.state.previous.?.castle_info.index() & CastleInfo.q.index() > 0)
                        self.state.material_key ^= tables.hash_castling[CastleInfo.q.indexLsb()];
                }
            },
            PieceType.rook => {
                const col: Color = from_piece.pieceToColor();
                if (move.getFrom() == self.rook_initial[0] and (self.state.castle_info.index() & CastleInfo.Q.index()) > 0) {
                    self.state.castle_info = @enumFromInt(self.state.castle_info.index() & ~CastleInfo.Q.index());
                    self.state.material_key ^= tables.hash_castling[CastleInfo.Q.relativeCastle(col).indexLsb()];
                } else if (move.getFrom() == self.rook_initial[1] and (self.state.castle_info.index() & CastleInfo.K.index()) > 0) {
                    self.state.castle_info = @enumFromInt(self.state.castle_info.index() & ~CastleInfo.K.index());
                    self.state.material_key ^= tables.hash_castling[CastleInfo.K.relativeCastle(col).indexLsb()];
                } else if (move.getFrom() == self.rook_initial[2] and (self.state.castle_info.index() & CastleInfo.q.index()) > 0) {
                    self.state.castle_info = @enumFromInt(self.state.castle_info.index() & ~CastleInfo.q.index());
                    self.state.material_key ^= tables.hash_castling[CastleInfo.q.relativeCastle(col).indexLsb()];
                } else if (move.getFrom() == self.rook_initial[3] and (self.state.castle_info.index() & CastleInfo.k.index()) > 0) {
                    self.state.castle_info = @enumFromInt(self.state.castle_info.index() & ~CastleInfo.k.index());
                    self.state.material_key ^= tables.hash_castling[CastleInfo.k.relativeCastle(col).indexLsb()];
                }
            },
            PieceType.pawn => {
                std.debug.assert(move.isPromotion() or (!move.isPromotion() and move.getTo().rank() != Rank.r8));
                // Updates en_passant if possible next turn
                switch (move.getFlags()) {
                    MoveFlags.double_push => {
                        self.state.en_passant = to.add(if (self.state.turn.isWhite()) Direction.south else Direction.north);
                        self.state.material_key ^= tables.hash_en_passant[self.state.en_passant.file().index()];
                    },
                    MoveFlags.en_passant => {
                        const en_passant_sq: Square = to.add(if (self.state.turn.isWhite()) Direction.south else Direction.north);
                        self.state.last_captured_piece = self.board[en_passant_sq.index()];

                        // Remove
                        self.remove(self.state.last_captured_piece, en_passant_sq);
                        self.state.material_key ^= tables.hash_psq[self.state.last_captured_piece.index()][en_passant_sq.index()];

                        self.board[en_passant_sq.index()] = Piece.none;
                    },
                    else => {},
                }
                if (move.isPromotion()) {
                    from_piece = MoveFlags.promoteType(move.getFlags()).pieceTypeToPiece(self.state.turn);
                    self.remove(PieceType.pawn.pieceTypeToPiece(self.state.turn), from);
                    self.state.material_key ^= tables.hash_psq[PieceType.pawn.pieceTypeToPiece(self.state.turn).index()][from.index()];
                    self.add(from_piece, from);
                    self.state.material_key ^= tables.hash_psq[from_piece.index()][from.index()];
                }
                // Reset rule 50 counter
                self.state.half_move = 0;
            },
            else => {},
        }

        if (move.isCapture() and !move.isEnPassant()) {
            if (to_piece == Piece.none) {
                return error.CaptureNone;
            } else if (to_piece == Piece.w_king or to_piece == Piece.b_king) {
                return error.CaptureKing;
            } else {
                // This should be the quickest to disable castle when rook is taken
                var castleRemove: CastleInfo = CastleInfo.none;

                if (to == self.rook_initial[0]) {
                    castleRemove = CastleInfo.Q;
                } else if (to == self.rook_initial[1]) {
                    castleRemove = CastleInfo.K;
                } else if (to == self.rook_initial[2]) {
                    castleRemove = CastleInfo.q;
                } else if (to == self.rook_initial[3]) {
                    castleRemove = CastleInfo.k;
                }

                if (castleRemove != CastleInfo.none and self.state.castle_info.index() & castleRemove.index() > 0) {
                    self.state.castle_info = @enumFromInt(self.state.castle_info.index() ^ castleRemove.index());
                    self.state.material_key ^= tables.hash_castling[castleRemove.indexLsb()];
                }

                self.state.last_captured_piece = to_piece;

                // Remove captured
                self.remove(to_piece, move.getTo());
                self.state.material_key ^= tables.hash_psq[to_piece.index()][to.index()];

                // Reset rule 50 counter
                self.state.half_move = 0;
            }
        }

        if (move.getFlags() == MoveFlags.oo) {
            to = Square.g1.relativeSquare(self.state.turn); // Needed for 960 UCI
            // Remove rook
            const from_rook: Square = self.rook_initial[1 + @as(usize, self.state.turn.invert().index()) * 2];
            to_piece = self.board[from_rook.index()];
            self.remove(to_piece, from_rook);
            self.state.material_key ^= tables.hash_psq[to_piece.index()][from_rook.index()];
        } else if (move.getFlags() == MoveFlags.ooo) {
            to = Square.c1.relativeSquare(self.state.turn); // Needed for 960 UCI
            // Remove rook
            const from_rook: Square = self.rook_initial[@as(usize, self.state.turn.invert().index()) * 2];
            to_piece = self.board[from_rook.index()];
            self.remove(to_piece, from_rook);
            self.state.material_key ^= tables.hash_psq[to_piece.index()][from_rook.index()];
        }

        // Remove/Add
        self.removeAdd(from_piece, from, to);
        self.state.material_key ^= tables.hash_psq[from_piece.index()][from.index()];
        self.state.material_key ^= tables.hash_psq[from_piece.index()][to.index()];

        if (!self.state.turn.isWhite())
            self.state.full_move += 1;
        self.state.turn = self.state.turn.invert();
        self.state.material_key ^= tables.hash_turn;

        // If castling we move the rook as well
        switch (move.getFlags()) {
            MoveFlags.oo => {
                const sq: Square = Square.f1.relativeSquare(self.state.turn.invert());
                self.add(to_piece, sq);
                self.state.material_key ^= tables.hash_psq[to_piece.index()][sq.index()];
            },
            MoveFlags.ooo => {
                const sq: Square = Square.d1.relativeSquare(self.state.turn.invert());
                self.add(to_piece, sq);
                self.state.material_key ^= tables.hash_psq[to_piece.index()][sq.index()];
            },
            else => {},
        }

        self.state.repetition = 0;
        if (self.state.half_move >= 0 and self.state.previous != null and self.state.previous.?.previous != null) {
            var s2: *State = self.state.previous.?.previous.?;
            var i: i7 = 4;
            while (i <= self.state.half_move and s2.previous != null and s2.previous.?.previous != null) : (i += 2) {
                s2 = s2.previous.?.previous.?;
                if (s2.material_key == self.state.material_key) {
                    self.state.repetition = if (s2.repetition != 0) -i else i;
                    break;
                }
            }
        }

        self.updateCheckersPinned();
    }

    pub fn unMovePiece(noalias self: *Position, move: Move) !void {
        const from: Square = move.getFrom();
        var to: Square = move.getTo();
        var to_piece: Piece = self.board[to.index()];

        if (move.getFlags() == MoveFlags.oo) {
            to = Square.g1.relativeSquare(self.state.turn.invert()); // Needed for 960 UCI
            to_piece = self.board[to.index()];
            self.remove(PieceType.pieceTypeToPiece(PieceType.rook, self.state.turn.invert()), Square.f1.relativeSquare(self.state.turn.invert()));
        } else if (move.getFlags() == MoveFlags.ooo) {
            to = Square.c1.relativeSquare(self.state.turn.invert()); // Needed for 960 UCI
            to_piece = self.board[to.index()];
            self.remove(PieceType.pieceTypeToPiece(PieceType.rook, self.state.turn.invert()), Square.d1.relativeSquare(self.state.turn.invert()));
        }

        // Remove/Add
        self.removeAdd(to_piece, to, from);

        // Was a promotion
        if (move.isPromotion()) {
            // Before delete we store the data we need
            const is_white: bool = to_piece.pieceToColor().isWhite();
            // Remove promoted piece back into pawn (already moved back)
            self.remove(to_piece, from);
            self.add(if (is_white) Piece.w_pawn else Piece.b_pawn, from);
            // to_piece = self.board[from.index()]; // update, may not be needed if we don't need later
        }

        if (self.state.last_captured_piece != Piece.none) {
            var local_to: Square = to;
            // Case where capture was en passant
            if (move.isEnPassant())
                local_to = if (self.state.last_captured_piece.pieceToColor().isWhite()) to.add(Direction.north) else to.add(Direction.south);

            self.add(self.state.last_captured_piece, local_to);
        }

        self.state = self.state.previous.?;

        // If castling we move the rook as well
        if (move.getFlags() == MoveFlags.oo) {
            self.add(PieceType.pieceTypeToPiece(PieceType.rook, self.state.turn), self.rook_initial[1 + @as(usize, self.state.turn.invert().index()) * 2]);
        } else if (move.getFlags() == MoveFlags.ooo) {
            self.add(PieceType.pieceTypeToPiece(PieceType.rook, self.state.turn), self.rook_initial[@as(usize, self.state.turn.invert().index()) * 2]);
        }
    }

    pub fn moveNull(noalias self: *Position, noalias state: *State) !void {
        // Reset data and set as previous
        state.turn = self.state.turn;
        state.castle_info = self.state.castle_info;
        // Increment ply counters. In particular, half_move will be reset to zero later on in case of a capture or a pawn move.
        state.half_move = self.state.half_move + 1;
        state.full_move = self.state.full_move;
        state.en_passant = Square.none;
        state.checkers = self.state.checkers;
        state.pinned = self.state.pinned;
        state.last_captured_piece = Piece.none;
        state.material_key = self.state.material_key;
        state.previous = self.state;
        self.state = state;

        if (self.state.previous != null and self.state.previous.?.en_passant != Square.none) {
            self.state.material_key ^= tables.hash_en_passant[self.state.previous.?.en_passant.file().index()];
        }

        if (!self.state.turn.isWhite())
            self.state.full_move += 1;
        self.state.turn = self.state.turn.invert();
        self.state.material_key ^= tables.hash_turn;

        self.updateCheckersPinned();
    }

    pub fn unMoveNull(noalias self: *Position) !void {
        self.state = self.state.previous.?;
    }

    pub fn updateCheckersPinned(noalias self: *Position) void {
        const bb_us: Bitboard = self.bb_colors[self.state.turn.index()];
        const bb_them: Bitboard = self.bb_colors[self.state.turn.invert().index()];

        const king_us: Square = @enumFromInt(types.lsb(bb_us & self.bb_pieces[PieceType.king.index()]));
        const king_them: Square = @enumFromInt(types.lsb(bb_them & self.bb_pieces[PieceType.king.index()]));

        self.state.pinned = .{ 0, 0 };

        // Compute checkers from non blockables piece types
        // All knights can attack the king the same way a knight would attack form the king's square
        self.state.checkers = switch (self.state.turn) {
            inline else => |turn| tables.getAttacks(.knight, turn.invert(), king_us, 0) & bb_them & self.bb_pieces[PieceType.knight.index()],
        };
        // Same method for pawn, transform the king into a pawn
        self.state.checkers |= tables.pawn_attacks[self.state.turn.index()][king_us.index()] & bb_them & self.bb_pieces[PieceType.pawn.index()];

        // Compute candidate checkers from sliders and pinned pieces, transform the king into a slider
        var candidates: Bitboard = tables.getAttacks(.bishop, .white, king_us, bb_them) & ((self.bb_pieces[PieceType.bishop.index()] | self.bb_pieces[PieceType.queen.index()]) & self.bb_colors[self.state.turn.invert().index()]);
        candidates |= tables.getAttacks(.rook, .white, king_us, bb_them) & ((self.bb_pieces[PieceType.rook.index()] | self.bb_pieces[PieceType.queen.index()]) & self.bb_colors[self.state.turn.invert().index()]);

        while (candidates != 0) {
            const sq: Square = types.popLsb(&candidates);
            const bb_between: Bitboard = tables.squares_between[king_us.index()][sq.index()] & bb_us;

            if (bb_between == 0) {
                // None of our piece between king and slider: check
                self.state.checkers ^= sq.sqToBB();
            } else if ((bb_between & (bb_between - 1)) == 0) {
                // Only one of our piece between king and slider: pinned
                self.state.pinned[self.state.turn.index()] ^= bb_between;
            }
        }

        // Detect pinned for other side
        candidates = tables.getAttacks(.bishop, .white, king_them, bb_us) & ((self.bb_pieces[PieceType.bishop.index()] | self.bb_pieces[PieceType.queen.index()]) & self.bb_colors[self.state.turn.index()]);
        candidates |= tables.getAttacks(.rook, .white, king_them, bb_us) & ((self.bb_pieces[PieceType.rook.index()] | self.bb_pieces[PieceType.queen.index()]) & self.bb_colors[self.state.turn.index()]);

        while (candidates != 0) {
            const sq: Square = types.popLsb(&candidates);
            const bb_between: Bitboard = tables.squares_between[king_them.index()][sq.index()] & bb_them;

            if ((bb_between & (bb_between - 1)) == 0) {
                // Only one of our piece between king and slider: pinned
                self.state.pinned[self.state.turn.invert().index()] ^= bb_between;
            }
        }
    }

    pub fn updateAttacked(noalias self: *Position, comptime is_960: bool) void {
        const bb_us: Bitboard = self.bb_colors[self.state.turn.index()];
        const bb_them: Bitboard = self.bb_colors[self.state.turn.invert().index()];
        const bb_all: Bitboard = bb_us | bb_them;

        const our_king: Square = @enumFromInt(types.lsb(bb_us & self.bb_pieces[PieceType.king.index()]));

        self.state.attacked = 0;
        // If the rook is attacked by a horizontal slider we cannot castle, this can only happen in chess 960
        self.state.attacked_horizontal = 0;

        for (PieceType.list()) |pt| {
            if (pt == PieceType.none)
                continue;
            var from_bb: Bitboard = self.bb_pieces[pt.index()] & bb_them;
            while (from_bb != 0) {
                const from: Square = types.popLsb(&from_bb);

                // Extract the king as it cannot move to a place that it covers
                const blockers: Bitboard = bb_all ^ our_king.sqToBB();

                if (is_960 and from.rank() == our_king.rank() and (pt == PieceType.queen or pt == PieceType.rook)) {
                    const tmp: Bitboard = switch (self.state.turn) {
                        inline else => |turn| tables.getAttacks(.rook, turn.invert(), from, blockers),
                    };
                    self.state.attacked_horizontal |= tmp;
                    self.state.attacked |= tmp;
                    if (pt == PieceType.queen) {
                        self.state.attacked |= switch (self.state.turn) {
                            inline else => |turn| tables.getAttacks(.bishop, turn.invert(), from, blockers),
                        };
                    }
                } else {
                    self.state.attacked |= switch (self.state.turn) {
                        inline else => |turn| switch (pt) {
                            .none => unreachable,
                            inline else => |pt_current| tables.getAttacks(pt_current, turn.invert(), from, blockers),
                        },
                    };
                }
            }
        }
    }

    pub fn generateLegalMoves(noalias self: *Position, comptime gen_type: GenerationType, comptime color: Color, list: []Move, len: *usize, comptime is_960: bool) void {
        const bb_us: Bitboard = self.bb_colors[color.index()];
        const bb_them: Bitboard = self.bb_colors[color.invert().index()];
        const bb_all: Bitboard = bb_us | bb_them;

        const our_king: Square = @enumFromInt(types.lsb(bb_us & self.bb_pieces[PieceType.king.index()]));

        // Pieces that can be taken
        var capture_mask: Bitboard = 0;
        // Squares that can be moved on
        var quiet_mask: Bitboard = 0;

        // Move king
        const to_king: Bitboard = tables.getAttacks(PieceType.king, color, our_king, bb_all) & ~self.state.attacked; // Careful: bb_us not excluded
        if (gen_type == .all or gen_type == .capture)
            Move.generateMove(MoveFlags.capture, our_king, to_king & bb_them, list, len);
        if (gen_type == .all or gen_type == .quiet)
            Move.generateMove(MoveFlags.quiet, our_king, to_king & ~bb_all, list, len);

        // This switch computes masks that allow capture or quiet moves based on check status and pinned pieces moves
        switch (types.popcount(self.state.checkers)) {
            // Double check, we already computed king moves
            2 => {
                return;
            },
            // SingleCheck
            // Only non pinned pieces will be able to move
            1 => {
                var checker_sq: Square = @enumFromInt(types.lsb(self.state.checkers));
                switch (self.board[checker_sq.index()].pieceToPieceType()) {
                    // Can only take or move for pawn and knight
                    PieceType.pawn => {
                        if (gen_type == .all or gen_type == .capture) {
                            // Can be a double_push check
                            if (self.state.en_passant != Square.none) {
                                // Double push check pinned has to be aligned vertically only, so cannot take this checker
                                // e.g. 8/8/8/5k2/4Pp2/8/8/4KR2 b - e3
                                const from_en_passant: Bitboard = tables.pawn_attacks[color.invert().index()][self.state.en_passant.index()];
                                Move.generateMoveFrom(MoveFlags.en_passant, from_en_passant & bb_us & self.bb_pieces[PieceType.pawn.index()] & ~self.state.pinned[self.state.turn.index()], self.state.en_passant, list, len);
                            }

                            var attackers: Bitboard = tables.getAttackers(self.*, color, checker_sq, bb_all) & ~self.state.pinned[self.state.turn.index()];
                            // Can be a promotion
                            if (checker_sq.rank() == Rank.r8.relativeRank(color)) {
                                const attacking_pawns: Bitboard = attackers & self.bb_pieces[PieceType.pawn.index()];
                                Move.generateMoveFromPromotion(MoveFlags.capture, attacking_pawns, checker_sq, list, len);
                                attackers &= ~attacking_pawns;
                            }
                            Move.generateMoveFrom(MoveFlags.capture, attackers, checker_sq, list, len);
                        }
                    },
                    PieceType.knight => {
                        if (gen_type == .all or gen_type == .capture) {
                            // Pinned knight cannot move
                            var attackers: Bitboard = tables.getAttackers(self.*, color, checker_sq, bb_all) & ~self.state.pinned[self.state.turn.index()];
                            // Can be a promotion
                            if (checker_sq.rank() == Rank.r8.relativeRank(color)) {
                                const attacking_pawns: Bitboard = attackers & self.bb_pieces[PieceType.pawn.index()];
                                Move.generateMoveFromPromotion(MoveFlags.capture, attacking_pawns, checker_sq, list, len);
                                attackers &= ~attacking_pawns;
                            }
                            Move.generateMoveFrom(MoveFlags.capture, attackers, checker_sq, list, len);
                        }
                    },
                    // Can block
                    else => {
                        capture_mask = self.state.checkers;
                        quiet_mask = tables.squares_between[our_king.index()][checker_sq.index()];
                    },
                }
            },
            // No check
            // Pinned pieces moves are computed here
            else => {
                capture_mask = bb_them;
                quiet_mask = ~bb_all;

                // Castling
                if (gen_type == .all or gen_type == .quiet) {
                    // Simplified code flow since we know our_king
                    // OO
                    if (self.state.castle_info.index() & CastleInfo.K.relativeCastle(color).index() > 0) {
                        const to_king_oo: Square = Square.g1.relativeSquare(color);
                        const to_rook_oo: Square = Square.f1.relativeSquare(color);
                        const rook_sq: Square = self.rook_initial[1 + 2 * @as(u8, color.invert().index())];
                        const path_king_oo: Bitboard = tables.squares_between[our_king.index()][to_king_oo.index()] | to_king_oo.sqToBB();
                        const path_rook_oo: Bitboard = tables.squares_between[to_rook_oo.index()][rook_sq.index()] | to_rook_oo.sqToBB();
                        if (rook_sq.sqToBB() & self.state.attacked_horizontal == 0 and (path_king_oo | path_rook_oo) & (bb_all & ~rook_sq.sqToBB() & ~our_king.sqToBB()) == 0 and path_king_oo & self.state.attacked == 0) {
                            if (is_960) {
                                list[len.*] = Move.init(MoveFlags.oo, our_king, rook_sq);
                                len.* += 1;
                            } else {
                                list[len.*] = Move.init(MoveFlags.oo, our_king, to_king_oo);
                                len.* += 1;
                            }
                        }
                    }
                    // OOO
                    if (self.state.castle_info.index() & CastleInfo.Q.relativeCastle(color).index() > 0) {
                        const to_king_ooo: Square = Square.c1.relativeSquare(color);
                        const to_rook_ooo: Square = Square.d1.relativeSquare(color);
                        const rook_sq: Square = self.rook_initial[0 + 2 * @as(u8, color.invert().index())];
                        const path_king_ooo: Bitboard = tables.squares_between[our_king.index()][to_king_ooo.index()] | to_king_ooo.sqToBB();
                        const path_rook_ooo: Bitboard = tables.squares_between[to_rook_ooo.index()][rook_sq.index()] | to_rook_ooo.sqToBB();
                        if (rook_sq.sqToBB() & self.state.attacked_horizontal == 0 and (path_king_ooo | path_rook_ooo) & (bb_all & ~rook_sq.sqToBB() & ~our_king.sqToBB()) == 0 and path_king_ooo & self.state.attacked == 0) {
                            if (is_960) {
                                list[len.*] = Move.init(MoveFlags.ooo, our_king, rook_sq);
                                len.* += 1;
                            } else {
                                list[len.*] = Move.init(MoveFlags.ooo, our_king, to_king_ooo);
                                len.* += 1;
                            }
                        }
                    }
                }

                // Pinned pieces and en passant cannot cover a check
                if ((gen_type == .all or gen_type == .capture) and self.state.en_passant != Square.none) {
                    const from_en_passant_: Bitboard = tables.pawn_attacks[color.invert().index()][self.state.en_passant.index()] & bb_us & self.bb_pieces[PieceType.pawn.index()];

                    // En passant can discover a check why de-obstructing an attack on the king
                    // In case of de-obstruction, our pawn cannot be pinned
                    var from_en_passant = from_en_passant_ & ~self.state.pinned[self.state.turn.index()];
                    while (from_en_passant != 0) {
                        const from: Square = types.popLsb(&from_en_passant);
                        // Bitboard after moving the pawn
                        const new_bb_all: Bitboard = bb_all ^ from.sqToBB() ^ self.state.en_passant.sqToBB() ^ self.state.en_passant.add(Direction.south.relativeDir(color)).sqToBB();
                        if (tables.getAttacks(PieceType.bishop, color, our_king, new_bb_all) & bb_them & (self.bb_pieces[PieceType.bishop.index()] | self.bb_pieces[PieceType.queen.index()]) > 0 or tables.getAttacks(PieceType.rook, color, our_king, new_bb_all) & bb_them & (self.bb_pieces[PieceType.rook.index()] | self.bb_pieces[PieceType.queen.index()]) > 0) {} else {
                            list[len.*] = Move.init(MoveFlags.en_passant, from, self.state.en_passant);
                            len.* += 1;
                        }
                    }

                    // En passant pinned
                    // If the king is aligned with the en passant tile, they are only aligned diagonally if pinned
                    // e.g. 8/8/8/6k1/4Pp2/8/8/2B1K3 b - e3
                    Move.generateMoveFrom(MoveFlags.en_passant, from_en_passant_ & self.state.pinned[self.state.turn.index()] & tables.squares_line[our_king.index()][self.state.en_passant.index()], self.state.en_passant, list, len);
                }

                // Pinned knight can't move
                var bb_pinned = self.state.pinned[self.state.turn.index()] & ~self.bb_pieces[PieceType.knight.index()];
                while (bb_pinned != 0) {
                    const from: Square = types.popLsb(&bb_pinned);
                    const pt: PieceType = self.board[from.index()].pieceToPieceType();

                    // Careful: bb_us not excluded
                    var to: Bitboard = switch (pt) {
                        .none => unreachable,
                        inline else => |pt_current| tables.getAttacks(pt_current, color, from, bb_all),
                    };

                    // Only keep moves aligned with king
                    const line: Bitboard = tables.squares_line[from.index()][our_king.index()];
                    to &= line;

                    if (gen_type == .all or gen_type == .capture) {
                        // Can be a promotion
                        if (pt == PieceType.pawn) {
                            const remove_promoted_pawn: Bitboard = to & types.mask_rank[Rank.r8.relativeRank(color).index()] & capture_mask;
                            Move.generateMovePromotion(MoveFlags.capture, from, remove_promoted_pawn, list, len);
                            to &= ~remove_promoted_pawn;
                        }
                        Move.generateMove(MoveFlags.capture, from, to & capture_mask, list, len);
                    }

                    if (gen_type == .all or gen_type == .quiet) {
                        if (pt != PieceType.pawn) {
                            Move.generateMove(MoveFlags.quiet, from, to & quiet_mask, list, len);
                        } else {
                            const pawn_push: Square = from.add(Direction.north.relativeDir(color));
                            // Push, cannot promote if pinned
                            if ((quiet_mask & line & pawn_push.sqToBB()) > 0) {
                                // Double push
                                if (from.rank() == Rank.r2.relativeRank(color) and quiet_mask & from.add(Direction.north_north.relativeDir(color)).sqToBB() > 0) {
                                    list[len.*] = Move.init(MoveFlags.double_push, from, from.add(Direction.north_north.relativeDir(color)));
                                    len.* += 1;
                                }
                                list[len.*] = Move.init(MoveFlags.quiet, from, from.add(Direction.north.relativeDir(color)));
                                len.* += 1;
                            }
                        }
                    }
                }
            },
        }

        // All non pinned moves

        for (PieceType.list()) |pt| {
            if (pt == PieceType.none or pt == PieceType.king)
                continue;

            var from_bb: Bitboard = self.bb_pieces[pt.index()] & bb_us & ~self.state.pinned[self.state.turn.index()];
            while (from_bb != 0) {
                const from: Square = types.popLsb(&from_bb);
                // Careful: bb_us not excluded
                var to: Bitboard =
                    switch (pt) {
                        .none => unreachable,
                        inline else => |pt_current| tables.getAttacks(pt_current, color, from, bb_all),
                    };

                if (gen_type == .all or gen_type == .capture) { // Can be a promotion
                    if (pt == PieceType.pawn) {
                        const remove_promoted_pawn: Bitboard = to & types.mask_rank[Rank.r8.relativeRank(color).index()] & capture_mask;
                        Move.generateMovePromotion(MoveFlags.capture, from, remove_promoted_pawn, list, len);
                        to &= ~remove_promoted_pawn;
                    }

                    Move.generateMove(MoveFlags.capture, from, to & capture_mask, list, len);
                }

                if ((gen_type == .all or gen_type == .quiet) and pt != PieceType.pawn)
                    Move.generateMove(MoveFlags.quiet, from, to & quiet_mask, list, len);
            }
        }

        if (gen_type == .all or gen_type == .quiet) {
            var from_bb: Bitboard = self.bb_pieces[PieceType.pawn.index()] & bb_us & ~self.state.pinned[self.state.turn.index()];
            while (from_bb != 0) {
                const from: Square = types.popLsb(&from_bb);
                const pawn_push: Square = from.add(Direction.north.relativeDir(color));
                // Push
                if (self.board[pawn_push.index()] == Piece.none) {
                    // Can be a promotion
                    if (pawn_push.rank() == Rank.r8.relativeRank(color)) {
                        Move.generateMovePromotion(MoveFlags.quiet, from, quiet_mask & pawn_push.sqToBB(), list, len);
                    } else {
                        // Double push
                        if (from.rank() == Rank.r2.relativeRank(color) and quiet_mask & from.add(Direction.north_north.relativeDir(color)).sqToBB() > 0) {
                            list[len.*] = Move.init(MoveFlags.double_push, from, from.add(Direction.north_north.relativeDir(color)));
                            len.* += 1;
                        }
                        if (quiet_mask & pawn_push.sqToBB() > 0) {
                            list[len.*] = Move.init(MoveFlags.quiet, from, from.add(Direction.north.relativeDir(color)));
                            len.* += 1;
                        }
                    }
                }
            }
        }
    }

    pub fn scoreMoves(self: Position, list: []Move, comptime flag: GenerationType, scores: []Value) void {
        for (list, 0..) |move, i| {
            scores[i] = 0;

            var from_piece: PieceType = self.board[move.getFrom().index()].pieceToPieceType();
            const to_piece: PieceType = self.board[move.getTo().index()].pieceToPieceType();

            if (move.isPromotion()) {
                from_piece = MoveFlags.promoteType(move.getFlags());
            }

            if (flag == .capture or flag == .all and move.isCapture()) {
                if (move.getFlags() != MoveFlags.en_passant) {
                    const capture_delta: Value = tables.material[to_piece.index()] - tables.material[from_piece.index()];
                    scores[i] += capture_delta;
                }
            } else {
                // Castle (bonus and 960 specific cases)
                var castle_bonus: Value = 0;
                if (move.isCastle()) {
                    castle_bonus = 50;
                }
                scores[i] += castle_bonus;

                scores[i] += tables.history[self.state.turn.index()][move.getFromTo()];
            }

            scores[i] += @as(Value, @intFromBool(move.getFrom().sqToBB() & self.state.attacked != 0)) - @as(Value, @intFromBool(move.getTo().sqToBB() & self.state.attacked != 0));
        }
    }

    pub fn endgame(self: Position, col: Color) bool {
        // Compute score based on the endgame condition
        // Once ennemy has less pieces our king attacks the other one
        // King, seven pawns a rook and a bishop
        return (if (col.isWhite()) self.score_material_b else self.score_material_w) <= tables.material[PieceType.king.index()] + 7 * tables.material[PieceType.pawn.index()] + tables.material[PieceType.rook.index()] + tables.material[PieceType.bishop.index()];
    }

    pub fn print(self: Position, writer: *std.Io.Writer) void {
        const line = " +---+---+---+---+---+---+---+---+\n";
        const letters = "   A   B   C   D   E   F   G   H\n";
        var i: i32 = 56;
        while (i >= 0) : (i -= 8) {
            writer.print("{s} ", .{line}) catch unreachable;
            var j: i32 = 0;
            while (j < 8) : (j += 1) {
                writer.print("| {c} ", .{self.board[@intCast(i + j)].value()}) catch unreachable;
            }
            writer.print("| {}\n", .{@divTrunc(i, 8) + 1}) catch unreachable;
        }
        writer.print("{s}", .{line}) catch unreachable;
        writer.print("{s}\n", .{letters}) catch unreachable;

        writer.print("{s} to move\n", .{if (self.state.turn.isWhite()) "White" else "Black"}) catch unreachable;

        var buffer: [90]u8 = undefined;
        const fen = self.getFen(&buffer);

        writer.print("fen: {s}\n", .{fen}) catch unreachable;

        writer.print("zobrist: {}\n", .{self.state.material_key}) catch unreachable;
    }

    pub fn printDebug(self: Position) void {
        var buffer: [512]u8 = undefined;
        const writer = std.debug.lockStderrWriter(&buffer);
        defer std.debug.unlockStderrWriter();
        self.print(writer);
    }

    pub fn printFenDebug(self: Position) void {
        var buffer: [90]u8 = undefined;
        const writer = std.debug.lockStderrWriter(&buffer);
        defer std.debug.unlockStderrWriter();
        const fen = self.getFen(&buffer);
        writer.print("fen: {s}\n", .{fen}) catch unreachable;
    }

    pub fn getFen(noalias self: *const Position, fen: []u8) []u8 {
        std.debug.assert(fen.len >= 90);
        var i: i8 = Square.a8.index();
        var cnt: usize = 0;
        while (i >= 0) : (i -= 8) {
            var blank_counter: u8 = 0;
            var j: i8 = 0;
            while (j < 8) : (j += 1) {
                const p: Piece = self.board[@intCast(i + j)];
                if (p == Piece.none) {
                    blank_counter += 1;
                } else {
                    if (blank_counter != 0) {
                        fen[cnt] = '0' + blank_counter;
                        cnt += 1;
                        blank_counter = 0;
                    }
                    fen[cnt] = p.value();
                    cnt += 1;
                }
            }
            if (blank_counter != 0) {
                fen[cnt] = '0' + blank_counter;
                cnt += 1;
            }
            if (i - 8 >= 0) {
                fen[cnt] = '/';
                cnt += 1;
            }
        }
        fen[cnt] = ' ';
        cnt += 1;
        fen[cnt] = if (self.state.turn.isWhite()) 'w' else 'b';
        cnt += 1;
        fen[cnt] = ' ';
        cnt += 1;
        if (self.state.castle_info == CastleInfo.none) {
            fen[cnt] = '-';
            cnt += 1;
        } else {
            if (self.state.castle_info.index() & CastleInfo.K.index() > 0) {
                fen[cnt] = 'K';
                cnt += 1;
            }
            if (self.state.castle_info.index() & CastleInfo.Q.index() > 0) {
                fen[cnt] = 'Q';
                cnt += 1;
            }
            if (self.state.castle_info.index() & CastleInfo.k.index() > 0) {
                fen[cnt] = 'k';
                cnt += 1;
            }
            if (self.state.castle_info.index() & CastleInfo.q.index() > 0) {
                fen[cnt] = 'q';
                cnt += 1;
            }
        }

        fen[cnt] = ' ';
        cnt += 1;
        if (self.state.en_passant == Square.none) {
            fen[cnt] = '-';
            cnt += 1;
        } else {
            const tmp_str = self.state.en_passant.str();
            for (tmp_str) |c| {
                fen[cnt] = c;
                cnt += 1;
            }
        }

        fen[cnt] = ' ';
        cnt += 1;
        var buffer: [4]u8 = undefined;
        const buffer_size_half: usize = std.fmt.printInt(&buffer, self.state.half_move, 10, .lower, .{});

        @memmove(fen[cnt..(cnt + buffer_size_half)], buffer[0..buffer_size_half]); // maybe not needed [0..buffer_size_half]
        cnt += buffer_size_half;

        fen[cnt] = ' ';
        cnt += 1;
        buffer = undefined;
        const buffer_size_full: usize = std.fmt.printInt(&buffer, self.state.full_move, 10, .lower, .{});

        @memcpy(fen[cnt..(cnt + buffer_size_full)], buffer[0..buffer_size_full]);
        cnt += buffer_size_full;

        return fen[0..cnt];
    }

    // Maybe sq should be a square and use sq.add()
    pub fn setFen(noalias state: *State, fen: []const u8) !Position {
        state.* = State{};
        var pos: Position = Position.init(state);
        var sq: i32 = Square.a8.index();
        var tokens = std.mem.tokenizeScalar(u8, fen, ' ');
        const token = tokens.next() orelse return error.MissingFen;

        const bd: []const u8 = token;

        // Behavior is : take the farthest rook to king for castling
        var passed_king_w: Square = .none;
        var passed_king_b: Square = .none;
        var found_rook_w: bool = false;
        var found_rook_b: bool = false;

        for (bd) |ch| {
            if (std.ascii.isDigit(ch)) {
                sq += @as(i32, ch - '0') * Direction.east.index();
            } else if (ch == '/') {
                sq += Direction.south.index() * 2;
            } else {
                const p: Piece = try Piece.firstIndex(ch);
                pos.add(p, @enumFromInt(sq));
                pos.state.material_key ^= tables.hash_psq[p.index()][@intCast(sq)];

                if (p == Piece.w_king) {
                    passed_king_w = @enumFromInt(sq);
                    found_rook_w = false;
                }
                if (p == Piece.b_king) {
                    passed_king_b = @enumFromInt(sq);
                    found_rook_b = false;
                }
                if (ch == 'R' and (passed_king_w != .none or !found_rook_w)) {
                    pos.rook_initial[@intFromBool(passed_king_w != .none)] = @enumFromInt(sq);
                    found_rook_w = true;
                }
                if (ch == 'r' and (passed_king_b != .none or !found_rook_b)) {
                    pos.rook_initial[2 + @as(usize, @intFromBool(passed_king_b != .none))] = @enumFromInt(sq);
                    found_rook_b = true;
                }
                sq += 1;
            }
        }

        const turn: ?[]const u8 = tokens.next();
        if (turn != null and std.ascii.eqlIgnoreCase(turn.?, "w")) {
            pos.state.turn = Color.white;
            pos.state.material_key ^= tables.hash_turn;
        } else if (turn != null and std.ascii.eqlIgnoreCase(turn.?, "b")) {
            pos.state.turn = Color.black;
        } else {
            return error.UnknownTurn;
        }

        pos.updateCheckersPinned();

        const castle: []const u8 = tokens.next() orelse return pos;
        for (castle) |ch| {
            switch (ch) {
                'K' => {
                    pos.state.castle_info = @enumFromInt(pos.state.castle_info.index() | CastleInfo.K.index());
                    pos.state.material_key ^= tables.hash_castling[CastleInfo.K.indexLsb()];
                },
                'Q' => {
                    pos.state.castle_info = @enumFromInt(pos.state.castle_info.index() | CastleInfo.Q.index());
                    pos.state.material_key ^= tables.hash_castling[CastleInfo.Q.indexLsb()];
                },
                'k' => {
                    pos.state.castle_info = @enumFromInt(pos.state.castle_info.index() | CastleInfo.k.index());
                    pos.state.material_key ^= tables.hash_castling[CastleInfo.k.indexLsb()];
                },
                'q' => {
                    pos.state.castle_info = @enumFromInt(pos.state.castle_info.index() | CastleInfo.q.index());
                    pos.state.material_key ^= tables.hash_castling[CastleInfo.q.indexLsb()];
                },
                '-' => {
                    pos.state.castle_info = CastleInfo.none;
                },
                else => {
                    // Shredder-FEN support
                    if (ch >= 65 and ch <= 72) {
                        if (ch - 65 > passed_king_w.file().index()) {
                            pos.state.castle_info = @enumFromInt(pos.state.castle_info.index() | CastleInfo.K.index());
                            pos.state.material_key ^= tables.hash_castling[CastleInfo.K.indexLsb()];
                        } else {
                            pos.state.castle_info = @enumFromInt(pos.state.castle_info.index() | CastleInfo.Q.index());
                            pos.state.material_key ^= tables.hash_castling[CastleInfo.Q.indexLsb()];
                        }
                    } else if (ch >= 97 and ch <= 104) {
                        if (ch - 97 > passed_king_w.file().index()) {
                            pos.state.castle_info = @enumFromInt(pos.state.castle_info.index() | CastleInfo.k.index());
                            pos.state.material_key ^= tables.hash_castling[CastleInfo.k.indexLsb()];
                        } else {
                            pos.state.castle_info = @enumFromInt(pos.state.castle_info.index() | CastleInfo.q.index());
                            pos.state.material_key ^= tables.hash_castling[CastleInfo.q.indexLsb()];
                        }
                    } else {
                        return error.UnknownCastle;
                    }
                },
            }
        }

        const ep: []const u8 = tokens.next() orelse return pos;
        if (ep.len == 2) {
            for (types.square_to_str, 0..) |sq_str, i| {
                if (std.ascii.eqlIgnoreCase(ep, sq_str)) {
                    const sq_ep: Square = @enumFromInt(i);
                    pos.state.en_passant = sq_ep;
                    pos.state.material_key ^= tables.hash_en_passant[sq_ep.file().index()];
                    break;
                }
            }
        }

        const half_move: []const u8 = tokens.next() orelse return pos;
        pos.state.half_move = try std.fmt.parseInt(u8, half_move, 10);

        const full_move: []const u8 = tokens.next() orelse return pos;
        pos.state.full_move = try std.fmt.parseInt(u32, full_move, 10);

        return pos;
    }
};

pub fn orderMoves(moves: []Move, scores: []Value) void {
    if (moves.len <= 1)
        return;

    std.sort.pdqContext(0, moves.len, Move.MoveSortContext{ .items = moves, .scores = scores });
}
