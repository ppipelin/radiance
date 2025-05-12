const position = @import("position.zig");
const std = @import("std");
const tables = @import("tables.zig");
const types = @import("types.zig");

/// MovePick struct to allow staged move generation
/// Stages
/// 0. Transposition table init (and 10.)
/// 1. Capture init (and 11.)
/// 2. Remove tt from capture (and 12.)
/// 3. Capture sort (and 13.)
/// 4. Capture return (and 14.)
/// 5. Quiet init
/// 6. Remove tt from quiet
/// 7. Quiet sort
/// 8. Quiet return
/// 9. return `Move.none`
pub const MovePick = struct {
    moves_capture: std.ArrayListUnmanaged(types.Move) = .empty,
    moves_quiet: std.ArrayListUnmanaged(types.Move) = .empty,
    stage: u8 = 0,
    tt_move: types.Move = types.Move.none,
    index_capture: u8 = 0,
    index_quiet: u8 = 0,
    scores: []types.Value = undefined,

    pub fn nextMove(self: *MovePick, allocator: std.mem.Allocator, pos: *position.Position, pv_move: types.Move, is_960: bool) !types.Move {
        if (self.stage == 0 or self.stage == 10) {
            self.stage += 1;

            if (pv_move != types.Move.none) {
                self.tt_move = pv_move;
                return self.tt_move;
            }

            const found: ?std.meta.Tuple(&[_]type{ types.Value, u8, types.Move, types.TableBound }) = tables.transposition_table.get(pos.state.material_key);
            if (found != null) {
                const move: types.Move = found.?[2];
                if (self.stage == 1 or (self.stage == 11 and move.isCapture())) {
                    const from_piece: types.Piece = pos.board[move.getFrom().index()];
                    const to_piece: types.Piece = pos.board[move.getTo().index()];

                    // Guard from collisions
                    // Uncomment for high collision rate
                    // if (from_piece != .none and from_piece.pieceToColor() == pos.state.turn and ((to_piece == .none and (!move.isCapture() or move.isEnPassant())) or (to_piece != .none and move.isCapture() and to_piece.pieceToColor() != pos.state.turn))) {
                    if (from_piece != .none and from_piece.pieceToColor() == pos.state.turn and (to_piece == .none or (move.isCapture() and to_piece.pieceToColor() != pos.state.turn))) {
                        // const attacks: types.Bitboard = tables.getAttacks(from_piece.pieceToPieceType(), pos.state.turn, move.getFrom(), pos.bb_colors[types.Color.white.index()] | pos.bb_colors[types.Color.black.index()]) & ~pos.bb_colors[pos.state.turn.index()];
                        // if (attacks & move.getTo().sqToBB() >= 1) {
                        self.tt_move = move;
                        return move;
                        // }
                    }
                }
            }
        }

        // Capture init
        if (self.stage == 1 or self.stage == 11) {
            pos.updateAttacked();
            pos.generateLegalMoves(allocator, types.GenerationType.capture, pos.state.turn, &self.moves_capture, is_960);
            self.stage += 1;
        }

        // Search for tt
        if (self.stage == 2 or self.stage == 12) {
            self.stage += 1;
            if (self.tt_move != types.Move.none) {
                for (self.moves_capture.items, 0..) |move, i| {
                    if (move == self.tt_move) {
                        _ = self.moves_capture.swapRemove(i);
                        break;
                    }
                }
            }
        }

        // Sort captures
        if (self.stage == 3 or self.stage == 13) {
            self.scores = try allocator.alloc(types.Value, self.moves_capture.items.len);
            pos.scoreMoves(self.moves_capture.items, self.scores);
            position.orderMoves(self.moves_capture.items, self.scores);
            self.stage += 1;
        }

        // Explored all captures, move to next stage
        if ((self.stage == 4 or self.stage == 14) and self.index_capture >= self.moves_capture.items.len) {
            self.stage += 1;
        }

        // Positive captures
        if (self.stage == 4) {
            if (self.scores[self.index_capture] >= tables.max_history) {
                const move: types.Move = self.moves_capture.items[self.index_capture];
                self.index_capture += 1;
                return move;
            }
        }

        if (self.stage == 14) {
            const move: types.Move = self.moves_capture.items[self.index_capture];
            self.index_capture += 1;
            return move;
        }

        if (self.stage == 4 or self.stage == 14) {
            self.stage += 1;
        }

        // Quiet init
        if (self.stage == 5) {
            pos.generateLegalMoves(allocator, types.GenerationType.quiet, pos.state.turn, &self.moves_quiet, is_960);
            self.stage += 1;
        }

        // Search for tt
        if (self.stage == 6) {
            self.stage += 1;
            if (self.tt_move != types.Move.none) {
                for (self.moves_quiet.items, 0..) |move, i| {
                    if (move == self.tt_move) {
                        _ = self.moves_quiet.swapRemove(i);
                        break;
                    }
                }
            }
        }

        // Sort quiets
        if (self.stage == 7) {
            const scores: []types.Value = try allocator.alloc(types.Value, self.moves_quiet.items.len);
            defer allocator.free(scores);
            pos.scoreMoves(self.moves_quiet.items, scores);
            position.orderMoves(self.moves_quiet.items, scores);
            self.stage += 1;
        }

        // Explored all quiets, move to next stage
        if (self.stage == 8 and self.index_quiet >= self.moves_quiet.items.len) {
            self.stage += 1;
        }

        // Quiet
        if (self.stage == 8) {
            const move: types.Move = self.moves_quiet.items[self.index_quiet];
            self.index_quiet += 1;
            return move;
        }

        // Explored all captures, move to next stage
        if (self.stage == 9 and self.index_capture >= self.moves_capture.items.len) {
            self.stage += 1;
        }

        // Negative captures
        if (self.stage == 9) {
            const move: types.Move = self.moves_capture.items[self.index_capture];
            self.index_capture += 1;
            return move;
        }

        return types.Move.none;
    }

    pub fn deinit(self: *MovePick, allocator: std.mem.Allocator) void {
        self.moves_capture.clearAndFree(allocator);
        self.moves_quiet.clearAndFree(allocator);
        self.stage = 0;
        self.tt_move = types.Move.none;
        self.index_capture = 0;
        self.index_quiet = 0;
        allocator.free(self.scores);
    }
};
