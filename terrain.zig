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

//}}} INIT
//{{{ FBM

fn fade(t: f32) f32 {
    return t * t * t * (t * (t * 6 - 15) + 10);
}

fn lerp(t: f32, a: f32, b: f32) f32 {
    return a + t * (b - a);
}

fn grad(hash: u8, x: f32, y: f32, z: f32) f32 {
    const h = hash & 15;
    const u = if (h < 8) x else y;
    const v = if (h < 4) y else if (h == 12 or h == 14) x else z;
    return (if ((h & 1) == 0) u else -u) + (if ((h & 2) == 0) v else -v);
}

fn noise(x: f32, y: f32, z: f32, p: []const u8) f32 {
    const X = @as(u8, @intFromFloat(@mod(x, 256)));
    const Y = @as(u8, @intFromFloat(@mod(y, 256)));
    const Z = @as(u8, @intFromFloat(@mod(z, 256)));
    const x_floor = x - @floor(x);
    const y_floor = y - @floor(y);
    const z_floor = z - @floor(z);
    const u = fade(x_floor);
    const v = fade(y_floor);
    const w = fade(z_floor);
    const A = p[X] +% Y;
    const AA = p[A] +% Z;
    const AB = p[A +% 1] +% Z;
    const B = p[X +% 1] +% Y;
    const BA = p[B] +% Z;
    const BB = p[B +% 1] +% Z;
    return lerp(w, lerp(v, lerp(u, grad(p[AA], x_floor, y_floor, z_floor), grad(p[BA], x_floor - 1, y_floor, z_floor)), lerp(u, grad(p[AB], x_floor, y_floor - 1, z_floor), grad(p[BB], x_floor - 1, y_floor - 1, z_floor))), lerp(v, lerp(u, grad(p[AA +% 1], x_floor, y_floor, z_floor - 1), grad(p[BA +% 1], x_floor - 1, y_floor, z_floor - 1)), lerp(u, grad(p[AB +% 1], x_floor, y_floor - 1, z_floor - 1), grad(p[BB +% 1], x_floor - 1, y_floor - 1, z_floor - 1))));
}

fn generatePermutation(allocator: std.mem.Allocator, seed: u64) ![]u8 {
    var rng = std.rand.DefaultPrng.init(seed);
    var random = rng.random();
    const perm = try allocator.alloc(u8, 512);
    var source = try allocator.alloc(u8, 256);
    defer allocator.free(source);
    for (source, 0..) |*value, index| {
        value.* = @intCast(index);
    }
    var i: usize = 255;
    while (i > 0) : (i -= 1) {
        const j = random.intRangeAtMost(usize, 0, i);
        std.mem.swap(u8, &source[i], &source[j]);
    }
    @memcpy(perm[0..256], source);
    @memcpy(perm[256..], source);
    return perm;
}

fn fbm(x: f32, y: f32, octaves: u8, persistence: f32, lacunarity: f32, scale: f32, p: []const u8) f32 {
    var value: f32 = 0;
    var amplitude: f32 = 1;
    var frequency: f32 = 1;
    var i: u8 = 0;
    while (i < octaves) : (i += 1) {
        value += amplitude * noise(x * frequency / scale, y * frequency / scale, 0, p);
        amplitude *= persistence;
        frequency *= lacunarity;
    }
    return value;
}

pub const TerrainConfig = struct {
    seed: u64,
    size: usize,
    base_map: ?[]const f32 = null,
    noise_weight: f32 = 1.0,
};

pub fn generateTerrain(allocator: std.mem.Allocator, config: TerrainConfig) ![]f32 {
    const size = config.size;
    var terrain = try allocator.alloc(f32, size * size);
    errdefer allocator.free(terrain);
    const perm = try generatePermutation(allocator, config.seed);
    defer allocator.free(perm);
    var min: f32 = std.math.inf(f32);
    var max: f32 = -std.math.inf(f32);
    for (0..size) |y| {
        for (0..size) |x| {
            const value = fbm(@floatFromInt(x), @floatFromInt(y), 6, 0.5, 2.0, 50.0, perm);
            terrain[y * size + x] = value;
            min = @min(min, value);
            max = @max(max, value);
        }
    }
    const range = if (max > min) max - min else 1.0;
    var sum: f32 = 0.0;
    for (terrain) |*value| {
        value.* = (value.* - min) / range;
        sum += value.*;
    }
    const mean = sum / @as(f32, @floatFromInt(terrain.len));
    if (config.base_map) |base| {
        const limit = @min(base.len, terrain.len);
        for (0..limit) |i| {
            const centered_noise = terrain[i] - mean;
            terrain[i] = base[i] + (centered_noise * config.noise_weight);
        }
    } else {
        if (config.noise_weight != 1.0) {
            for (terrain) |*value| {
                value.* *= config.noise_weight;
            }
        }
    }
    return terrain;
}

