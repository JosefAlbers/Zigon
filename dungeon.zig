//{{{ INIT
// Copyright 2026 J Joe
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//     http://www.apache.org/licenses/LICENSE-2.0
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

const std = @import("std");

const MAX_PATTERNS = 256;
const Mask = std.bit_set.StaticBitSet(MAX_PATTERNS);

pub const WFCConfig = struct {
    pattern_size: usize = 3,
    output_width: usize = 30,
    output_height: usize = 30,
    max_attempts: usize = 100,
    use_pattern_weights: bool = true,
    dungeon_type: DungeonType = .rogue,
    seed: ?u64 = null,
    verbose: bool = false,
};

pub const WFCResult = struct {
    map: []u8,
    width: usize,
    height: usize,
    success: bool,
    attempts_taken: usize,

    pub fn deinit(self: *WFCResult, allocator: std.mem.Allocator) void {
        allocator.free(self.map);
    }
};

//}}} INIT
//{{{ WFC

fn addAugmentedWithWeights(
    allocator: std.mem.Allocator,
    original: []const u8,
    list: *std.ArrayList([]u8),
    weights: *std.ArrayList(f32),
    N: usize,
) !void {
    const curr = try allocator.alloc(u8, N * N);
    defer allocator.free(curr);
    @memcpy(curr, original);
    for (0..4) |_| {
        if (findPatternIndex(list.items, curr, N)) |idx| {
            weights.items[idx] += 1.0;
        } else {
            const copy = try allocator.alloc(u8, N * N);
            @memcpy(copy, curr);
            try list.append(copy);
            try weights.append(1.0);
        }
        var flipped = try allocator.alloc(u8, N * N);
        defer allocator.free(flipped);
        for (0..N) |y| {
            for (0..N) |x| {
                flipped[y * N + x] = curr[y * N + (N - 1 - x)];
            }
        }
        if (findPatternIndex(list.items, flipped, N)) |idx| {
            weights.items[idx] += 1.0;
        } else {
            const copy = try allocator.alloc(u8, N * N);
            @memcpy(copy, flipped);
            try list.append(copy);
            try weights.append(1.0);
        }
        var next = try allocator.alloc(u8, N * N);
        defer allocator.free(next);
        for (0..N) |y| {
            for (0..N) |x| {
                next[x * N + (N - 1 - y)] = curr[y * N + x];
            }
        }
        @memcpy(curr, next);
    }
}

fn findPatternIndex(items: [][]const u8, p: []const u8, N: usize) ?usize {
    _ = N;
    for (items, 0..) |item, i| {
        if (std.mem.eql(u8, item, p)) return i;
    }
    return null;
}

fn canOverlap(p1: []const u8, p2: []const u8, dx: i32, dy: i32, N: usize) bool {
    const n: i32 = @intCast(N);
    for (0..N) |y| {
        for (0..N) |x| {
            const tx = @as(i32, @intCast(x)) + dx;
            const ty = @as(i32, @intCast(y)) + dy;
            if (tx >= 0 and tx < n and ty >= 0 and ty < n) {
                const ux: usize = @intCast(tx);
                const uy: usize = @intCast(ty);
                if (p1[y * N + x] != p2[uy * N + ux]) return false;
            }
        }
    }
    return true;
}

fn findLowestEntropyWithNoise(wave: []Mask, random: std.rand.Random) ?usize {
    var min_e: f32 = @floatFromInt(MAX_PATTERNS + 1);
    var best: ?usize = null;
    for (wave, 0..) |m, i| {
        const c = m.count();
        if (c > 1) {
            const noise = random.float(f32) * 0.1;
            const entropy: f32 = @as(f32, @floatFromInt(c)) + noise;
            if (entropy < min_e) {
                min_e = entropy;
                best = i;
            }
        }
    }
    return best;
}

fn pickWeightedRandomFromMask(m: Mask, num_p: usize, weights: []f32, random: std.rand.Random) usize {
    var opts = std.ArrayList(usize).init(std.heap.page_allocator);
    defer opts.deinit();
    var cumulative_weights = std.ArrayList(f32).init(std.heap.page_allocator);
    defer cumulative_weights.deinit();
    var total: f32 = 0.0;
    for (0..num_p) |i| {
        if (m.isSet(i)) {
            opts.append(i) catch unreachable;
            total += weights[i];
            cumulative_weights.append(total) catch unreachable;
        }
    }
    if (opts.items.len == 0) unreachable;
    if (opts.items.len == 1) return opts.items[0];
    const r = random.float(f32) * total;
    for (cumulative_weights.items, 0..) |cum_weight, idx| {
        if (r <= cum_weight) return opts.items[idx];
    }
    return opts.items[opts.items.len - 1];
}

fn pickRandomFromMask(m: Mask, num_p: usize, random: std.rand.Random) usize {
    var opts = std.ArrayList(usize).init(std.heap.page_allocator);
    defer opts.deinit();
    for (0..num_p) |i| if (m.isSet(i)) opts.append(i) catch unreachable;
    return opts.items[random.intRangeLessThan(usize, 0, opts.items.len)];
}

