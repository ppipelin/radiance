const std = @import("std");

/// PRNG from https://github.com/SnowballSH/Avalanche
/// MIT License
/// Copyright (c) 2023 Yinuo Huang
pub const PRNG = struct {
    seed: u128,

    pub fn rand64(self: *PRNG) u64 {
        var x = self.seed;
        x ^= x >> 12;
        x ^= x << 25;
        x ^= x >> 27;
        self.seed = x;
        var r: u64 = @truncate(x);
        const x2: u64 = @truncate(x >> 64);
        r = r ^ x2;
        return r;
    }

    // Less bits
    pub fn sparse_rand64(self: *PRNG) u64 {
        return self.rand64() & self.rand64() & self.rand64();
    }

    pub fn new(seed: u128) PRNG {
        return PRNG{ .seed = seed };
    }
};
