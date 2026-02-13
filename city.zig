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

pub const CityConfig = struct {
    pocket_scale: f32 = 80.0,
    pocket_threshold: f32 = 0.45,
    district_size: f32 = 30.0,
    arterial_width: f32 = 0.15,
    subdivisions: i32 = 3,
    building_density: f32 = 0.7,
    min_building_height: f32 = 0.2,
    max_building_height: f32 = 3.0,
    min_altitude: f32 = 0.5,
    max_altitude: f32 = 12.0,
};

fn hash2(x: i32, y: i32, seed: u64) u64 {
    var h: u64 = seed;
    h = h +% @as(u64, @bitCast(@as(i64, x))) *% 0x9E3779B97F4A7C15;
    h = h ^ (h >> 30);
    h = h +% @as(u64, @bitCast(@as(i64, y))) *% 0xBF58476D1CE4E5B9;
    h = h ^ (h >> 27);
    return h;
}

fn floatHash(h: u64) f32 {
    return @as(f32, @floatFromInt(h >> 40)) / 16777216.0;
}

fn valueNoise(x: f32, y: f32, seed: u64) f32 {
    const ix = @floor(x);
    const iy = @floor(y);
    const fx = x - ix;
    const fy = y - iy;
    const i: i32 = @intFromFloat(ix);
    const j: i32 = @intFromFloat(iy);
    const v00 = floatHash(hash2(i, j, seed));
    const v10 = floatHash(hash2(i + 1, j, seed));
    const v01 = floatHash(hash2(i, j + 1, seed));
    const v11 = floatHash(hash2(i + 1, j + 1, seed));
    const ux = fx * fx * (3.0 - 2.0 * fx);
    const uy = fy * fy * (3.0 - 2.0 * fy);
    return (v00 * (1.0 - ux) + v10 * ux) * (1.0 - uy) + (v01 * (1.0 - ux) + v11 * ux) * uy;
}

fn inDistrict(wx: f32, wz: f32, inv_dist: f32, config: CityConfig, seed: u64) bool {
    const gx = @floor(wx * inv_dist);
    const gz = @floor(wz * inv_dist);
    var d1: f32 = 1e9;
    var d2: f32 = 1e9;
    var dy: f32 = -1.0;
    while (dy <= 1.0) : (dy += 1.0) {
        var dx: f32 = -1.0;
        while (dx <= 1.0) : (dx += 1.0) {
            const cx = gx + dx;
            const cz = gz + dy;
            const h = hash2(@intFromFloat(cx), @intFromFloat(cz), seed);
            const rx = 0.5 + (floatHash(h) - 0.5) * 0.8;
            const rz = 0.5 + (floatHash(h +% 123) - 0.5) * 0.8;
            const sx = (cx + rx) * config.district_size;
            const sz = (cz + rz) * config.district_size;
            const d = @sqrt((wx - sx) * (wx - sx) + (wz - sz) * (wz - sz));
            if (d < d1) {
                d2 = d1;
                d1 = d;
            } else if (d < d2) {
                d2 = d;
            }
        }
    }
    return (d2 - d1) * inv_dist >= config.arterial_width;
}

const GRID_CELL: f32 = 20.0;
const GRID_DIM: usize = 32;
const MAX_PER_CELL: usize = 32;