fn propagate(
    allocator: std.mem.Allocator,
    wave: []Mask,
    start: usize,
    rules: []Mask,
    num_p: usize,
    output_width: usize,
    output_height: usize,
) !void {
    var stack = std.ArrayList(usize).init(allocator);
    defer stack.deinit();
    try stack.append(start);
    const dx = [4]i32{ 0, 1, 0, -1 };
    const dy = [4]i32{ -1, 0, 1, 0 };
    while (stack.popOrNull()) |curr| {
        const cx = curr % output_width;
        const cy = curr / output_width;
        for (0..4) |dir| {
            const nx = @as(i32, @intCast(cx)) + dx[dir];
            const ny = @as(i32, @intCast(cy)) + dy[dir];
            if (nx >= 0 and nx < output_width and ny >= 0 and ny < output_height) {
                const n_idx = @as(usize, @intCast(ny)) * output_width + @as(usize, @intCast(nx));
                const old = wave[n_idx];
                if (old.count() == 0) continue;
                var valid = Mask.initEmpty();
                var it = wave[curr].iterator(.{});
                while (it.next()) |p_idx| {
                    valid.setUnion(rules[dir * num_p + p_idx]);
                }
                wave[n_idx].setIntersection(valid);
                if (!wave[n_idx].eql(old) and wave[n_idx].count() > 0) {
                    try stack.append(n_idx);
                }
            }
        }
    }
}

//}}} WFC
//{{{ PRESET

pub const DungeonType = enum {
    rooms,
    rogue,
    cavern,
    maze,
    labyrinth,
    arena,

    pub fn getBitmap(self: DungeonType) struct { data: []const u8, width: usize, height: usize } {
        return switch (self) {
            .rooms => .{
                .data = &ROOMS,
                .width = 10,
                .height = 8,
            },
            .rogue => .{
                .data = &ROGUE,
                .width = 16,
                .height = 16,
            },
            .cavern => .{
                .data = &CAVERN,
                .width = 12,
                .height = 12,
            },
            .maze => .{
                .data = &MAZE,
                .width = 10,
                .height = 10,
            },
            .labyrinth => .{
                .data = &LABYRINTH,
                .width = 12,
                .height = 12,
            },
            .arena => .{
                .data = &ARENA,
                .width = 10,
                .height = 10,
            },
        };
    }
};

const ROOMS = [_]u8{
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
    0, 1, 0, 0, 0, 0, 0, 0, 1, 0,
    0, 1, 0, 0, 1, 1, 0, 0, 1, 0,
    0, 1, 1, 0, 1, 1, 0, 1, 1, 0,
    0, 0, 1, 1, 1, 1, 1, 1, 0, 0,
    0, 0, 0, 0, 1, 1, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
};

const ROGUE = [_]u8{
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 1, 1, 1, 0, 0, 1, 1, 1, 1, 0, 0, 1, 1, 1, 0,
    0, 1, 1, 1, 0, 0, 1, 1, 1, 1, 0, 0, 1, 1, 1, 0,
    0, 1, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 0,
    0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0,
    0, 0, 1, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 1, 0, 0,
    0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0,
    0, 1, 1, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 1, 1, 0,
    0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0,
    0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0,
    0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 1, 1, 0, 0,
    0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0,
    0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
};

const CAVERN = [_]u8{
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0,
    0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0,
    0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 0,
    0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0,
    0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0,
    0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0,
    0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0,
    0, 0, 1, 1, 1, 1, 0, 1, 1, 1, 1, 0,
    0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 0, 0,
    0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
};

const MAZE = [_]u8{
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 1, 1, 0, 1, 1, 0, 1, 1, 0,
    0, 1, 1, 0, 1, 1, 0, 1, 1, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 1, 1, 0, 1, 1, 0, 1, 1, 0,
    0, 1, 1, 0, 1, 1, 0, 1, 1, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 1, 1, 0, 1, 1, 0, 1, 1, 0,
    0, 1, 1, 0, 1, 1, 0, 1, 1, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
};

const LABYRINTH = [_]u8{
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 0,
    0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 1, 0,
    0, 1, 1, 1, 0, 1, 1, 1, 0, 0, 1, 0,
    0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 1, 0,
    0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0,
    0, 1, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0,
    0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0,
    0, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 0,
    0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0,
    0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
};

const ARENA = [_]u8{
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
    0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
    0, 1, 1, 0, 0, 0, 0, 1, 1, 0,
    0, 1, 1, 0, 0, 0, 0, 1, 1, 0,
    0, 1, 1, 0, 0, 0, 0, 1, 1, 0,
    0, 1, 1, 0, 0, 0, 0, 1, 1, 0,
    0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
    0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
};

//}}} PRESET
//{{{ MAIN

