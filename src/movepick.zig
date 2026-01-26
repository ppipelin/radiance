const position = @import("position.zig");
const search = @import("search.zig");
const std = @import("std");
const tables = @import("tables.zig");
const types = @import("types.zig");

// TODO: Use enum for Stages
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
    // TODO: Avoid using allocations with types.max_moves and two lengths for slicing
    moves_capture: std.ArrayListUnmanaged(types.Move) = .empty,
    moves_quiet: std.ArrayListUnmanaged(types.Move) = .empty,
    stage: u8 = 0,
    tt_move: types.Move = types.Move.none,
    index_capture: u8 = 0,
    index_quiet: u8 = 0,

    pub fn nextMove(noalias self: *MovePick, allocator: std.mem.Allocator, noalias pos: *position.Position, pv_move: types.Move, comptime is_960: bool) !types.Move {
        if (self.stage == 0 or self.stage == 10) {
            self.stage += 1;

            // PV move replaces transposition table move
            if (pv_move != types.Move.none) {
                self.tt_move = pv_move;
                return self.tt_move;
            }

            if (self.tt_move != types.Move.none)
                return self.tt_move;

            const found: ?std.meta.Tuple(&[_]type{ types.Value, u8, types.Move, types.TableBound }) = tables.transposition_table.get(pos.state.material_key);
            if (found != null) {
                const move: types.Move = found.?[2];
                if (self.stage == 1 or (self.stage == 11 and move.isCapture())) {
                    // Guard from collisions
                    // Uncomment for high collision rate
                    // const from_piece: types.Piece = pos.board[move.getFrom().index()];
                    // const to_piece: types.Piece = pos.board[move.getTo().index()];
                    // if (from_piece != .none and from_piece.pieceToColor() == pos.state.turn and ((to_piece == .none and (!move.isCapture() or move.isEnPassant())) or (to_piece != .none and move.isCapture() and to_piece.pieceToColor() != pos.state.turn))) {
                    // if (from_piece != .none and from_piece.pieceToColor() == pos.state.turn and (to_piece == .none or (move.isCapture() and to_piece.pieceToColor() != pos.state.turn))) {
                    // const attacks: types.Bitboard = tables.getAttacks(from_piece.pieceToPieceType(), pos.state.turn, move.getFrom(), pos.bb_colors[types.Color.white.index()] | pos.bb_colors[types.Color.black.index()]) & ~pos.bb_colors[pos.state.turn.index()];
                    // if (attacks & move.getTo().sqToBB() >= 1) {
                    self.tt_move = move;
                    return move;
                    // }
                    // }
                }
            }
        }

        // Capture init
        if (self.stage == 1 or self.stage == 11) {
            pos.updateAttacked(is_960);

            switch (pos.state.turn) {
                inline else => |turn| pos.generateLegalMoves(allocator, .capture, turn, &self.moves_capture, is_960),
            }
            self.stage += 1;
        }

        // Search for tt to remove
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
            var scores: [types.max_moves]types.Value = undefined;
            pos.scoreMoves(self.moves_capture.items, .capture, &scores);
            position.orderMoves(self.moves_capture.items, &scores);
            self.stage += 1;
        }

        // Explored all positive captures, go to next stage
        if ((self.stage == 4 or self.stage == 14) and self.index_capture >= self.moves_capture.items.len) {
            self.stage += 1;
        }

        // Positive captures
        if (self.stage == 4) {
            if (extractMove(pos.*, self.moves_capture.items[self.index_capture..], 0)) {
                self.index_capture += 1;
                return self.moves_capture.items[self.index_capture - 1];
            }
        }

        if (self.stage == 14) {
            const move: types.Move = self.moves_capture.items[self.index_capture];
            self.index_capture += 1;
            return move;
        }

        // No satifying move was found, go to next stage
        if (self.stage == 4 or self.stage == 14) {
            self.stage += 1;
        }

        // Quiet init
        if (self.stage == 5) {
            switch (pos.state.turn) {
                inline else => |turn| pos.generateLegalMoves(allocator, .quiet, turn, &self.moves_quiet, is_960),
            }
            self.stage += 1;
        }

        // Search for tt to remove
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
            var scores: [types.max_moves]types.Value = undefined;
            pos.scoreMoves(self.moves_quiet.items, .quiet, &scores);
            position.orderMoves(self.moves_quiet.items, &scores);
            self.stage += 1;
        }

        // Explored all quiets, go to next stage
        if (self.stage == 8 and self.index_quiet >= self.moves_quiet.items.len) {
            self.stage += 1;
        }

        // Quiet
        if (self.stage == 8) {
            const move: types.Move = self.moves_quiet.items[self.index_quiet];
            self.index_quiet += 1;
            return move;
        }

        // Explored all negative captures, go to next stage
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

    pub fn deinit(noalias self: *MovePick, allocator: std.mem.Allocator) void {
        self.moves_capture.clearAndFree(allocator);
        self.moves_quiet.clearAndFree(allocator);
        self.stage = 0;
        self.tt_move = types.Move.none;
        self.index_capture = 0;
        self.index_quiet = 0;
    }

    // Find first move that satisfies threshold and put it first
    // Return false otherwise
    fn extractMove(pos: position.Position, moves: []types.Move, threshold: types.Value) bool {
        for (moves, 1..) |_, i| {
            if (search.seeGreaterEqual(pos, moves[0], threshold)) {
                return true;
            } else if (i < moves.len) {
                std.mem.swap(types.Move, &moves[0], &moves[i]);
            }
        }
        // Last element was brought first in the slice, reorder it
        std.mem.rotate(types.Move, moves, 1);
        return false;
    }
};