//}}} FBM
//{{{ PDS

pub const Point = extern struct {
    x: f32,
    z: f32,
};

pub const ForestConfig = struct {
    min_dist: f32,
    density_scale: f32,
    moisture_threshold: f32,
};

pub fn generateFoliage(
    allocator: std.mem.Allocator,
    size: usize,
    terrain: []const f32,
    config: ForestConfig,
    seed: u64,
) ![]Point {
    var points = std.ArrayList(Point).init(allocator);
    errdefer points.deinit();
    const perm = try generatePermutation(allocator, seed + 1);
    defer allocator.free(perm);
    var prng = std.rand.DefaultPrng.init(seed);
    const random = prng.random();
    var y: f32 = 0;
    while (y < @as(f32, @floatFromInt(size))) : (y += config.min_dist) {
        var x: f32 = 0;
        while (x < @as(f32, @floatFromInt(size))) : (x += config.min_dist) {
            const rx = x + random.float(f32) * config.min_dist;
            const rz = y + random.float(f32) * config.min_dist;
            if (rx >= @as(f32, @floatFromInt(size)) or rz >= @as(f32, @floatFromInt(size))) continue;
            const ix = @as(usize, @intFromFloat(rx));
            const iz = @as(usize, @intFromFloat(rz));
            const height = terrain[iz * size + ix];
            if (height > 0.15 and height < 0.7) {
                const moisture = noise(rx / config.density_scale, rz / config.density_scale, 0, perm);
                const detail = noise(rx / 10.0, rz / 10.0, 1, perm) * 0.3;
                const normalized_moisture = ((moisture + detail) + 1.0) / 2.0;
                if (normalized_moisture > config.moisture_threshold) {
                    try points.append(.{ .x = rx, .z = rz });
                }
            }
        }
    }
    return points.toOwnedSlice();
}

//}}} PDS
//{{{ MISC

pub fn createBowlMap(allocator: std.mem.Allocator, size: usize) ![]f32 {
    const map = try allocator.alloc(f32, size * size);
    const center = @as(f32, @floatFromInt(size)) / 2.0;
    const max_dist = std.math.sqrt(center * center * 2.0);
    for (0..size) |y| {
        for (0..size) |x| {
            const dx = @as(f32, @floatFromInt(x)) - center;
            const dy = @as(f32, @floatFromInt(y)) - center;
            const dist = std.math.sqrt(dx * dx + dy * dy);
            map[y * size + x] = std.math.pow(f32, dist / max_dist, 2.0) + 0.2;
        }
    }
    return map;
}

pub fn loadBaseMapFromFile(allocator: std.mem.Allocator, path: []const u8, size: usize) ![]f32 {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        return err;
    };
    defer file.close();
    const content = file.readToEndAlloc(allocator, size * size * 32) catch |err| {
        return err;
    };
    defer allocator.free(content);
    var token_count: usize = 0;
    var count_iter = std.mem.tokenizeAny(u8, content, " \n\r,");
    while (count_iter.next()) |_| token_count += 1;
    if (token_count != size * size) {
        return error.InvalidSize;
    }
    var map = try allocator.alloc(f32, size * size);
    @memset(map, 0.0);
    var iter = std.mem.tokenizeAny(u8, content, " \n\r,");
    var i: usize = 0;
    while (iter.next()) |tok| {
        if (i < map.len) map[i] = std.fmt.parseFloat(f32, tok) catch 0.0;
        i += 1;
    }
    return map;
}

pub fn getWeightedAverageHeight(terrain: []const f32, x: f32, z: f32, radius: f32, size: usize, alpha: f32) ?f32 {
    const f_size = @as(f32, @floatFromInt(size));
    const center_x = @round(x);
    const center_z = @round(z);
    var sum: f32 = 0.0;
    var total_weight: f32 = 0.0;
    var dz: f32 = -radius;
    while (dz <= 1.0) : (dz += 1.0) {
        var dx: f32 = -1.0;
        while (dx <= 1.0) : (dx += 1.0) {
            const neighbor_x = center_x + dx;
            const neighbor_z = center_z + dz;
            if (neighbor_x >= 0 and neighbor_x < f_size and neighbor_z >= 0 and neighbor_z < f_size) {
                const diff_x = neighbor_x - x;
                const diff_z = neighbor_z - z;
                const dist_sq = diff_x * diff_x + diff_z * diff_z;
                const weight = @exp(-alpha * dist_sq);
                const ix = @as(usize, @intFromFloat(neighbor_x));
                const iz = @as(usize, @intFromFloat(neighbor_z));
                const h = terrain[iz * size + ix];
                sum += h * weight;
                total_weight += weight;
            }
        }
    }
    if (total_weight <= 0.0) return null;
    return sum / total_weight;
}

