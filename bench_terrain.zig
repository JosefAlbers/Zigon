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
const terrain_gen = @import("terrain.zig");

fn formatWithCommas(buf: []u8, value: u64) []const u8 {
    var tmp: [32]u8 = undefined;
    const len = std.fmt.formatIntBuf(&tmp, value, 10, .lower, .{});
    if (len <= 3) {
        @memcpy(buf[0..len], tmp[0..len]);
        return buf[0..len];
    }
    const commas = (len - 1) / 3;
    const total = len + commas;
    var out_i: usize = total;
    var src_i: usize = len;
    var group: usize = 0;
    while (src_i > 0) {
        src_i -= 1;
        out_i -= 1;
        buf[out_i] = tmp[src_i];
        group += 1;
        if (group == 3 and src_i > 0) {
            out_i -= 1;
            buf[out_i] = ',';
            group = 0;
        }
    }
    return buf[0..total];
}

const BenchResult = struct {
    size: usize,
    median_ms: f64,
    pixels_per_sec: u64,
};

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const allocator = std.heap.page_allocator;
    const seed: u64 = 12345;
    const sizes = [_]usize{ 64, 128, 256, 512, 1024, 2048 };
    const warmup_runs: usize = 2;
    const bench_runs: usize = 5;
    try stdout.print("\n", .{});
    try stdout.print("╔══════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║       ZIGON TERRAIN GENERATION BENCHMARK (Zig)      ║\n", .{});
    try stdout.print("╚══════════════════════════════════════════════════════╝\n", .{});
    try stdout.print("\n  FBM: 6 octaves, persistence=0.5, lacunarity=2.0, scale=50.0\n", .{});
    try stdout.print("  Optimization: ReleaseFast\n", .{});
    try stdout.print("  Runs: {d} warmup + {d} measured (reporting median)\n\n", .{ warmup_runs, bench_runs });
    try stdout.print("  {s:<12} {s:>12} {s:>16} {s:>14}\n", .{ "Grid Size", "Median (ms)", "Pixels/sec", "Total px" });
    try stdout.print("  ------------ ------------ ---------------- --------------\n", .{});
    var results: [sizes.len]BenchResult = undefined;
    for (sizes, 0..) |size, idx| {
        const config = terrain_gen.TerrainConfig{
            .seed = seed,
            .size = size,
            .noise_weight = 1.0,
            .octaves = 6,
            .persistence = 0.5,
            .lacunarity = 2.0,
            .scale = 50.0,
        };
        for (0..warmup_runs) |_| {
            const t = try terrain_gen.generateTerrain(allocator, config);
            allocator.free(t);
        }
        var times: [10]u64 = undefined;
        for (0..bench_runs) |i| {
            const t0 = std.time.nanoTimestamp();
            const t = try terrain_gen.generateTerrain(allocator, config);
            const t1 = std.time.nanoTimestamp();
            allocator.free(t);
            times[i] = @intCast(t1 - t0);
        }
        std.mem.sort(u64, times[0..bench_runs], {}, std.sort.asc(u64));
        const median_ns = times[bench_runs / 2];
        const median_ms = @as(f64, @floatFromInt(median_ns)) / 1_000_000.0;
        const pixels = size * size;
        const pixels_per_sec: u64 = if (median_ns > 0)
            @intFromFloat(@as(f64, @floatFromInt(pixels)) / (@as(f64, @floatFromInt(median_ns)) / 1_000_000_000.0))
        else
            0;
        results[idx] = .{
            .size = size,
            .median_ms = median_ms,
            .pixels_per_sec = pixels_per_sec,
        };
        var pps_buf: [32]u8 = undefined;
        var px_buf: [32]u8 = undefined;
        const pps_str = formatWithCommas(&pps_buf, pixels_per_sec);
        const px_str = formatWithCommas(&px_buf, pixels);
        try stdout.print("  {d:<12} {d:>10.3} ms {s:>16} {s:>14}\n", .{
            size, median_ms, pps_str, px_str,
        });
    }
    try stdout.print("\n---JSON---\n[", .{});
    for (results[0..sizes.len], 0..) |r, i| {
        if (i > 0) try stdout.print(",", .{});
        try stdout.print("{{\"size\":{d},\"median_ms\":{d:.4},\"pixels_per_sec\":{d}}}", .{
            r.size, r.median_ms, r.pixels_per_sec,
        });
    }
    try stdout.print("]\n---END---\n", .{});
    try stdout.print("\n  Done.\n\n", .{});
}