pub fn spawn(allocator: std.mem.Allocator, config: WFCConfig) !WFCResult {
    const N = config.pattern_size;
    const bitmap_info = config.dungeon_type.getBitmap();
    const input_width = bitmap_info.width;
    const input_height = bitmap_info.height;
    const input_bitmap = bitmap_info.data;
    if (config.verbose) {
        const stdout = std.io.getStdOut().writer();
        try stdout.print("Generating {d}×{d} dungeon using {s} archetype...\n", .{ config.output_width, config.output_height, @tagName(config.dungeon_type) });
    }
    var patterns = std.ArrayList([]u8).init(allocator);
    defer {
        for (patterns.items) |p| allocator.free(p);
        patterns.deinit();
    }
    var pattern_weights = std.ArrayList(f32).init(allocator);
    defer pattern_weights.deinit();
    var y: usize = 0;
    while (y + N <= input_height) : (y += 1) {
        var x: usize = 0;
        while (x + N <= input_width) : (x += 1) {
            var p = try allocator.alloc(u8, N * N);
            for (0..N) |py| {
                for (0..N) |px| {
                    p[py * N + px] = input_bitmap[(y + py) * input_width + (x + px)];
                }
            }
            try addAugmentedWithWeights(allocator, p, &patterns, &pattern_weights, N);
            allocator.free(p);
        }
    }
    const num_p = patterns.items.len;
    if (config.verbose) {
        const stdout = std.io.getStdOut().writer();
        try stdout.print("Extracted {d} unique patterns\n", .{num_p});
    }
    if (config.use_pattern_weights) {
        var total_weight: f32 = 0;
        for (pattern_weights.items) |w| total_weight += w;
        for (pattern_weights.items) |*w| w.* = w.* / total_weight;
    }
    var rules = try allocator.alloc(Mask, 4 * num_p);
    defer allocator.free(rules);
    for (rules) |*r| r.* = Mask.initEmpty();
    for (0..num_p) |i| {
        for (0..num_p) |j| {
            if (canOverlap(patterns.items[i], patterns.items[j], 0, -1, N)) rules[0 * num_p + i].set(j);
            if (canOverlap(patterns.items[i], patterns.items[j], 1, 0, N)) rules[1 * num_p + i].set(j);
            if (canOverlap(patterns.items[i], patterns.items[j], 0, 1, N)) rules[2 * num_p + i].set(j);
            if (canOverlap(patterns.items[i], patterns.items[j], -1, 0, N)) rules[3 * num_p + i].set(j);
        }
    }
    var wave = try allocator.alloc(Mask, config.output_width * config.output_height);
    defer allocator.free(wave);
    const seed = config.seed orelse @as(u64, @intCast(std.time.timestamp()));
    var prng = std.rand.DefaultPrng.init(seed);
    const random = prng.random();
    var attempt: usize = 0;
    var success = false;
    while (attempt < config.max_attempts) : (attempt += 1) {
        var initial_mask = Mask.initEmpty();
        for (0..num_p) |i| initial_mask.set(i);
        @memset(wave, initial_mask);
        var contradiction = false;
        var steps: usize = 0;
        while (findLowestEntropyWithNoise(wave, random)) |target_idx| {
            steps += 1;
            const m = wave[target_idx];
            if (m.count() == 0) {
                contradiction = true;
                break;
            }
            const chosen = if (config.use_pattern_weights)
                pickWeightedRandomFromMask(m, num_p, pattern_weights.items, random)
            else
                pickRandomFromMask(m, num_p, random);
            var collapsed = Mask.initEmpty();
            collapsed.set(chosen);
            wave[target_idx] = collapsed;
            try propagate(allocator, wave, target_idx, rules, num_p, config.output_width, config.output_height);
            for (wave) |cell| {
                if (cell.count() == 0) {
                    contradiction = true;
                    break;
                }
            }
            if (contradiction) break;
        }
        if (!contradiction) {
            success = true;
            if (config.verbose) {
                const stdout = std.io.getStdOut().writer();
                try stdout.print("Success on attempt {d} after {d} steps\n", .{ attempt + 1, steps });
            }
            break;
        }
    }
    var output = try allocator.alloc(u8, config.output_width * config.output_height);
    for (wave, 0..) |m, i| {
        if (m.count() == 1) {
            const idx = m.findFirstSet().?;
            const center_idx = (N / 2) * N + (N / 2);
            output[i] = patterns.items[idx][center_idx];
        } else {
            output[i] = 2;
        }
    }
    return WFCResult{
        .map = output,
        .width = config.output_width,
        .height = config.output_height,
        .success = success,
        .attempts_taken = attempt + 1,
    };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();
    const stdout = std.io.getStdOut().writer();
    const configs = [_]WFCConfig{
        .{ .dungeon_type = .rogue, .use_pattern_weights = true, .verbose = true },
        .{ .dungeon_type = .cavern, .use_pattern_weights = true, .verbose = true },
        .{ .dungeon_type = .labyrinth, .use_pattern_weights = false, .verbose = true },
    };
    for (configs) |config| {
        var result = try spawn(allocator, config);
        defer result.deinit(allocator);
        try stdout.print("\n", .{});
        for (0..result.height) |y| {
            for (0..result.width) |x| {
                const val = result.map[y * result.width + x];
                const char = switch (val) {
                    0 => "  ",
                    1 => "██",
                    else => "??",
                };
                try stdout.print("{s}", .{char});
            }
            try stdout.print("\n", .{});
        }
        try stdout.print("\n", .{});
    }
}

//}}} MAIN