pub fn getTerrainHeight(
    terrain: []const f32,
    x: f32,
    z: f32,
    reach: usize,
    dim_x: usize,
    dim_z: usize,
    mode: enum { avg, min, max, non },
) ?f32 {
    if (x < 0 or z < 0) return null;
    const xu = @as(usize, @intFromFloat(@round(x)));
    const zu = @as(usize, @intFromFloat(@round(z)));
    if (xu >= dim_x or zu >= dim_z) return null;
    if (mode == .non) {
        const idx = zu * dim_x + xu;
        return if (idx < terrain.len) terrain[idx] else null;
    }
    var sum: f32 = 0.0;
    var count: usize = 0;
    var minv: f32 = std.math.inf(f32);
    var maxv: f32 = -std.math.inf(f32);
    if (xu >= dim_x or zu >= dim_z) return null;
    const x0 = if (xu > reach) xu - reach else 0;
    const z0 = if (zu > reach) zu - reach else 0;
    const x1 = @min(xu + reach, dim_x - 1);
    const z1 = @min(zu + reach, dim_z - 1);
    var zz = z0;
    while (zz <= z1) : (zz += 1) {
        var xx = x0;
        while (xx <= x1) : (xx += 1) {
            const idx = zz * dim_x + xx;
            if (idx < terrain.len) {
                const h = terrain[idx];
                sum += h;
                if (h < minv) minv = h;
                if (h > maxv) maxv = h;
                count += 1;
            }
        }
    }
    if (count == 0) return null;
    return switch (mode) {
        .avg => sum / @as(f32, @floatFromInt(count)),
        .min => minv,
        .max => maxv,
        .non => unreachable,
    };
}

pub fn getBilinearHeight(terrain: []const f32, xz: @Vector(2, f32), size: usize) ?f32 {
    const f_size = @as(f32, @floatFromInt(size));
    if (@reduce(.Or, xz < @as(@Vector(2, f32), @splat(0))) or
        @reduce(.Or, xz >= @as(@Vector(2, f32), @splat(f_size)))) return null;
    const xz0 = @floor(xz);
    const t_xz = xz - xz0;
    const ix0 = @as(usize, @intFromFloat(xz0[0]));
    const iz0 = @as(usize, @intFromFloat(xz0[1]));
    const ix1 = @min(ix0 + 1, size - 1);
    const iz1 = @min(iz0 + 1, size - 1);
    const h00 = terrain[iz0 * size + ix0];
    const h10 = terrain[iz0 * size + ix1];
    const h01 = terrain[iz1 * size + ix0];
    const h11 = terrain[iz1 * size + ix1];
    const row0 = h00 + t_xz[0] * (h10 - h00);
    const row1 = h01 + t_xz[0] * (h11 - h01);
    return row0 + t_xz[1] * (row1 - row0);
}

fn rayTerrainIntersection(
    terrain: []const f32,
    ray_origin: @Vector(3, f32),
    ray_direction: @Vector(3, f32),
    cube_size: f32,
    size: usize,
) ?@Vector(3, f32) {
    const step: f32 = 1.0;
    var t: f32 = 0.0;
    const max_dist = @as(f32, @floatFromInt(size)) * cube_size * 2.5;
    const offset = @as(f32, @floatFromInt(size)) * cube_size / 2.0;
    const f_size = @as(f32, @floatFromInt(size));
    while (t < max_dist) : (t += step) {
        const p = @Vector(3, f32){
            .x = ray_origin.x + ray_direction.x * t,
            .y = ray_origin.y + ray_direction.y * t,
            .z = ray_origin.z + ray_direction.z * t,
        };
        const tx = p.x + offset;
        const tz = p.z + offset;
        if (tx >= 0 and tx < f_size and tz >= 0 and tz < f_size) {
            if (p.y <= getWeightedAverageHeight(
                terrain,
                tx,
                tz,
                1.0,
                size,
                1.0,
            ) * cube_size) return p;
        }
    }
    return null;
}

pub const Color = extern struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