const TowerGrid = struct {
    cells: [GRID_DIM * GRID_DIM][MAX_PER_CELL]u16,
    counts: [GRID_DIM * GRID_DIM]u8,
    origin_x: f32,
    origin_z: f32,

    fn init(ox: f32, oz: f32) TowerGrid {
        return .{
            .cells = [_][MAX_PER_CELL]u16{[_]u16{0} ** MAX_PER_CELL} ** (GRID_DIM * GRID_DIM),
            .counts = [_]u8{0} ** (GRID_DIM * GRID_DIM),
            .origin_x = ox,
            .origin_z = oz,
        };
    }

    fn cellIdx(self: *const TowerGrid, wx: f32, wz: f32) ?usize {
        const cx: i32 = @intFromFloat(@floor((wx - self.origin_x) / GRID_CELL));
        const cz: i32 = @intFromFloat(@floor((wz - self.origin_z) / GRID_CELL));
        if (cx < 0 or cz < 0 or cx >= GRID_DIM or cz >= GRID_DIM) return null;
        return @as(usize, @intCast(cz)) * GRID_DIM + @as(usize, @intCast(cx));
    }

    fn insert(self: *TowerGrid, idx: u16, wx: f32, wz: f32) void {
        const ci = self.cellIdx(wx, wz) orelse return;
        const cnt = self.counts[ci];
        if (cnt >= MAX_PER_CELL) return;
        self.cells[ci][cnt] = idx;
        self.counts[ci] += 1;
    }

    fn hasNearby(self: *const TowerGrid, pos: []const [2]f32, wx: f32, wz: f32, radius: f32) bool {
        const r2 = radius * radius;
        const n: i32 = @intFromFloat(@ceil(radius / GRID_CELL));
        const cx0: i32 = @intFromFloat(@floor((wx - self.origin_x) / GRID_CELL));
        const cz0: i32 = @intFromFloat(@floor((wz - self.origin_z) / GRID_CELL));
        var dz: i32 = -n;
        while (dz <= n) : (dz += 1) {
            var dx: i32 = -n;
            while (dx <= n) : (dx += 1) {
                const cx = cx0 + dx;
                const cz = cz0 + dz;
                if (cx < 0 or cz < 0 or cx >= GRID_DIM or cz >= GRID_DIM) continue;
                const ci = @as(usize, @intCast(cz)) * GRID_DIM + @as(usize, @intCast(cx));
                for (0..self.counts[ci]) |k| {
                    const t = pos[self.cells[ci][k]];
                    const ddx = wx - t[0];
                    const ddz = wz - t[1];
                    if (ddx * ddx + ddz * ddz < r2) return true;
                }
            }
        }
        return false;
    }
};

const Building = struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,
    h: f32,
    l: f32,
};

const MAX_BUILDINGS: usize = 12_000;

const CityCache = struct {
    buildings: [MAX_BUILDINGS]Building = undefined,
    count: usize = 0,
    last_offset_x: f32 = -1e9,
    last_offset_z: f32 = -1e9,
};

var g_cache: CityCache = .{};

fn push(x: f32, y: f32, z: f32, w: f32, h: f32, l: f32) void {
    if (g_cache.count >= MAX_BUILDINGS) return;
    g_cache.buildings[g_cache.count] = .{ .x = x, .y = y, .z = z, .w = w, .h = h, .l = l };
    g_cache.count += 1;
}

