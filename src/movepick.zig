const position = @import("position.zig");
const std = @import("std");
const tables = @import("tables.zig");
const types = @import("types.zig");

/// MovePick struct to allow staged move generation
/// Stages
/// 1. Capture init
/// 2. Capture sort
/// 3. Capture return
/// 4. Quiet init
/// 5. Quiet sort
/// 6. Quiet return
/// 7. return `Move.none`
pub const MovePick = struct {
    moves_capture: std.ArrayListUnmanaged(types.Move) = .empty,
    moves_quiet: std.ArrayListUnmanaged(types.Move) = .empty,
    stage: u8 = 0,
    pv_move: types.Move = types.Move.none,
    index_capture: u8 = 0,
    index_quiet: u8 = 0,

    pub fn nextMove(self: *MovePick, allocator: std.mem.Allocator, pos: *position.Position, pv_move: types.Move, is_960: bool) types.Move {
        // Capture init with pv
        if (self.stage == 0) {
            pos.updateAttacked();
            pos.generateLegalMoves(allocator, types.GenerationType.capture, pos.state.turn, &self.moves_capture, is_960);
            self.stage += 1;
            if (pv_move != types.Move.none) {
                for (self.moves_capture.items, 0..) |move, i| {
                    if (move == pv_move) {
                        return self.moves_capture.swapRemove(i);
                    }
                }
            }
        }

        // We did not sort captures
        // TODO: sort positive and negative captures separately
        if (self.stage == 1) {
            pos.orderMoves(self.moves_capture.items, types.Move.none);
            self.stage += 1;
        }

        // Explored all captures, move to next stage
        if (self.stage == 2 and self.index_capture >= self.moves_capture.items.len) {
            self.stage += 1;
        }

        // Positive captures
        if (self.stage == 2) {
            const move: types.Move = self.moves_capture.items[self.index_capture];
            var from_piece: types.PieceType = pos.board[move.getFrom().index()].pieceToPieceType();
            var to_piece: types.PieceType = pos.board[move.getTo().index()].pieceToPieceType();
            if (tables.material[to_piece.index()] > tables.material[from_piece.index()]) {
                self.index_capture += 1;
                return move;
            }
        }

        if (self.stage == 2) {
            self.stage += 1;
        }

        // Quiet init with pv
        if (self.stage == 3) {
            pos.generateLegalMoves(allocator, types.GenerationType.quiet, pos.state.turn, &self.moves_quiet, is_960);
            self.stage += 1;
            if (pv_move != types.Move.none) {
                for (self.moves_quiet.items, 0..) |move, i| {
                    if (move == pv_move) {
                        return self.moves_quiet.swapRemove(i);
                    }
                }
            }
        }

        // We did not sort quiets
        if (self.stage == 4) {
            pos.orderMoves(self.moves_quiet.items, types.Move.none);
            self.stage += 1;
        }

        // Explored all quiets, move to next stage
        if (self.stage == 5 and self.index_quiet >= self.moves_quiet.items.len) {
            self.stage += 1;
        }

        // Quiet
        if (self.stage == 5) {
            const move: types.Move = self.moves_quiet.items[self.index_quiet];
            self.index_quiet += 1;
            return move;
        }

        // Explored all captures, move to next stage
        if (self.stage == 6 and self.index_capture >= self.moves_capture.items.len) {
            self.stage += 1;
        }

        // Negative captures
        if (self.stage == 6) {
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
        self.pv_move = types.Move.none;
        self.index_capture = 0;
        self.index_quiet = 0;
    }
};