fn hsvToRgba(h: f32, s: f32, v: f32) Color {
    const c = v * s;
    const x = c * (1.0 - @abs(@mod(h / 60.0, 2.0) - 1.0));
    const m = v - c;
    const segment = @as(usize, @intFromFloat(@mod(h / 60.0, 6.0)));
    const rgb_table = [6][3]f32{
        .{ c, x, 0 }, .{ x, c, 0 }, .{ 0, c, x },
        .{ 0, x, c }, .{ x, 0, c }, .{ c, 0, x },
    };
    const rgb = rgb_table[segment];
    return Color{
        .r = @intFromFloat((rgb[0] + m) * 255.0),
        .g = @intFromFloat((rgb[1] + m) * 255.0),
        .b = @intFromFloat((rgb[2] + m) * 255.0),
        .a = 255,
    };
}

fn getTerrainColor(height: f32, water_level: f32, cube_height: f32) Color {
    const v = (height - water_level) / cube_height;
    if (v < -0.4) return hsvToRgba(40.0, 0.5, 0.0);
    if (v < 0.05) return hsvToRgba(40.0, 0.5, 0.8 + v * 2.0);
    if (v < 0.15) return hsvToRgba(95.0, 0.55 + v, 0.625 - v * 0.5);
    if (v < 0.35) return hsvToRgba(110.0, 0.6 + (v - 0.15) * 2.0, 0.5 - (v - 0.15) * 0.7);
    if (v < 0.55) return hsvToRgba(30.0, 0.6 - (v - 0.35) * 1.5, 0.3 + (v - 0.35) * 1.5);
    if (v < 1.55) return hsvToRgba(210.0, 0.1, 1.55 - v);
    return hsvToRgba(210.0, 0.1, 0.0);
}

pub fn writeTextureBuffer(
    buffer: []Color,
    terrain: []const f32,
    base_size: usize,
    texture_scale: f32,
    water_level: f32,
    cube_height: f32,
) void {
    const w = @as(usize, @intFromFloat(@as(f32, @floatFromInt(base_size)) * texture_scale));
    const h = w;
    if (buffer.len < w * h) return;
    const inv_scale = 1.0 / texture_scale;
    for (0..h) |z| {
        const fz = @as(f32, @floatFromInt(z)) * inv_scale;
        for (0..w) |x| {
            const fx = @as(f32, @floatFromInt(x)) * inv_scale;
            const height = getBilinearHeight(terrain, .{ fx, fz }, base_size);
            const h_val = height orelse 0.0;
            buffer[z * w + x] = getTerrainColor(h_val * cube_height, water_level, cube_height);
        }
    }
}

//}}} UTIL
//{{{ WASM

var wasm_terrain: ?[]f32 = null;

export fn generate_terrain_wasm(seed: u32, size: usize) void {
    if (wasm_terrain) |terrain| {
        std.heap.page_allocator.free(terrain);
    }
    const config = TerrainConfig{ .seed = seed, .size = size };
    if (generateTerrain(std.heap.page_allocator, config)) |generated_terrain| {
        wasm_terrain = generated_terrain;
    } else |_| {
        wasm_terrain = null;
    }
}

export fn get_terrain_height_wasm(x: i32, y: i32, size: usize) f32 {
    if (wasm_terrain) |terrain| {
        const index = @as(usize, @intCast(y)) * size + @as(usize, @intCast(x));
        if (index < terrain.len) {
            return terrain[index];
        }
    }
    return 0;
}

export fn free_terrain_wasm() void {
    if (wasm_terrain) |terrain| {
        std.heap.page_allocator.free(terrain);
        wasm_terrain = null;
    }
}

var wasm_foliage: ?[]Point = null;

export fn generate_foliage_wasm(seed: u32, size: usize) void {
    if (wasm_foliage) |points| {
        std.heap.page_allocator.free(points);
    }
    wasm_foliage = null;
    if (wasm_terrain) |terrain| {
        const config = ForestConfig{
            .min_dist = 3.5,
            .density_scale = 25.0,
            .moisture_threshold = 0.5,
        };
        if (generateFoliage(std.heap.page_allocator, size, terrain, config, seed)) |points| {
            wasm_foliage = points;
        } else |_| {}
    }
}

export fn get_foliage_ptr() u32 {
    if (wasm_foliage) |points| {
        return @intCast(@intFromPtr(points.ptr));
    }
    return 0;
}

export fn get_foliage_len() usize {
    if (wasm_foliage) |points| {
        return points.len;
    }
    return 0;
}

//}}} WASM