fn rebuildCache(
    terrain: []const f32,
    map_size: usize,
    rendered_size: f32,
    offset_x: f32,
    offset_z: f32,
    cube_base: f32,
    cube_height_scale: f32,
    water_level: f32,
    config: CityConfig,
) void {
    g_cache.count = 0;
    g_cache.last_offset_x = offset_x;
    g_cache.last_offset_z = offset_z;
    const seed: u64 = 777;
    const inv_dist = 1.0 / config.district_size;
    const half_size = rendered_size * 0.5;
    const sub_step = cube_base / @as(f32, @floatFromInt(config.subdivisions));
    const origin_tile_x: i32 = @intFromFloat(@round((offset_x - half_size) / cube_base));
    const origin_tile_z: i32 = @intFromFloat(@round((offset_z - half_size) / cube_base));
    var tgrid = TowerGrid.init(offset_x - half_size, offset_z - half_size);
    var tower_pos: [2048][2]f32 = undefined;
    var tower_count: usize = 0;
    for (0..map_size) |tz| {
        for (0..map_size) |tx| {
            const idx = tz * map_size + tx;
            const terrain_h = terrain[idx] * cube_height_scale;
            if (terrain_h < water_level + config.min_altitude) continue;
            if (terrain_h > water_level + config.max_altitude) continue;
            const tile_wx = @as(f32, @floatFromInt(tx)) * cube_base - half_size + offset_x;
            const tile_wz = @as(f32, @floatFromInt(tz)) * cube_base - half_size + offset_z;
            const noise = valueNoise(tile_wx / config.pocket_scale, tile_wz / config.pocket_scale, seed);
            if (noise < config.pocket_threshold) continue;
            const intensity = (noise - config.pocket_threshold) / (1.0 - config.pocket_threshold);
            if (!inDistrict(tile_wx, tile_wz, inv_dist, config, seed)) continue;
            const wtx = origin_tile_x + @as(i32, @intCast(tx));
            const wtz = origin_tile_z + @as(i32, @intCast(tz));
            var sz: i32 = 0;
            while (sz < config.subdivisions) : (sz += 1) {
                var sx: i32 = 0;
                while (sx < config.subdivisions) : (sx += 1) {
                    const ox = (@as(f32, @floatFromInt(sx)) - @as(f32, @floatFromInt(config.subdivisions - 1)) * 0.5) * sub_step;
                    const oz = (@as(f32, @floatFromInt(sz)) - @as(f32, @floatFromInt(config.subdivisions - 1)) * 0.5) * sub_step;
                    const lot_wx = tile_wx + ox;
                    const lot_wz = tile_wz + oz;
                    const lot_h = hash2(wtx * config.subdivisions + sx, wtz * config.subdivisions + sz, seed);
                    var rng = std.rand.DefaultPrng.init(lot_h);
                    const r = rng.random();
                    const thresh = 1.0 - (config.building_density * (0.3 + 0.7 * intensity));
                    if (r.float(f32) > thresh) {
                        const hb = config.min_building_height + config.max_building_height * intensity * intensity * 2.5;
                        const bh = hb * (0.4 + 0.6 * r.float(f32));
                        if (bh > 1.5 and tower_count < tower_pos.len) {
                            tower_pos[tower_count] = .{ lot_wx, lot_wz };
                            if (tower_count <= std.math.maxInt(u16))
                                tgrid.insert(@intCast(tower_count), lot_wx, lot_wz);
                            tower_count += 1;
                        }
                    }
                }
            }
        }
    }
    const prox = cube_base * 4.0;
    for (0..map_size) |tz| {
        for (0..map_size) |tx| {
            const idx = tz * map_size + tx;
            const terrain_h = terrain[idx] * cube_height_scale;
            if (terrain_h < water_level + config.min_altitude) continue;
            if (terrain_h > water_level + config.max_altitude) continue;
            const tile_wx = @as(f32, @floatFromInt(tx)) * cube_base - half_size + offset_x;
            const tile_wz = @as(f32, @floatFromInt(tz)) * cube_base - half_size + offset_z;
            const noise = valueNoise(tile_wx / config.pocket_scale, tile_wz / config.pocket_scale, seed);
            if (noise < config.pocket_threshold) continue;
            const intensity = (noise - config.pocket_threshold) / (1.0 - config.pocket_threshold);
            if (!inDistrict(tile_wx, tile_wz, inv_dist, config, seed)) continue;
            const wtx = origin_tile_x + @as(i32, @intCast(tx));
            const wtz = origin_tile_z + @as(i32, @intCast(tz));
            var sz: i32 = 0;
            while (sz < config.subdivisions) : (sz += 1) {
                var sx: i32 = 0;
                while (sx < config.subdivisions) : (sx += 1) {
                    const ox = (@as(f32, @floatFromInt(sx)) - @as(f32, @floatFromInt(config.subdivisions - 1)) * 0.5) * sub_step;
                    const oz = (@as(f32, @floatFromInt(sz)) - @as(f32, @floatFromInt(config.subdivisions - 1)) * 0.5) * sub_step;
                    const lot_wx = tile_wx + ox;
                    const lot_wz = tile_wz + oz;
                    const lot_h = hash2(wtx * config.subdivisions + sx, wtz * config.subdivisions + sz, seed);
                    var rng = std.rand.DefaultPrng.init(lot_h);
                    const r = rng.random();
                    const thresh = 1.0 - (config.building_density * (0.3 + 0.7 * intensity));
                    if (r.float(f32) <= thresh) continue;
                    const hb = config.min_building_height + config.max_building_height * intensity * intensity * 2.5;
                    const bh = hb * (0.4 + 0.6 * r.float(f32));
                    const tall = bh > 1.5;
                    if (!tall and !tgrid.hasNearby(tower_pos[0..tower_count], lot_wx, lot_wz, prox)) continue;
                    const fv = 0.3 + r.float(f32) * 0.6;
                    const asp = 0.6 + r.float(f32) * 0.8;
                    var bw = sub_step * fv;
                    var bl = sub_step * fv * asp;
                    if (tall) {
                        bw *= 0.7;
                        bl *= 0.7;
                    }
                    const split = @mod(lot_h, 100);
                    if (split < 20 and bh > 0.8) {
                        const hw = bw * 0.48;
                        const off = bw * 0.25;
                        push(lot_wx - off, terrain_h + bh / 2.0, lot_wz, hw, bh, bl);
                        push(lot_wx + off, terrain_h + bh * 0.7 / 2.0, lot_wz, hw, bh * 0.7, bl);
                    } else if (split >= 20 and split < 35 and bh > 1.2) {
                        const qw = bw * 0.47;
                        const ql = bl * 0.47;
                        const qo = bw * 0.25;
                        const ql2 = bl * 0.25;
                        push(lot_wx - qo, terrain_h + bh / 2.0, lot_wz - ql2, qw, bh, ql);
                        push(lot_wx + qo, terrain_h + bh * 0.8 / 2.0, lot_wz - ql2, qw, bh * 0.8, ql);
                        push(lot_wx - qo, terrain_h + bh * 0.6 / 2.0, lot_wz + ql2, qw, bh * 0.6, ql);
                        push(lot_wx + qo, terrain_h + bh * 0.9 / 2.0, lot_wz + ql2, qw, bh * 0.9, ql);
                    } else {
                        push(lot_wx, terrain_h + bh / 2.0, lot_wz, bw, bh, bl);
                    }
                    if (split >= 35 and split < 60) {
                        const ch = bh * (0.3 + r.float(f32) * 0.4);
                        push(lot_wx + sub_step * 0.6, terrain_h + ch / 2.0, lot_wz, sub_step * 1.2, ch, sub_step * 0.3);
                    } else if (split >= 60 and split < 75) {
                        const ch = bh * (0.3 + r.float(f32) * 0.4);
                        push(lot_wx, terrain_h + ch / 2.0, lot_wz + sub_step * 0.6, sub_step * 0.3, ch, sub_step * 1.2);
                    }
                }
            }
        }
    }
}

