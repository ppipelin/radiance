const std = @import("std");
const tables = @import("tables.zig");
const types = @import("types.zig");

const Bitboard = types.Bitboard;
const Color = types.Color;
const Direction = types.Direction;
const File = types.File;
const Move = types.Move;
const MoveFlags = types.MoveFlags;
const Piece = types.Piece;
const PieceType = types.PieceType;
const Rank = types.Rank;
const Square = types.Square;

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
        return @truncate(types.lsb(@intFromEnum(self)));
    }

    pub inline fn relativeCastle(self: CastleInfo, c: Color) CastleInfo {
        return if (c.isWhite()) self else @enumFromInt(self.index() >> 2);
    }
};

pub const State = struct {
    turn: Color = Color.white,
    castle_info: CastleInfo = CastleInfo.none,
    repetition: i7 = 0, // Zero if no repetition, x positive if happened once x half moves ago, negative indicates repetition
    half_move: u8 = 0,
    full_move: u32 = 1,
    en_passant: Square = Square.none,
    checkers: types.Bitboard = 0,
    pinned: types.Bitboard = 0,
    last_captured_piece: Piece = Piece.none,
    material_key: u64 = 0,
    previous: ?*State = null,
};

pub const Position = struct {
    // Board
    board: [types.board_size2]Piece = undefined,

    // Bitboards
    bb_pieces: [PieceType.nb()]Bitboard = undefined,
    bb_colors: [Color.nb()]Bitboard = undefined,

    // Rook initial positions are recorded for 960
    rook_initial: [4]Square = [_]Square{ Square.a1, Square.h1, Square.a8, Square.h8 },

    // Zobrist hash
    zobrist: u64 = 0,

    // Score
    score_mg: types.Value = 0,
    score_eg: types.Value = 0,
    score_king_w: types.Value = 0,
    score_king_b: types.Value = 0,
    score_material_w: types.Value = 0,
    score_material_b: types.Value = 0,

    state: *State = undefined,

    pub fn init(state: *State) Position {
        state.* = State{};
        var pos: Position = Position{};

        @memset(pos.board[0..types.board_size2], Piece.none);
        @memset(pos.bb_pieces[0..PieceType.nb()], 0);
        @memset(pos.bb_colors[0..Color.nb()], 0);
        pos.state = state;

        return pos;
    }

    /// Remove from board and bitboards
    pub inline fn remove(self: *Position, p: Piece, sq: Square) void {
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
    pub inline fn add(self: *Position, p: Piece, sq: Square) void {
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

    inline fn removeAdd(self: *Position, p: Piece, removeSq: Square, addSq: Square) void {
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

    pub fn movePiece(self: *Position, move: Move, state: *State) !void {
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
        const to: Square = move.getTo();
        var from_piece: Piece = self.board[from.index()];
        const to_piece: Piece = self.board[to.index()];

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
                const is_white = col.isWhite();
                if (move.getFrom().file() == File.fh) {
                    if (self.state.castle_info.index() & (if (is_white) CastleInfo.K else CastleInfo.k).index() > 0) {
                        self.state.castle_info = @enumFromInt(self.state.castle_info.index() & ~(if (is_white) CastleInfo.K.index() else CastleInfo.k.index()));
                        self.state.material_key ^= tables.hash_castling[CastleInfo.K.relativeCastle(col).indexLsb()];
                    }
                } else if (move.getFrom().file() == File.fa) {
                    if (self.state.castle_info.index() & (if (is_white) CastleInfo.Q else CastleInfo.q).index() > 0) {
                        self.state.castle_info = @enumFromInt(self.state.castle_info.index() & ~(if (is_white) CastleInfo.Q.index() else CastleInfo.q.index()));
                        self.state.material_key ^= tables.hash_castling[CastleInfo.Q.relativeCastle(col).indexLsb()];
                    }
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
                        self.state.material_key ^= tables.hash_psq[self.state.last_captured_piece.index()][en_passant_sq.file().index()];

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

        // Add
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
                var tmp: State = State{};
                // CHESS 960 BUG
                try self.movePiece(Move.init(MoveFlags.quiet, @enumFromInt(from.index() + 3), @enumFromInt(from.index() + 3 - 2)), &tmp);
                // We have moved, we need to set the turn back
                self.state = state;
                self.state.material_key ^= tables.hash_turn;
            },
            MoveFlags.ooo => {
                var tmp: State = State{};
                // CHESS 960 BUG
                try self.movePiece(Move.init(MoveFlags.quiet, @enumFromInt(from.index() - 4), @enumFromInt(from.index() - 4 + 3)), &tmp);
                // We have moved, we need to set the turn back
                self.state = state;
                self.state.material_key ^= tables.hash_turn;
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
    }

    /// silent will not change self.state
    pub fn unMovePiece(self: *Position, move: Move, silent: bool) !void {
        const from: Square = move.getFrom();
        const to: Square = move.getTo();
        const to_piece: Piece = self.board[to.index()];

        // Remove/Add
        self.removeAdd(to_piece, to, from);

        if (!silent) {
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
        }

        // If castling we move the rook as well
        if (move.getFlags() == MoveFlags.oo) {
            try self.unMovePiece(Move.init(MoveFlags.quiet, @enumFromInt(from.index() + 3), @enumFromInt(from.index() + 3 - 2)), true);
        } else if (move.getFlags() == MoveFlags.ooo) {
            try self.unMovePiece(Move.init(MoveFlags.quiet, @enumFromInt(from.index() - 4), @enumFromInt(from.index() - 4 + 3)), true);
        }
    }

    pub fn moveNull(self: *Position, state: *State) !void {
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
    }

    pub fn unMoveNull(self: *Position) !void {
        self.state = self.state.previous.?;
    }

    pub fn generateLegalMoves(self: *Position, allocator: std.mem.Allocator, color: Color, list: *std.ArrayListUnmanaged(Move)) void {
        const bb_us: Bitboard = self.bb_colors[color.index()];
        const bb_them: Bitboard = self.bb_colors[color.invert().index()];
        const bb_all: Bitboard = bb_us | bb_them;

        const our_king: Square = @enumFromInt(types.lsb(bb_us & self.bb_pieces[PieceType.king.index()]));

        // Pieces that can be taken
        var capture_mask: Bitboard = 0;
        // Squares that can be moved on
        var quiet_mask: Bitboard = 0;
        var attacked: Bitboard = 0;
        self.state.pinned = 0;

        for (std.enums.values(PieceType)) |pt| {
            if (pt == PieceType.none)
                continue;
            var from_bb: Bitboard = self.bb_pieces[pt.index()] & bb_them;
            while (from_bb != 0) {
                const from: Square = types.popLsb(&from_bb);
                // Extract the king as it can't move to a place that it covers
                attacked |= tables.getAttacks(pt, color.invert(), from, bb_all ^ our_king.sqToBB());
            }
        }

        // Compute checkers from non blockables piece types
        // All knights can attack the king the same way a knight would attack form the king's square
        self.state.checkers = tables.getAttacks(PieceType.knight, color.invert(), our_king, 0) & bb_them & self.bb_pieces[PieceType.knight.index()];
        // Same method for pawn, transform the king into a pawn
        self.state.checkers |= tables.pawn_attacks[color.index()][our_king.index()] & bb_them & self.bb_pieces[PieceType.pawn.index()];

        // Compute candidate checkers from sliders and pinned pieces, transform the king into a slider
        var candidates: Bitboard = tables.getAttacks(PieceType.bishop, Color.white, our_king, bb_them) & ((self.bb_pieces[PieceType.bishop.index()] | self.bb_pieces[PieceType.queen.index()]) & self.bb_colors[color.invert().index()]);
        candidates |= tables.getAttacks(PieceType.rook, Color.white, our_king, bb_them) & ((self.bb_pieces[PieceType.rook.index()] | self.bb_pieces[PieceType.queen.index()]) & self.bb_colors[color.invert().index()]);

        while (candidates != 0) {
            const sq: Square = types.popLsb(&candidates);
            const bb_between: Bitboard = tables.squares_between[our_king.index()][sq.index()] & bb_us;

            if (bb_between == 0) {
                // No our piece between king and slider: check
                self.state.checkers ^= sq.sqToBB();
            } else if ((bb_between & (bb_between - 1)) == 0) {
                // Only one of our piece between king and slider: pinned
                self.state.pinned ^= bb_between;
            }
        }

        // Move king
        const to_king: Bitboard = tables.getAttacks(PieceType.king, color, our_king, bb_all) & ~attacked; // Careful: bb_us not excluded
        Move.generateMove(allocator, MoveFlags.capture, our_king, to_king & bb_them, list);
        Move.generateMove(allocator, MoveFlags.quiet, our_king, to_king & ~bb_all, list);

        switch (types.popcount(self.state.checkers)) {
            // Double check, we already computed king moves
            2 => {
                return;
            },
            // SingleCheck
            1 => {
                var checker_sq: Square = @enumFromInt(types.lsb(self.state.checkers));
                switch (self.board[checker_sq.index()].pieceToPieceType()) {
                    // Can only take or move for pawn and knight
                    PieceType.pawn => {
                        // Can be a double_push check
                        if (self.state.en_passant != Square.none) {
                            // Double push check pinned has to be aligned vertically only, so cannot take this checker
                            const from_en_passant: Bitboard = tables.pawn_attacks[color.invert().index()][self.state.en_passant.index()];
                            Move.generateMoveFrom(allocator, MoveFlags.en_passant, from_en_passant & bb_us & self.bb_pieces[PieceType.pawn.index()] & ~self.state.pinned, self.state.en_passant, list);
                        }

                        var attackers: Bitboard = tables.getAttackers(self.*, color, checker_sq, bb_all) & ~self.state.pinned;
                        // Can be a promotion
                        if (checker_sq.rank() == Rank.r8.relativeRank(color)) {
                            const attacking_pawns: Bitboard = attackers & self.bb_pieces[PieceType.pawn.index()];
                            Move.generateMoveFromPromotion(allocator, MoveFlags.capture, attacking_pawns, checker_sq, list);
                            attackers &= ~attacking_pawns;
                        }
                        Move.generateMoveFrom(allocator, MoveFlags.capture, attackers, checker_sq, list);
                    },
                    PieceType.knight => {
                        var attackers: Bitboard = tables.getAttackers(self.*, color, checker_sq, bb_all) & ~self.state.pinned;
                        // Can be a promotion
                        if (checker_sq.rank() == Rank.r8.relativeRank(color)) {
                            const attacking_pawns: Bitboard = attackers & self.bb_pieces[PieceType.pawn.index()];
                            Move.generateMoveFromPromotion(allocator, MoveFlags.capture, attacking_pawns, checker_sq, list);
                            attackers &= ~attacking_pawns;
                        }
                        Move.generateMoveFrom(allocator, MoveFlags.capture, attackers, checker_sq, list);
                    },
                    // Can block
                    else => {
                        capture_mask = self.state.checkers;
                        quiet_mask = tables.squares_between[our_king.index()][checker_sq.index()];
                    },
                }
            },
            // No check
            else => {
                capture_mask = bb_them;
                quiet_mask = ~bb_all;

                // Castling
                // Simplified code flow since we know our_king
                // OO
                if (self.state.castle_info.index() & CastleInfo.K.relativeCastle(color).index() > 0) {
                    const to_king_oo: Square = Square.g1.relativeSquare(color);
                    const path_king_oo: Bitboard = tables.squares_between[our_king.index()][to_king_oo.index()] | to_king_oo.sqToBB();
                    const path_rook_oo: Bitboard = tables.squares_between[our_king.index()][self.rook_initial[1 + 2 * @as(u8, color.invert().index())].index()];
                    if ((path_king_oo | path_rook_oo) & (bb_all & ~self.rook_initial[1 + 2 * @as(u8, color.invert().index())].sqToBB() & ~our_king.sqToBB()) == 0 and path_king_oo & attacked == 0) {
                        list.append(allocator, Move.init(MoveFlags.oo, our_king, to_king_oo)) catch unreachable;
                    }
                }
                // OOO
                if (self.state.castle_info.index() & CastleInfo.Q.relativeCastle(color).index() > 0) {
                    const to_king_ooo: Square = Square.c1.relativeSquare(color);
                    const path_king_ooo: Bitboard = tables.squares_between[our_king.index()][to_king_ooo.index()] | to_king_ooo.sqToBB();
                    const path_rook_ooo: Bitboard = tables.squares_between[our_king.index()][self.rook_initial[0 + 2 * @as(u8, color.invert().index())].index()];
                    if ((path_king_ooo | path_rook_ooo) & (bb_all & ~self.rook_initial[0 + 2 * @as(u8, color.invert().index())].sqToBB() & ~our_king.sqToBB()) == 0 and path_king_ooo & attacked == 0) {
                        list.append(allocator, Move.init(MoveFlags.ooo, our_king, to_king_ooo)) catch unreachable;
                    }
                }

                // Pinned pieces and en passant cannot cover a check
                if (self.state.en_passant != Square.none) {
                    const from_en_passant_: Bitboard = tables.pawn_attacks[color.invert().index()][self.state.en_passant.index()] & bb_us & self.bb_pieces[PieceType.pawn.index()];

                    // En passant can discover a check why de-obstructing an attack on the king
                    // In case of de-obstruction, our pawn cannot be pinned
                    var from_en_passant = from_en_passant_ & ~self.state.pinned;
                    while (from_en_passant != 0) {
                        const from: Square = types.popLsb(&from_en_passant);
                        // Bitboard after moving the pawn
                        const new_bb_all: Bitboard = bb_all ^ from.sqToBB() ^ self.state.en_passant.sqToBB() ^ self.state.en_passant.add(Direction.south.relativeDir(color)).sqToBB();
                        if (tables.getAttacks(PieceType.bishop, color, our_king, new_bb_all) & bb_them & (self.bb_pieces[PieceType.bishop.index()] | self.bb_pieces[PieceType.queen.index()]) > 0 or tables.getAttacks(PieceType.rook, color, our_king, new_bb_all) & bb_them & (self.bb_pieces[PieceType.rook.index()] | self.bb_pieces[PieceType.queen.index()]) > 0) {} else {
                            list.append(allocator, Move.init(MoveFlags.en_passant, from, self.state.en_passant)) catch unreachable;
                        }
                    }

                    // En passant pinned
                    Move.generateMoveFrom(allocator, MoveFlags.en_passant, from_en_passant_ & self.state.pinned & tables.squares_line[our_king.index()][self.state.en_passant.index()], self.state.en_passant, list);
                }

                var bb_pinned = self.state.pinned & ~self.bb_pieces[PieceType.knight.index()];
                while (bb_pinned != 0) {
                    const from: Square = types.popLsb(&bb_pinned);
                    const pt: PieceType = self.board[from.index()].pieceToPieceType();

                    var to: Bitboard = tables.getAttacks(pt, color, from, bb_all); // Careful: bb_us not excluded

                    // Keep moves aligned with king
                    const line: Bitboard = tables.squares_line[from.index()][our_king.index()];
                    to &= line;

                    // Can be a promotion
                    if (pt == PieceType.pawn) {
                        const remove_promoted_pawn: Bitboard = to & types.mask_rank[Rank.r8.relativeRank(color).index()] & capture_mask;
                        Move.generateMovePromotion(allocator, MoveFlags.capture, from, remove_promoted_pawn, list);
                        to &= ~remove_promoted_pawn;
                    }
                    Move.generateMove(allocator, MoveFlags.capture, from, to & capture_mask, list);

                    if (pt != PieceType.pawn) {
                        Move.generateMove(allocator, MoveFlags.quiet, from, to & quiet_mask, list);
                    } else {
                        const pawn_push: Square = from.add(Direction.north.relativeDir(color));
                        // Push, cannot promote if pinned
                        if ((quiet_mask & line & pawn_push.sqToBB()) > 0) {
                            list.append(allocator, Move.init(MoveFlags.quiet, from, from.add(Direction.north.relativeDir(color)))) catch unreachable;
                            // Double push
                            if (from.rank() == Rank.r2.relativeRank(color) and quiet_mask & from.add(Direction.north_north.relativeDir(color)).sqToBB() > 0) {
                                list.append(allocator, Move.init(MoveFlags.double_push, from, from.add(Direction.north_north.relativeDir(color)))) catch unreachable;
                            }
                        }
                    }
                }
            },
        }

        // All non pinned moves

        for (std.enums.values(PieceType)) |pt| {
            if (pt == PieceType.none or pt == PieceType.king)
                continue;

            var from_bb: Bitboard = self.bb_pieces[pt.index()] & bb_us & ~self.state.pinned;
            while (from_bb != 0) {
                const from: Square = types.popLsb(&from_bb);
                var to: Bitboard = tables.getAttacks(pt, color, from, bb_all); // Careful: bb_us not excluded

                // Can be a promotion
                if (pt == PieceType.pawn) {
                    const remove_promoted_pawn: Bitboard = to & types.mask_rank[Rank.r8.relativeRank(color).index()] & capture_mask;
                    Move.generateMovePromotion(allocator, MoveFlags.capture, from, remove_promoted_pawn, list);
                    to &= ~remove_promoted_pawn;
                }

                Move.generateMove(allocator, MoveFlags.capture, from, to & capture_mask, list);
                if (pt != PieceType.pawn)
                    Move.generateMove(allocator, MoveFlags.quiet, from, to & quiet_mask, list);
            }
        }

        var from_bb: Bitboard = self.bb_pieces[PieceType.pawn.index()] & bb_us & ~self.state.pinned;
        while (from_bb != 0) {
            const from: Square = types.popLsb(&from_bb);
            const pawn_push: Square = from.add(Direction.north.relativeDir(color));
            // Push
            if (self.board[pawn_push.index()] == Piece.none) {
                // Can be a promotion
                if (pawn_push.rank() == Rank.r8.relativeRank(color)) {
                    Move.generateMovePromotion(allocator, MoveFlags.quiet, from, quiet_mask & pawn_push.sqToBB(), list);
                } else {
                    if (quiet_mask & pawn_push.sqToBB() > 0)
                        list.append(allocator, Move.init(MoveFlags.quiet, from, from.add(Direction.north.relativeDir(color)))) catch unreachable;
                    // Double push
                    if (from.rank() == Rank.r2.relativeRank(color) and quiet_mask & from.add(Direction.north_north.relativeDir(color)).sqToBB() > 0) {
                        list.append(allocator, Move.init(MoveFlags.double_push, from, from.add(Direction.north_north.relativeDir(color)))) catch unreachable;
                    }
                }
            }
        }
    }

    pub fn generateLegalCaptures(self: *Position, allocator: std.mem.Allocator, color: Color, list: *std.ArrayListUnmanaged(Move)) void {
        const bb_us: Bitboard = self.bb_colors[color.index()];
        const bb_them: Bitboard = self.bb_colors[color.invert().index()];
        const bb_all: Bitboard = bb_us | bb_them;

        const our_king: Square = @enumFromInt(types.lsb(bb_us & self.bb_pieces[PieceType.king.index()]));

        // Pieces that can be taken
        var capture_mask: Bitboard = 0;
        // Squares that can be moved on
        var quiet_mask: Bitboard = 0;
        var attacked: Bitboard = 0;
        self.state.pinned = 0;

        for (std.enums.values(PieceType)) |pt| {
            if (pt == PieceType.none)
                continue;
            var from_bb: Bitboard = self.bb_pieces[pt.index()] & bb_them;
            while (from_bb != 0) {
                const from: Square = types.popLsb(&from_bb);
                // Extract the king as it can't move to a place that it covers
                attacked |= tables.getAttacks(pt, color.invert(), from, bb_all ^ our_king.sqToBB());
            }
        }

        // Compute checkers from non blockables piece types
        // All knights can attack the king the same way a knight would attack form the king's square
        self.state.checkers = tables.getAttacks(PieceType.knight, color.invert(), our_king, 0) & bb_them & self.bb_pieces[PieceType.knight.index()];
        // Same method for pawn, transform the king into a pawn
        self.state.checkers |= tables.pawn_attacks[color.index()][our_king.index()] & bb_them & self.bb_pieces[PieceType.pawn.index()];

        // Compute candidate checkers from sliders and pinned pieces, transform the king into a slider
        var candidates: Bitboard = tables.getAttacks(PieceType.bishop, Color.white, our_king, bb_them) & ((self.bb_pieces[PieceType.bishop.index()] | self.bb_pieces[PieceType.queen.index()]) & self.bb_colors[color.invert().index()]);
        candidates |= tables.getAttacks(PieceType.rook, Color.white, our_king, bb_them) & ((self.bb_pieces[PieceType.rook.index()] | self.bb_pieces[PieceType.queen.index()]) & self.bb_colors[color.invert().index()]);

        while (candidates != 0) {
            const sq: Square = types.popLsb(&candidates);
            const bb_between: Bitboard = tables.squares_between[our_king.index()][sq.index()] & bb_us;

            if (bb_between == 0) {
                // No our piece between king and slider: check
                self.state.checkers ^= sq.sqToBB();
            } else if ((bb_between & (bb_between - 1)) == 0) {
                // Only one of our piece between king and slider: pinned
                self.state.pinned ^= bb_between;
            }
        }

        // Move king
        const to_king: Bitboard = tables.getAttacks(PieceType.king, color, our_king, bb_all) & ~attacked; // Careful: bb_us not excluded
        Move.generateMove(allocator, MoveFlags.capture, our_king, to_king & bb_them, list);

        switch (types.popcount(self.state.checkers)) {
            // Double check, we already computed king moves
            2 => {
                return;
            },
            // SingleCheck
            1 => {
                var checker_sq: Square = @enumFromInt(types.lsb(self.state.checkers));
                switch (self.board[checker_sq.index()].pieceToPieceType()) {
                    // Can only take or move for pawn and knight
                    PieceType.pawn => {
                        // Can be a double_push check
                        if (self.state.en_passant != Square.none) {
                            // Double push check pinned has to be aligned vertically only, so cannot take this checker
                            const from_en_passant: Bitboard = tables.pawn_attacks[color.invert().index()][self.state.en_passant.index()];
                            Move.generateMoveFrom(allocator, MoveFlags.en_passant, from_en_passant & bb_us & self.bb_pieces[PieceType.pawn.index()] & ~self.state.pinned, self.state.en_passant, list);
                        }

                        var attackers: Bitboard = tables.getAttackers(self.*, color, checker_sq, bb_all) & ~self.state.pinned;
                        // Can be a promotion
                        if (checker_sq.rank() == Rank.r8.relativeRank(color)) {
                            const attacking_pawns: Bitboard = attackers & self.bb_pieces[PieceType.pawn.index()];
                            Move.generateMoveFromPromotion(allocator, MoveFlags.capture, attacking_pawns, checker_sq, list);
                            attackers &= ~attacking_pawns;
                        }
                        Move.generateMoveFrom(allocator, MoveFlags.capture, attackers, checker_sq, list);
                    },
                    PieceType.knight => {
                        var attackers: Bitboard = tables.getAttackers(self.*, color, checker_sq, bb_all) & ~self.state.pinned;
                        // Can be a promotion
                        if (checker_sq.rank() == Rank.r8.relativeRank(color)) {
                            const attacking_pawns: Bitboard = attackers & self.bb_pieces[PieceType.pawn.index()];
                            Move.generateMoveFromPromotion(allocator, MoveFlags.capture, attacking_pawns, checker_sq, list);
                            attackers &= ~attacking_pawns;
                        }
                        Move.generateMoveFrom(allocator, MoveFlags.capture, attackers, checker_sq, list);
                    },
                    // Can block
                    else => {
                        capture_mask = self.state.checkers;
                        quiet_mask = tables.squares_between[our_king.index()][checker_sq.index()];
                    },
                }
            },
            // No check
            else => {
                capture_mask = bb_them;
                quiet_mask = ~bb_all;

                // Pinned pieces and en passant cannot cover a check
                if (self.state.en_passant != Square.none) {
                    const from_en_passant_: Bitboard = tables.pawn_attacks[color.invert().index()][self.state.en_passant.index()] & bb_us & self.bb_pieces[PieceType.pawn.index()];

                    // En passant can discover a check why de-obstructing an attack on the king
                    // In case of de-obstruction, our pawn cannot be pinned
                    var from_en_passant = from_en_passant_ & ~self.state.pinned;
                    while (from_en_passant != 0) {
                        const from: Square = types.popLsb(&from_en_passant);
                        // Bitboard after moving the pawn
                        const new_bb_all: Bitboard = bb_all ^ from.sqToBB() ^ self.state.en_passant.sqToBB() ^ self.state.en_passant.add(Direction.south.relativeDir(color)).sqToBB();
                        if (tables.getAttacks(PieceType.bishop, color, our_king, new_bb_all) & bb_them & (self.bb_pieces[PieceType.bishop.index()] | self.bb_pieces[PieceType.queen.index()]) > 0 or tables.getAttacks(PieceType.rook, color, our_king, new_bb_all) & bb_them & (self.bb_pieces[PieceType.rook.index()] | self.bb_pieces[PieceType.queen.index()]) > 0) {} else {
                            list.append(allocator, Move.init(MoveFlags.en_passant, from, self.state.en_passant)) catch unreachable;
                        }
                    }

                    // En passant pinned
                    Move.generateMoveFrom(allocator, MoveFlags.en_passant, from_en_passant_ & self.state.pinned & tables.squares_line[our_king.index()][self.state.en_passant.index()], self.state.en_passant, list);
                }

                var bb_pinned = self.state.pinned & ~self.bb_pieces[PieceType.knight.index()];
                while (bb_pinned != 0) {
                    const from: Square = types.popLsb(&bb_pinned);
                    const pt: PieceType = self.board[from.index()].pieceToPieceType();

                    var to: Bitboard = tables.getAttacks(pt, color, from, bb_all); // Careful: bb_us not excluded

                    // Keep moves aligned with king
                    const line: Bitboard = tables.squares_line[from.index()][our_king.index()];
                    to &= line;

                    // Can be a promotion
                    if (pt == PieceType.pawn) {
                        const remove_promoted_pawn: Bitboard = to & types.mask_rank[Rank.r8.relativeRank(color).index()] & capture_mask;
                        Move.generateMovePromotion(allocator, MoveFlags.capture, from, remove_promoted_pawn, list);
                        to &= ~remove_promoted_pawn;
                    }
                    Move.generateMove(allocator, MoveFlags.capture, from, to & capture_mask, list);
                }
            },
        }

        // All non pinned moves

        for (std.enums.values(PieceType)) |pt| {
            if (pt == PieceType.none or pt == PieceType.king)
                continue;

            var from_bb: Bitboard = self.bb_pieces[pt.index()] & bb_us & ~self.state.pinned;
            while (from_bb != 0) {
                const from: Square = types.popLsb(&from_bb);
                var to: Bitboard = tables.getAttacks(pt, color, from, bb_all); // Careful: bb_us not excluded

                // Can be a promotion
                if (pt == PieceType.pawn) {
                    const remove_promoted_pawn: Bitboard = to & types.mask_rank[Rank.r8.relativeRank(color).index()] & capture_mask;
                    Move.generateMovePromotion(allocator, MoveFlags.capture, from, remove_promoted_pawn, list);
                    to &= ~remove_promoted_pawn;
                }

                Move.generateMove(allocator, MoveFlags.capture, from, to & capture_mask, list);
            }
        }
    }

    pub fn print(self: Position, writer: anytype) void {
        const line = " +---+---+---+---+---+---+---+---+\n";
        const letters = "   A   B   C   D   E   F   G   H\n";
        var i: i32 = 56;
        while (i >= 0) : (i -= 8) {
            writer.print("{s} ", .{line}) catch unreachable;
            var j: i32 = 0;
            while (j < 8) : (j += 1) {
                writer.print("| {c} ", .{@intFromEnum(self.board[@intCast(i + j)])}) catch unreachable;
            }
            writer.print("| {}\n", .{@divTrunc(i, 8) + 1}) catch unreachable;
        }
        writer.print("{s}", .{line}) catch unreachable;
        writer.print("{s}\n", .{letters}) catch unreachable;

        writer.print("{s} to move\n", .{if (self.state.turn.isWhite()) "White" else "Black"}) catch unreachable;

        var buffer: [90]u8 = undefined;
        const fen = self.getFen(&buffer);

        writer.print("fen: {s}\n", .{fen}) catch unreachable;

        writer.print("zobrist: {}\n", .{self.zobrist}) catch unreachable;
    }

    pub fn printDebug(self: Position) void {
        const writer = std.io.getStdErr().writer();
        self.print(writer);
    }

    pub fn getFen(self: *const Position, fen: []u8) []u8 {
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
        var buf = buffer[0..];
        var tmp_str: []u8 = std.fmt.bufPrintIntToSlice(buf, self.state.half_move, 10, .lower, std.fmt.FormatOptions{});

        @memcpy(fen[cnt..(cnt + tmp_str.len)], tmp_str);
        cnt += tmp_str.len;

        fen[cnt] = ' ';
        cnt += 1;
        buffer = undefined;
        buf = buffer[0..];
        tmp_str = std.fmt.bufPrintIntToSlice(buf, self.state.full_move, 10, .lower, std.fmt.FormatOptions{});

        std.mem.copyForwards(u8, fen[cnt..(cnt + tmp_str.len)], tmp_str);
        @memcpy(fen[cnt..(cnt + tmp_str.len)], tmp_str);
        cnt += tmp_str.len;

        return fen[0..cnt];
    }

    // Maybe sq should be a square and use sq.add()
    pub fn setFen(state: *State, fen: []const u8) !Position {
        state.* = State{};
        var pos: Position = Position.init(state);
        var sq: i32 = Square.a8.index();
        var tokens = std.mem.tokenizeScalar(u8, fen, ' ');
        const bd: []const u8 = tokens.next().?;
        var rook_cnt: u8 = 0;
        for (bd) |ch| {
            if (std.ascii.isDigit(ch)) {
                sq += @as(i32, ch - '0') * Direction.east.index();
            } else if (ch == '/') {
                sq += Direction.south.index() * 2;
            } else {
                const p: Piece = try Piece.firstIndex(ch);
                pos.add(p, @enumFromInt(sq));
                pos.state.material_key ^= tables.hash_psq[p.index()][@intCast(sq)];
                if (ch == 'R' and rook_cnt < 2) {
                    pos.rook_initial[rook_cnt] = @enumFromInt(sq);
                    rook_cnt += 1;
                }
                sq += 1;
            }
        }

        const turn: ?[]const u8 = tokens.next();
        if (turn != null and std.mem.eql(u8, turn.?, "w")) {
            pos.state.turn = Color.white;
            pos.state.material_key ^= tables.hash_turn;
        } else if (turn != null and std.mem.eql(u8, turn.?, "b")) {
            pos.state.turn = Color.black;
        } else {
            return error.UnknownTurn;
        }

        const castle: ?[]const u8 = tokens.next();
        if (castle == null)
            return pos;
        for (castle.?) |ch| {
            switch (ch) {
                'K' => {
                    pos.state.castle_info = @enumFromInt(@intFromEnum(pos.state.castle_info) | @intFromEnum(CastleInfo.K));
                    pos.state.material_key ^= tables.hash_castling[CastleInfo.K.indexLsb()];
                },
                'Q' => {
                    pos.state.castle_info = @enumFromInt(@intFromEnum(pos.state.castle_info) | @intFromEnum(CastleInfo.Q));
                    pos.state.material_key ^= tables.hash_castling[CastleInfo.Q.indexLsb()];
                },
                'k' => {
                    pos.state.castle_info = @enumFromInt(@intFromEnum(pos.state.castle_info) | @intFromEnum(CastleInfo.k));
                    pos.state.material_key ^= tables.hash_castling[CastleInfo.k.indexLsb()];
                },
                'q' => {
                    pos.state.castle_info = @enumFromInt(@intFromEnum(pos.state.castle_info) | @intFromEnum(CastleInfo.q));
                    pos.state.material_key ^= tables.hash_castling[CastleInfo.q.indexLsb()];
                },
                '-' => {
                    pos.state.castle_info = CastleInfo.none;
                },
                else => {
                    return error.UnknownCaslte;
                },
            }
        }

        const ep: ?[]const u8 = tokens.next();
        if (ep == null)
            return pos;
        if (ep.?.len == 2) {
            for (types.square_to_str, 0..) |sq_str, i| {
                if (std.mem.eql(u8, ep.?, sq_str)) {
                    const sq_ep: Square = @enumFromInt(i);
                    pos.state.en_passant = sq_ep;
                    pos.state.material_key ^= tables.hash_en_passant[sq_ep.file().index()];
                    break;
                }
            }
        }

        const half_move: ?[]const u8 = tokens.next();
        if (half_move == null)
            return pos;
        pos.state.half_move = try std.fmt.parseInt(u8, half_move.?, 10);

        const full_move: ?[]const u8 = tokens.next();
        if (full_move == null)
            return pos;
        pos.state.full_move = try std.fmt.parseInt(u32, full_move.?, 10);

        return pos;
    }
};
