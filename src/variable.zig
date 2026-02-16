const types = @import("types.zig");
const Value = types.Value;

pub var knight_mobility: Value = 5;
pub var bishop_mobility: Value = 5;
pub var rook_mobility: Value = 5;
pub var queen_mobility: Value = 5;
pub var king_mobility: Value = 5;

pub var pawn_threat_knight: Value = 0;
pub var pawn_threat_bishop: Value = 0;
pub var pawn_threat_rook: Value = 0;
pub var pawn_threat_queen: Value = 0;

pub var pawn_defend_king: Value = 5;
pub var pawn_isolated: Value = 30;
pub var pawn_doubled: Value = 15;
pub var pawn_blocked: Value = 10;
pub var pawn_protection: Value = 30;

pub var bishop_pair: Value = 10;

pub var rook_open_files: Value = 40;
pub var rook_semi_open_files: Value = 20;