pub fn drawCity(
    terrain: []const f32,
    map_size: usize,
    rendered_size: f32,
    offset_x: f32,
    offset_z: f32,
    cube_base: f32,
    cube_height_scale: f32,
    water_level: f32,
    cam_x: f32,
    cam_z: f32,
    config: CityConfig,
) void {
    const ray = @cImport({
        @cInclude("raylib.h");
        @cInclude("rlgl.h");
    });
    if (offset_x != g_cache.last_offset_x or offset_z != g_cache.last_offset_z) {
        rebuildCache(terrain, map_size, rendered_size, offset_x, offset_z, cube_base, cube_height_scale, water_level, config);
    }
    if (g_cache.count == 0) return;
    const LOD_WIN_SQ: f32 = 120.0 * 120.0;
    const CN = ray.Color{ .r = 200, .g = 200, .b = 200, .a = 255 };
    const CS = ray.Color{ .r = 180, .g = 180, .b = 180, .a = 255 };
    const CE = ray.Color{ .r = 170, .g = 170, .b = 170, .a = 255 };
    const CW = ray.Color{ .r = 160, .g = 160, .b = 160, .a = 255 };
    const CT = ray.Color{ .r = 220, .g = 220, .b = 220, .a = 255 };
    const CB = ray.Color{ .r = 140, .g = 140, .b = 140, .a = 255 };
    const CWN = ray.Color{ .r = 45, .g = 50, .b = 55, .a = 255 };
    const CDR = ray.Color{ .r = 40, .g = 30, .b = 20, .a = 255 };
    ray.rlBegin(ray.RL_QUADS);
    for (g_cache.buildings[0..g_cache.count]) |b| {
        const x = b.x;
        const y = b.y;
        const z = b.z;
        const W = b.w;
        const H = b.h;
        const L = b.l;
        const hw = W / 2.0;
        const hh = H / 2.0;
        const hl = L / 2.0;
        const ddx = x - cam_x;
        const ddz = z - cam_z;
        const draw_win = ddx * ddx + ddz * ddz < LOD_WIN_SQ;
        ray.rlColor4ub(CN.r, CN.g, CN.b, 255);
        ray.rlVertex3f(x - hw, y - hh, z + hl);
        ray.rlVertex3f(x - hw, y + hh, z + hl);
        ray.rlVertex3f(x + hw, y + hh, z + hl);
        ray.rlVertex3f(x + hw, y - hh, z + hl);
        ray.rlColor4ub(CS.r, CS.g, CS.b, 255);
        ray.rlVertex3f(x - hw, y - hh, z - hl);
        ray.rlVertex3f(x + hw, y - hh, z - hl);
        ray.rlVertex3f(x + hw, y + hh, z - hl);
        ray.rlVertex3f(x - hw, y + hh, z - hl);
        ray.rlColor4ub(CE.r, CE.g, CE.b, 255);
        ray.rlVertex3f(x + hw, y - hh, z - hl);
        ray.rlVertex3f(x + hw, y - hh, z + hl);
        ray.rlVertex3f(x + hw, y + hh, z + hl);
        ray.rlVertex3f(x + hw, y + hh, z - hl);
        ray.rlColor4ub(CW.r, CW.g, CW.b, 255);
        ray.rlVertex3f(x - hw, y - hh, z - hl);
        ray.rlVertex3f(x - hw, y + hh, z - hl);
        ray.rlVertex3f(x - hw, y + hh, z + hl);
        ray.rlVertex3f(x - hw, y - hh, z + hl);
        ray.rlColor4ub(CT.r, CT.g, CT.b, 255);
        ray.rlVertex3f(x - hw, y + hh, z - hl);
        ray.rlVertex3f(x + hw, y + hh, z - hl);
        ray.rlVertex3f(x + hw, y + hh, z + hl);
        ray.rlVertex3f(x - hw, y + hh, z + hl);
        ray.rlColor4ub(CB.r, CB.g, CB.b, 255);
        ray.rlVertex3f(x - hw, y - hh, z - hl);
        ray.rlVertex3f(x - hw, y - hh, z + hl);
        ray.rlVertex3f(x + hw, y - hh, z + hl);
        ray.rlVertex3f(x + hw, y - hh, z - hl);
        if (draw_win) {
            const wc_z: i32 = @max(1, @min(4, @as(i32, @intFromFloat(W / 0.18))));
            const wc_x: i32 = @max(1, @min(4, @as(i32, @intFromFloat(L / 0.18))));
            const wr: i32 = @max(1, @min(6, @as(i32, @intFromFloat(H / 0.22))));
            emitWin(ray, x, y, z + hl, 1, 0, 0, 1, W, H, wr, wc_z, CWN, CDR, true);
            emitWin(ray, x, y, z - hl, 1, 0, 0, -1, W, H, wr, wc_z, CWN, CDR, false);
            emitWin(ray, x + hw, y, z, 0, 1, 1, 0, L, H, wr, wc_x, CWN, CDR, false);
            emitWin(ray, x - hw, y, z, 0, 1, -1, 0, L, H, wr, wc_x, CWN, CDR, false);
        }
    }
    ray.rlEnd();
}

fn emitWin(
    ray: anytype,
    fx: f32,
    fy: f32,
    fz: f32,
    u_ax: f32,
    u_az: f32,
    n_ax: f32,
    n_az: f32,
    face_w: f32,
    face_h: f32,
    rows: i32,
    cols: i32,
    wcol: anytype,
    dcol: anytype,
    door: bool,
) void {
    const eps: f32 = 0.003;
    const cw = face_w / @as(f32, @floatFromInt(cols));
    const ch = face_h / @as(f32, @floatFromInt(rows));
    const ww = cw * 0.40;
    const wh = ch * 0.45;
    var row: i32 = 0;
    while (row < rows) : (row += 1) {
        if (row == 0 and rows > 1) continue;
        const rt = (@as(f32, @floatFromInt(row)) + 0.5) / @as(f32, @floatFromInt(rows));
        const wy = fy - face_h * 0.5 + rt * face_h;
        var col: i32 = 0;
        while (col < cols) : (col += 1) {
            const ct = (@as(f32, @floatFromInt(col)) + 0.5) / @as(f32, @floatFromInt(cols));
            const wu = (ct - 0.5) * face_w;
            const wx2 = fx + u_ax * wu + n_ax * eps;
            const wz2 = fz + u_az * wu + n_az * eps;
            const hw2 = ww * 0.5;
            const hh2 = wh * 0.5;
            ray.rlColor4ub(wcol.r, wcol.g, wcol.b, wcol.a);
            ray.rlVertex3f(wx2 - u_ax * hw2, wy - hh2, wz2 - u_az * hw2);
            ray.rlVertex3f(wx2 - u_ax * hw2, wy + hh2, wz2 - u_az * hw2);
            ray.rlVertex3f(wx2 + u_ax * hw2, wy + hh2, wz2 + u_az * hw2);
            ray.rlVertex3f(wx2 + u_ax * hw2, wy - hh2, wz2 + u_az * hw2);
        }
    }
    if (door) {
        const dw = cw * 0.50;
        const dh = ch * 0.70;
        const dy = fy - face_h * 0.5 + dh * 0.5;
        const dx2 = fx + n_ax * eps;
        const dz2 = fz + n_az * eps;
        const hdw = dw * 0.5;
        ray.rlColor4ub(dcol.r, dcol.g, dcol.b, dcol.a);
        ray.rlVertex3f(dx2 - u_ax * hdw, dy - dh * 0.5, dz2 - u_az * hdw);
        ray.rlVertex3f(dx2 - u_ax * hdw, dy + dh * 0.5, dz2 - u_az * hdw);
        ray.rlVertex3f(dx2 + u_ax * hdw, dy + dh * 0.5, dz2 + u_az * hdw);
        ray.rlVertex3f(dx2 + u_ax * hdw, dy - dh * 0.5, dz2 + u_az * hdw);
    }
}
