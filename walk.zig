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
const ray = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
    @cInclude("rlgl.h");
});
const terrain_gen = @import("terrain.zig");
const object_gen = @import("object.zig");
const dungeon_gen = @import("dungeon.zig");

const build_config = @import("config");
const WINDOW_WIDTH: i32 = build_config.window_width;
const WINDOW_HEIGHT: i32 = build_config.window_height;

var CUBE_BASE: f32 = 1.0;
var CUBE_HEIGHT: f32 = 20.0;

export fn set_phys_cfg(base: f32, height: f32) void {
    CUBE_BASE = base;
    CUBE_HEIGHT = height;
    if (lib_instance) |state| {
        state.map.rendered_size = @as(f32, @floatFromInt(state.map.size - 1)) * CUBE_BASE;
    }
}

fn getSeed() u64 {
    return @as(u64, @intCast(std.time.timestamp()));
}

//}}} INIT
//{{{ USR

const User = struct {
    camera: ray.Camera3D,
    mode: enum { fpv, tpv, non },
    init_pos: ray.Vector3,
    init_tgt: ray.Vector3,
    height: f32,

    fn init(size: usize) User {
        ray.EnableCursor();
        const physical_size = @as(f32, @floatFromInt(size - 1)) * CUBE_BASE;
        const dist = physical_size * 0.8;
        const init_pos = ray.Vector3{ .x = dist, .y = dist, .z = dist };
        const init_tgt = ray.Vector3{ .x = 0.0, .y = -dist * 0.2, .z = 0.0 };
        return .{
            .camera = ray.Camera3D{
                .position = init_pos,
                .target = init_tgt,
                .up = .{ .x = 0.0, .y = 1.0, .z = 0.0 },
                .fovy = 45.0,
                .projection = ray.CAMERA_PERSPECTIVE,
            },
            .mode = .tpv,
            .init_pos = init_pos,
            .init_tgt = init_tgt,
            .height = 0.7,
        };
    }

    fn update(self: *User, map: *Map) void {
        switch (self.mode) {
            .fpv => {
                const old_pos = self.camera.position;
                ray.UpdateCamera(&self.camera, ray.CAMERA_FIRST_PERSON);
                if (map.getY(.{ self.camera.position.x, self.camera.position.z })) |h| {
                    self.camera.position.y = h + self.height;
                } else {
                    self.camera.position = old_pos;
                }
            },
            .tpv => {
                const wheel = ray.GetMouseWheelMove();
                if (wheel != 0) self.zoom(wheel);
                // self.orbit();
            },
            else => return,
        }
    }

    fn spawn(self: *User, pos: ray.Vector3) void {
        self.camera.position = .{ .x = pos.x, .y = pos.y + self.height, .z = pos.z };
        self.camera.target = .{ .x = 0.0, .y = pos.y + self.height, .z = 0.0 };
        ray.DisableCursor();
        self.mode = .fpv;
    }

    fn orbit(self: *User) void {
        const sens = 0.003;
        const delta = ray.GetMouseDelta();
        const r = std.math.sqrt(self.camera.position.x * self.camera.position.x + self.camera.position.y * self.camera.position.y + self.camera.position.z * self.camera.position.z);
        var ax = std.math.asin(self.camera.position.y / r);
        var ay = std.math.atan2(self.camera.position.z, self.camera.position.x);
        ax = std.math.clamp(ax + delta.y * sens, -std.math.pi / 3.0, std.math.pi / 3.0);
        ay -= delta.x * sens;
        self.camera.position.x = @cos(ay) * @cos(ax) * r;
        self.camera.position.y = @sin(ax) * r;
        self.camera.position.z = @sin(ay) * @cos(ax) * r;
        self.camera.target = self.init_tgt;
    }

    fn zoom(self: *User, amount: f32) void {
        const f = 1.0 - amount * 0.05;
        self.camera.position.x *= f;
        self.camera.position.y *= f;
        self.camera.position.z *= f;
    }

    fn reset(self: *User) void {
        self.camera.position = self.init_pos;
        self.camera.target = self.init_tgt;
        self.camera.projection = ray.CAMERA_PERSPECTIVE;
        ray.EnableCursor();
        self.mode = .tpv;
    }
};

export fn get_user_status(x: *f32, y: *f32, z: *f32) bool {
    if (lib_instance) |state| {
        if (state.user.mode == .fpv) {
            x.* = state.user.camera.position.x;
            y.* = state.user.camera.position.y;
            z.* = state.user.camera.position.z;
            return true;
        }
    }
    return false;
}

export fn get_camera_transform(px: *f32, py: *f32, pz: *f32, tx: *f32, ty: *f32, tz: *f32, ux: *f32, uy: *f32, uz: *f32, mode: *i32) void {
    if (lib_instance) |state| {
        px.* = state.user.camera.position.x;
        py.* = state.user.camera.position.y;
        pz.* = state.user.camera.position.z;
        tx.* = state.user.camera.target.x;
        ty.* = state.user.camera.target.y;
        tz.* = state.user.camera.target.z;
        ux.* = state.user.camera.up.x;
        uy.* = state.user.camera.up.y;
        uz.* = state.user.camera.up.z;
        mode.* = @intFromEnum(state.user.mode);
    }
}

export fn set_camera_transform(px: f32, py: f32, pz: f32, tx: f32, ty: f32, tz: f32, ux: f32, uy: f32, uz: f32, mode: i32) void {
    if (lib_instance) |state| {
        state.user.camera.position = .{ .x = px, .y = py, .z = pz };
        state.user.camera.target = .{ .x = tx, .y = ty, .z = tz };
        state.user.camera.up = .{ .x = ux, .y = uy, .z = uz };
        state.user.mode = @enumFromInt(mode);
    }
}

//}}} USR
//{{{ OBJ

const Object = struct {
    id: i32,
    obj_type: union(object_gen.ObjectType) {
        Beam,
        Rock,
        Tree,
        House,
        Bird,
        Rain,
        Human,
        Custom: object_gen.Kwargs,
        Model: ModelData,
    },
    x: f32,
    z: f32,
    y_offset: f32,
    rotation: ray.Vector3 = .{ .x = 0, .y = 0, .z = 0 },
    target_x: ?f32 = null,
    target_z: ?f32 = null,
    speed: f32 = 5.0,
    state: f32 = 0.0,
    is_terrain_bound: bool = true,

    const ModelData = struct {
        model: *ray.Model,
        scale: f32,
        tint: ray.Color,
    };

    pub fn draw(self: *const Object, map: *Map, t: f32) void {
        const world_y = if (self.is_terrain_bound)
            (map.getY(.{ self.x, self.z }) orelse return) + self.y_offset
        else
            self.y_offset;
        const world_pos = ray.Vector3{ .x = self.x, .y = world_y, .z = self.z };
        const custom_args = switch (self.obj_type) {
            .Custom => |args| args,
            else => null,
        };
        const model_params = switch (self.obj_type) {
            .Model => |data| object_gen.ObjectType.ModelParams{
                .model = data.model.*,
                .scale = data.scale,
                .tint = data.tint,
            },
            else => null,
        };
        object_gen.drawObject(self.obj_type, world_pos, self.rotation, t * self.state, custom_args, model_params);
    }

    pub fn deinit(self: *Object) void {
        _ = self;
    }

    pub fn update(self: *Object, dt: f32, others: *std.AutoHashMap(i32, Object)) void {
        if (self.target_x) |tx| {
            const tz = self.target_z.?;
            const dx = tx - self.x;
            const dz = tz - self.z;
            const dist_sq = dx * dx + dz * dz;
            if (dist_sq < 0.01) {
                self.target_x = null;
                self.target_z = null;
                return;
            }
            const dist = @sqrt(dist_sq);
            const move_amount = self.speed * dt;
            self.x += (dx / dist) * move_amount;
            self.z += (dz / dist) * move_amount;
            self.rotation.y = std.math.atan2(dx, dz) * (180.0 / std.math.pi);
        }
        var it = others.valueIterator();
        while (it.next()) |other| {
            if (other.id == self.id) continue;
            const dx = self.x - other.x;
            const dz = self.z - other.z;
            const dist_sq = dx * dx + dz * dz;
            if (dist_sq < 1.0) {
                const dist = @sqrt(dist_sq);
                if (dist > 0.0001) {
                    const push = (1.0 - dist) * 5.0 * dt;
                    self.x += (dx / dist) * push;
                    self.z += (dz / dist) * push;
                }
            }
        }
    }
};

fn getOrLoadModel(state: *State, path_slice: []const u8, rot: ray.Vector3, trans: ray.Vector3) !*ray.Model {
    if (state.model_cache.getPtr(path_slice)) |model_ptr| {
        return model_ptr;
    }
    const key = try state.allocator.dupe(u8, path_slice);
    errdefer state.allocator.free(key);
    const c_path = try state.allocator.allocSentinel(u8, path_slice.len, 0);
    defer state.allocator.free(c_path);
    @memcpy(c_path, path_slice);
    var model = ray.LoadModel(c_path);
    if (model.meshCount == 0) {
        return error.ModelLoadFailed;
    }
    const mat_rot = ray.MatrixRotateXYZ(rot);
    const mat_trans = ray.MatrixTranslate(trans.x, trans.y, trans.z);
    const mat_fix = ray.MatrixMultiply(mat_rot, mat_trans);
    model.transform = ray.MatrixMultiply(model.transform, mat_fix);
    try state.model_cache.put(key, model);
    return state.model_cache.getPtr(key).?;
}

export fn spawn_object_by_name(id: i32, type_name: [*c]const u8, x: f32, z: f32, y_off: f32) void {
    if (lib_instance) |state| {
        const name_slice = std.mem.span(type_name);
        const tag = std.meta.stringToEnum(object_gen.ObjectType, name_slice) orelse .Rock;
        const obj = Object{
            .id = id,
            .obj_type = switch (tag) {
                .Custom => .{ .Custom = .{ .shape = .Cube } },
                .Model => .{ .Model = .{ .model = undefined, .scale = 1.0, .tint = ray.WHITE } },
                inline else => |t| @unionInit(@TypeOf(@as(Object, undefined).obj_type), @tagName(t), {}),
            },
            .x = x,
            .z = z,
            .y_offset = y_off,
        };
        state.objects.put(id, obj) catch {};
    }
}

export fn set_object_rotation(id: i32, pitch: f32, yaw: f32, roll: f32) void {
    if (lib_instance) |state| {
        if (state.objects.getPtr(id)) |obj| {
            obj.rotation = .{ .x = pitch, .y = yaw, .z = roll };
        }
    }
}

export fn spawn_custom_mesh(id: i32, shape_idx: i32, x: f32, y_offset: f32, z: f32, radius: f32, width: f32, height: f32, r: i32, g: i32, b: i32) void {
    if (lib_instance) |state| {
        const obj = Object{
            .id = id,
            .obj_type = .{
                .Custom = .{
                    .shape = @enumFromInt(shape_idx),
                    .radius = radius,
                    .width = width,
                    .height = height,
                    .color = .{ .r = @intCast(r), .g = @intCast(g), .b = @intCast(b), .a = 255 },
                },
            },
            .x = x,
            .z = z,
            .y_offset = y_offset,
        };
        state.objects.put(id, obj) catch {};
    }
}

export fn spawn_object(id: i32, type_id: i32, x: f32, z: f32, y_off: f32) void {
    if (lib_instance) |state| {
        const tag: object_gen.ObjectType = @enumFromInt(type_id);
        const obj = Object{
            .id = id,
            .obj_type = switch (tag) {
                .Custom => .{ .Custom = .{} },
                .Model => .{ .Model = .{ .model = undefined, .scale = 1.0, .tint = ray.WHITE } },
                .Human => .Human,
                .Rain => .Rain,
                .Bird => .Bird,
                .House => .House,
                .Tree => .Tree,
                .Rock => .Rock,
                .Beam => .Beam,
            },
            .x = x,
            .z = z,
            .y_offset = y_off,
        };
        state.objects.put(id, obj) catch {};
    }
}

export fn spawn_glb_model(
    id: i32,
    path_ptr: [*:0]const u8,
    x: f32,
    z: f32,
    y_off: f32,
    scale: f32,
    rot_x: f32,
    rot_y: f32,
    rot_z: f32,
    off_x: f32,
    off_y: f32,
    off_z: f32,
    r: u8,
    g: u8,
    b: u8,
) void {
    if (lib_instance) |state| {
        const path = std.mem.span(path_ptr);

        const model_ptr = getOrLoadModel(state, path, .{ .x = rot_x, .y = rot_y, .z = rot_z }, .{ .x = off_x, .y = off_y, .z = off_z }) catch |err| {
            std.debug.print("Failed to load model {s}: {}\n", .{ path, err });
            return;
        };

        const obj = Object{
            .id = id,
            .obj_type = .{
                .Model = .{
                    .model = model_ptr,
                    .scale = scale,
                    .tint = ray.Color{ .r = r, .g = g, .b = b, .a = 255 },
                },
            },
            .x = x,
            .z = z,
            .y_offset = y_off,
        };
        state.objects.put(id, obj) catch {};
    }
}

export fn update_object_model(id: i32, path_ptr: [*:0]const u8) void {
    if (lib_instance) |state| {
        if (state.objects.getPtr(id)) |obj| {
            switch (obj.obj_type) {
                .Model => |*data| {
                    const path = std.mem.span(path_ptr);
                    if (getOrLoadModel(state, path, .{ .x = 0, .y = 0, .z = 0 }, .{ .x = 0, .y = 0, .z = 0 })) |new_ptr| {
                        data.model = new_ptr;
                    } else |_| {}
                },
                else => {},
            }
        }
    }
}

export fn despawn_object(id: i32) void {
    if (lib_instance) |state| {
        if (state.objects.fetchRemove(id)) |kv| {
            var obj = kv.value;
            obj.deinit();
        }
    }
}

export fn get_object_position(id: i32, x: *f32, z: *f32, y_off: *f32) bool {
    if (lib_instance) |state| {
        if (state.objects.get(id)) |obj| {
            x.* = obj.x;
            z.* = obj.z;
            y_off.* = obj.y_offset;
            return true;
        }
    }
    return false;
}

export fn set_object_terrain_bound(id: i32, bound: bool) void {
    if (lib_instance) |state| {
        if (state.objects.getPtr(id)) |obj| {
            obj.is_terrain_bound = bound;
        }
    }
}

export fn set_object_position(id: i32, x: f32, z: f32, y_off: f32) void {
    if (lib_instance) |state| {
        if (state.objects.getPtr(id)) |obj| {
            obj.x = x;
            obj.z = z;
            obj.y_offset = y_off;
        }
    }
}

export fn set_object_state(id: i32, state_val: f32) void {
    if (lib_instance) |state| {
        if (state.objects.getPtr(id)) |obj| {
            obj.state = state_val;
        }
    }
}

export fn set_object_target(id: i32, target_x: f32, target_z: f32, speed: f32) void {
    if (lib_instance) |state| {
        if (state.objects.getPtr(id)) |obj| {
            obj.target_x = target_x;
            obj.target_z = target_z;
            obj.speed = speed;
        }
    }
}

export fn stop_object(id: i32) void {
    if (lib_instance) |state| {
        if (state.objects.getPtr(id)) |obj| {
            obj.target_x = null;
            obj.target_z = null;
        }
    }
}

//}}} OBJ
//{{{ MAP

const city_gen = @import("city.zig");

const Map = struct {
    allocator: std.mem.Allocator,
    size: usize,
    rendered_size: f32,
    seed: u64,
    terrain: []f32,
    base_map: ?[]f32,
    model: ray.Model,
    image: ray.Image,
    texture: ray.Texture,
    water_level: f32,
    noise_weight: f32,
    texture_scale: f32,
    octaves: u8 = 6,
    persistence: f32 = 0.5,
    lacunarity: f32 = 2.0,
    fbm_scale: f32 = 50.0,
    world_offset_x: f32 = 0.0,
    world_offset_z: f32 = 0.0,
    city: ?city_gen.CityConfig = null,

    pub fn init(allocator: std.mem.Allocator, size: usize, seed: u64) !Map {
        var self = Map{
            .allocator = allocator,
            .size = size,
            .rendered_size = @as(f32, @floatFromInt(size - 1)) * CUBE_BASE,
            .seed = seed,
            .terrain = &.{},
            .base_map = null,
            .model = std.mem.zeroes(ray.Model),
            .image = std.mem.zeroes(ray.Image),
            .texture = std.mem.zeroes(ray.Texture),
            .water_level = -2.0,
            .noise_weight = 0.9,
            .texture_scale = 1.0,
        };
        const initial_mesh = ray.GenMeshPlane(self.rendered_size, self.rendered_size, @intCast(size - 1), @intCast(size - 1));
        self.model = ray.LoadModelFromMesh(initial_mesh);
        if (seed == 0) {
            self.base_map = null;
            // self.base_map = try getDungeon(allocator, 142, size, 4, @enumFromInt(1)); //[] ad hoc
        }
        try self.spawn(seed);
        return self;
    }

    pub fn deinit(self: *Map) void {
        self.unloadResources();
        if (self.base_map) |base| self.allocator.free(base);
    }

    fn unloadResources(self: *Map) void {
        if (self.model.meshCount > 0) {
            ray.UnloadModel(self.model);
            self.model = std.mem.zeroes(ray.Model);
        }
        if (self.texture.id > 0) {
            ray.UnloadTexture(self.texture);
            self.texture = std.mem.zeroes(ray.Texture);
        }
        if (self.image.data != null) {
            ray.UnloadImage(self.image);
            self.image = std.mem.zeroes(ray.Image);
        }
        if (self.terrain.len > 0) {
            self.allocator.free(self.terrain);
            self.terrain = &.{};
        }
    }

    pub fn spawn(self: *Map, seed: u64) !void {
        const half_size = self.rendered_size * 0.5;
        const config = terrain_gen.TerrainConfig{
            .seed = seed,
            .size = self.size,
            .base_map = self.base_map,
            .noise_weight = self.noise_weight,
            .octaves = self.octaves,
            .persistence = self.persistence,
            .lacunarity = self.lacunarity,
            .scale = self.fbm_scale,
            .world_start_x = self.world_offset_x - half_size,
            .world_start_z = self.world_offset_z - half_size,
            .world_step = CUBE_BASE,
        };
        const new_terrain = try terrain_gen.generateTerrain(self.allocator, config);
        self.allocator.free(self.terrain);
        self.terrain = new_terrain;
        var mesh = self.model.meshes[0];
        for (0..self.size) |z| {
            for (0..self.size) |x| {
                const idx = z * self.size + x;
                const fx = @as(f32, @floatFromInt(x)) * CUBE_BASE;
                const fz = @as(f32, @floatFromInt(z)) * CUBE_BASE;
                mesh.vertices[idx * 3] = fx - half_size;
                mesh.vertices[idx * 3 + 1] = self.terrain[idx] * CUBE_HEIGHT;
                mesh.vertices[idx * 3 + 2] = fz - half_size;
            }
        }
        const v_count: i32 = @intCast(mesh.vertexCount);
        ray.UpdateMeshBuffer(mesh, 0, mesh.vertices, v_count * 3 * @sizeOf(f32), 0);
        self.update();
        self.seed = seed;
    }

    pub fn update(self: *Map) void {
        const new_w: i32 = @intFromFloat(@as(f32, @floatFromInt(self.size - 1)) * self.texture_scale);
        const resized = (self.image.width != new_w) or (self.image.data == null);
        if (resized) {
            const new_image = ray.GenImageColor(new_w, new_w, ray.BLANK);
            const pixels: []terrain_gen.Color = @as([*]terrain_gen.Color, @ptrCast(@alignCast(new_image.data)))[0..@intCast(new_w * new_w)];
            terrain_gen.writeTextureBuffer(pixels, self.terrain, self.size, self.texture_scale, self.water_level, CUBE_HEIGHT);
            const new_texture = ray.LoadTextureFromImage(new_image);
            ray.SetTextureFilter(new_texture, ray.TEXTURE_FILTER_POINT);
            if (self.model.materialCount > 0) self.model.materials[0].maps[ray.MATERIAL_MAP_DIFFUSE].texture = new_texture;
            if (self.image.data != null) ray.UnloadImage(self.image);
            if (self.texture.id > 0) ray.UnloadTexture(self.texture);
            self.image = new_image;
            self.texture = new_texture;
        } else {
            const pixels: []terrain_gen.Color = @as([*]terrain_gen.Color, @ptrCast(@alignCast(self.image.data)))[0..@intCast(new_w * new_w)];
            terrain_gen.writeTextureBuffer(pixels, self.terrain, self.size, self.texture_scale, self.water_level, CUBE_HEIGHT);
            ray.UpdateTexture(self.texture, self.image.data);
        }
    }

    pub fn draw(self: *Map, cam_x: f32, cam_z: f32) void {
        ray.DrawModel(self.model, .{ .x = self.world_offset_x, .y = 0, .z = self.world_offset_z }, 1.0, ray.WHITE);
        ray.DrawCube(.{ .x = self.world_offset_x, .y = self.water_level, .z = self.world_offset_z }, self.rendered_size, 0.1, self.rendered_size, ray.ColorAlpha(ray.SKYBLUE, 0.5));
        if (self.city) |cfg| {
            city_gen.drawCity(self.terrain, self.size, self.rendered_size, self.world_offset_x, self.world_offset_z, CUBE_BASE, CUBE_HEIGHT, self.water_level, cam_x, cam_z, cfg);
        }
    }

    fn getY(self: *Map, world_xz: @Vector(2, f32)) ?f32 {
        const half_size = self.rendered_size * 0.5;
        const local_x = world_xz[0] - self.world_offset_x;
        const local_z = world_xz[1] - self.world_offset_z;
        const local_v = @Vector(2, f32){ local_x, local_z };
        const g_xz = (local_v + @as(@Vector(2, f32), @splat(half_size))) / @as(@Vector(2, f32), @splat(CUBE_BASE));
        const raw_h = terrain_gen.getBilinearHeight(self.terrain, g_xz, self.size) orelse return null;
        return raw_h * CUBE_HEIGHT;
    }
};

export fn load_map_data(data: [*]const f32, len: usize) void {
    if (lib_instance) |state| {
        if (state.map.base_map) |base| {
            if (len == base.len) {
                @memcpy(base, data[0..len]);
                state.map.spawn(state.map.seed) catch {};
            }
        }
    }
}

export fn get_terrain_height(world_x: f32, world_z: f32) f32 {
    if (lib_instance) |state| {
        if (state.map.getY(.{ world_x, world_z })) |h| {
            return h;
        }
    }
    return 0.0;
}

export fn set_map_cfg(water: f32, noise: f32, tex_scale: f32, seed: u64, spawn: bool) void {
    if (lib_instance) |state| {
        state.map.water_level = water;
        state.map.noise_weight = noise;
        state.map.texture_scale = tex_scale;
        state.map.seed = seed;
        if (spawn) {
            state.map.spawn(state.map.seed) catch {};
        } else {
            state.map.update();
        }
    }
}

export fn set_fbm_cfg(octaves: i32, persistence: f32, lacunarity: f32, scale: f32) void {
    if (lib_instance) |state| {
        state.map.octaves = @intCast(octaves);
        state.map.persistence = persistence;
        state.map.lacunarity = lacunarity;
        state.map.fbm_scale = scale;
    }
}

export fn set_world_offset(x: f32, z: f32) void {
    if (lib_instance) |state| {
        state.map.world_offset_x = x;
        state.map.world_offset_z = z;
        state.map.spawn(state.map.seed) catch {};
    }
}

export fn set_city_cfg(num_sites: i32, num_pockets: i32, enabled: bool) void {
    if (lib_instance) |state| {
        if (enabled) {
            const f_sites = @max(1.0, @as(f32, @floatFromInt(num_sites)));
            const f_pockets = @max(1.0, @as(f32, @floatFromInt(num_pockets)));
            const dist_size = 800.0 / (f_sites + 10.0);
            const p_scale = f_pockets * 15.0;
            state.map.city = city_gen.CityConfig{
                .district_size = dist_size,
                .pocket_scale = p_scale,
                .pocket_threshold = 0.4,
                .arterial_width = 0.12,
                .subdivisions = 3,
                .building_density = 0.8,
                .min_building_height = 0.2,
                .max_building_height = 4.0,
                .min_altitude = 0.5,
                .max_altitude = 15.0,
            };
        } else {
            state.map.city = null;
        }
    }
}

export fn set_dungeon_map(seed: u64, type_idx: i32, magnify: i32) void {
    if (lib_instance) |state| {
        const d_type: @import("dungeon.zig").DungeonType = @enumFromInt(type_idx);
        if (getDungeon(state.allocator, seed, state.map.size, @intCast(magnify), d_type)) |new_map| {
            if (state.map.base_map) |old| {
                state.allocator.free(old);
            }
            state.map.base_map = new_map;
            state.map.spawn(state.map.seed) catch {};
        } else |_| {
            std.debug.print("Failed to generate dungeon map.\n", .{});
        }
    }
}

//}}} MAP
//{{{ HUD

const GizmoOp = enum(u8) {
    Text2D = 1,
    Rect2D = 2,
    RectLine2D = 3,
    Line2D = 4,
    Circle2D = 5,
    CircleLine2D = 6,
    Triangle2D = 7,
    Line3D = 10,
    Cube3D = 11,
    Sphere3D = 12,
    Cylinder3D = 13,
};

var gizmo_buffer: [128 * 1024]u8 = undefined;
var gizmo_len: usize = 0;

export fn submit_gizmo_buffer(ptr: [*]const u8, len: usize) void {
    const safe_len = @min(len, gizmo_buffer.len);
    @memcpy(gizmo_buffer[0..safe_len], ptr[0..safe_len]);
    gizmo_len = safe_len;
}

fn readInt(reader: anytype, comptime T: type) !T {
    return reader.readInt(T, .little);
}

fn readFloat(reader: anytype) !f32 {
    const bits = try reader.readInt(u32, .little);
    return @bitCast(bits);
}

fn readColor(reader: anytype) !ray.Color {
    const r = try reader.readByte();
    const g = try reader.readByte();
    const b = try reader.readByte();
    const a = try reader.readByte();
    return ray.Color{ .r = r, .g = g, .b = b, .a = a };
}

fn render_gizmos(phase: enum { World3D, Screen2D }) void {
    var fbs = std.io.fixedBufferStream(gizmo_buffer[0..gizmo_len]);
    var reader = fbs.reader();

    while (true) {
        const op_byte = reader.readByte() catch break;
        const op: GizmoOp = @enumFromInt(op_byte);
        switch (op) {
            .Text2D => {
                const x = readFloat(reader) catch break;
                const y = readFloat(reader) catch break;
                const size = readInt(reader, i32) catch break;
                const color = readColor(reader) catch break;
                const len = reader.readByte() catch break;
                if (phase == .Screen2D) {
                    var buf: [256]u8 = undefined;
                    const safe_len = @min(len, 255);
                    _ = reader.read(buf[0..safe_len]) catch break;
                    buf[safe_len] = 0;
                    ray.DrawText(@ptrCast(&buf), @intFromFloat(x), @intFromFloat(y), size, color);
                    if (len > 255) fbs.seekBy(len - 255) catch break;
                } else {
                    fbs.seekBy(len) catch break;
                }
            },
            .Rect2D => {
                const x = readFloat(reader) catch break;
                const y = readFloat(reader) catch break;
                const w = readFloat(reader) catch break;
                const h = readFloat(reader) catch break;
                const color = readColor(reader) catch break;
                if (phase == .Screen2D) ray.DrawRectangle(@intFromFloat(x), @intFromFloat(y), @intFromFloat(w), @intFromFloat(h), color);
            },
            .RectLine2D => {
                const x = readFloat(reader) catch break;
                const y = readFloat(reader) catch break;
                const w = readFloat(reader) catch break;
                const h = readFloat(reader) catch break;
                const thick = readFloat(reader) catch break;
                const color = readColor(reader) catch break;
                if (phase == .Screen2D) ray.DrawRectangleLinesEx(.{ .x = x, .y = y, .width = w, .height = h }, thick, color);
            },
            .Line2D => {
                const x1 = readFloat(reader) catch break;
                const y1 = readFloat(reader) catch break;
                const x2 = readFloat(reader) catch break;
                const y2 = readFloat(reader) catch break;
                const thick = readFloat(reader) catch break;
                const color = readColor(reader) catch break;
                if (phase == .Screen2D) ray.DrawLineEx(.{ .x = x1, .y = y1 }, .{ .x = x2, .y = y2 }, thick, color);
            },
            .Circle2D => {
                const x = readFloat(reader) catch break;
                const y = readFloat(reader) catch break;
                const r = readFloat(reader) catch break;
                const color = readColor(reader) catch break;
                if (phase == .Screen2D) ray.DrawCircle(@intFromFloat(x), @intFromFloat(y), r, color);
            },
            .CircleLine2D => {
                const x = readFloat(reader) catch break;
                const y = readFloat(reader) catch break;
                const r = readFloat(reader) catch break;
                const thick = readFloat(reader) catch break;
                const color = readColor(reader) catch break;
                if (phase == .Screen2D) ray.DrawRing(.{ .x = x, .y = y }, r - thick, r, 0, 360, 32, color);
            },
            .Triangle2D => {
                const x1 = readFloat(reader) catch break;
                const y1 = readFloat(reader) catch break;
                const x2 = readFloat(reader) catch break;
                const y2 = readFloat(reader) catch break;
                const x3 = readFloat(reader) catch break;
                const y3 = readFloat(reader) catch break;
                const color = readColor(reader) catch break;
                if (phase == .Screen2D) ray.DrawTriangle(.{ .x = x1, .y = y1 }, .{ .x = x2, .y = y2 }, .{ .x = x3, .y = y3 }, color);
            },
            .Line3D => {
                const x1 = readFloat(reader) catch break;
                const y1 = readFloat(reader) catch break;
                const z1 = readFloat(reader) catch break;
                const x2 = readFloat(reader) catch break;
                const y2 = readFloat(reader) catch break;
                const z2 = readFloat(reader) catch break;
                const color = readColor(reader) catch break;
                if (phase == .World3D) ray.DrawLine3D(.{ .x = x1, .y = y1, .z = z1 }, .{ .x = x2, .y = y2, .z = z2 }, color);
            },
            .Cube3D => {
                const x = readFloat(reader) catch break;
                const y = readFloat(reader) catch break;
                const z = readFloat(reader) catch break;
                const tx = readFloat(reader) catch break;
                const ty = readFloat(reader) catch break;
                const tz = readFloat(reader) catch break;
                const thick = readFloat(reader) catch break;
                const color = readColor(reader) catch break;
                if (phase == .World3D) {
                    object_gen.drawShape(.{ .x = x, .y = y, .z = z }, .{ .x = tx, .y = ty, .z = tz }, .{ .shape = .Cube, .radius = thick, .color = color });
                }
            },
            .Sphere3D => {
                const x = readFloat(reader) catch break;
                const y = readFloat(reader) catch break;
                const z = readFloat(reader) catch break;
                const rad = readFloat(reader) catch break;
                const color = readColor(reader) catch break;
                if (phase == .World3D) ray.DrawSphere(.{ .x = x, .y = y, .z = z }, rad, color);
            },
            .Cylinder3D => {
                const x = readFloat(reader) catch break;
                const y = readFloat(reader) catch break;
                const z = readFloat(reader) catch break;
                const tx = readFloat(reader) catch break;
                const ty = readFloat(reader) catch break;
                const tz = readFloat(reader) catch break;
                const thick = readFloat(reader) catch break;
                const color = readColor(reader) catch break;
                if (phase == .World3D) {
                    object_gen.drawShape(.{ .x = x, .y = y, .z = z }, .{ .x = tx, .y = ty, .z = tz }, .{ .shape = .Cylinder, .radius = thick, .color = color });
                }
            },
        }
    }
}

fn render_overlays_2d() void {
    render_gizmos(.Screen2D);
}

fn render_overlays_3d() void {
    render_gizmos(.World3D);
}

//}}} HUD
//{{{ INP

const Input = struct {
    state: *State,

    last_ground_click: ?ray.Vector3 = null,
    selection_start: ray.Vector2 = .{ .x = 0, .y = 0 },
    is_selecting: bool = false,
    selected_units: std.ArrayList(i32),
    const bindings = [_]struct {
        input: union(enum) { key: i32, mouse: i32 },
        trigger: enum { Press, Hold, Release },
        handler: *const fn (self: *Input) void,
        pub fn isTriggered(self: @This()) bool {
            switch (self.input) {
                .key => |k| switch (self.trigger) {
                    .Press => return ray.IsKeyPressed(k),
                    .Hold => return ray.IsKeyDown(k),
                    .Release => return ray.IsKeyReleased(k),
                },
                .mouse => |m| switch (self.trigger) {
                    .Press => return ray.IsMouseButtonPressed(m),
                    .Hold => return ray.IsMouseButtonDown(m),
                    .Release => return ray.IsMouseButtonReleased(m),
                },
            }
        }
    }{
        .{ .input = .{ .mouse = ray.MOUSE_BUTTON_RIGHT }, .trigger = .Press, .handler = onRegenerate },
        .{ .input = .{ .key = ray.KEY_COMMA }, .trigger = .Hold, .handler = onWaterDown },
        .{ .input = .{ .key = ray.KEY_PERIOD }, .trigger = .Hold, .handler = onWaterUp },
        .{ .input = .{ .key = ray.KEY_LEFT_BRACKET }, .trigger = .Hold, .handler = onRoughnessDown },
        .{ .input = .{ .key = ray.KEY_RIGHT_BRACKET }, .trigger = .Hold, .handler = onRoughnessUp },
        .{ .input = .{ .key = ray.KEY_F }, .trigger = .Press, .handler = onTextureScaleUp },
        .{ .input = .{ .key = ray.KEY_C }, .trigger = .Press, .handler = onTextureScaleDown },
        .{ .input = .{ .key = ray.KEY_D }, .trigger = .Hold, .handler = onSkyLighter },
        .{ .input = .{ .key = ray.KEY_N }, .trigger = .Hold, .handler = onSkyDarker },
        .{ .input = .{ .key = ray.KEY_Z }, .trigger = .Press, .handler = onResetCamera },
        .{ .input = .{ .mouse = ray.MOUSE_BUTTON_LEFT }, .trigger = .Press, .handler = onStartSelection },
        .{ .input = .{ .mouse = ray.MOUSE_BUTTON_LEFT }, .trigger = .Hold, .handler = onUpdateSelection },
        .{ .input = .{ .mouse = ray.MOUSE_BUTTON_LEFT }, .trigger = .Release, .handler = onEndSelection },
        .{ .input = .{ .mouse = ray.MOUSE_BUTTON_MIDDLE }, .trigger = .Press, .handler = onToggleSpawn },
    };

    pub fn init(state: *State, allocator: std.mem.Allocator) Input {
        return .{
            .state = state,
            .selected_units = std.ArrayList(i32).init(allocator),
        };
    }

    pub fn deinit(self: *Input) void {
        self.selected_units.deinit();
    }

    pub fn update(self: *Input) void {
        for (bindings) |bind| {
            if (bind.isTriggered()) {
                bind.handler(self);
            }
        }
    }

    fn onRegenerate(self: *Input) void {
        self.state.map.spawn(getSeed()) catch {};
    }

    fn onWaterUp(self: *Input) void {
        if (self.state.map.water_level > std.mem.max(f32, self.state.map.terrain) * CUBE_HEIGHT + 1.0) return;
        self.state.map.water_level += 0.03;
        self.state.map.update();
    }

    fn onWaterDown(self: *Input) void {
        if (self.state.map.water_level < std.mem.min(f32, self.state.map.terrain) * CUBE_HEIGHT - 1.0) return;
        self.state.map.water_level -= 0.03;
        self.state.map.update();
    }

    fn onRoughnessUp(self: *Input) void {
        self.state.map.noise_weight += 0.1;
        self.state.map.spawn(self.state.map.seed) catch {};
    }

    fn onRoughnessDown(self: *Input) void {
        self.state.map.noise_weight = @max(0, self.state.map.noise_weight - 0.1);
        self.state.map.spawn(self.state.map.seed) catch {};
    }

    fn onTextureScaleUp(self: *Input) void {
        if (self.state.map.texture_scale < 32.0) {
            self.state.map.texture_scale *= 2.0;
            self.state.map.update();
        }
    }

    fn onTextureScaleDown(self: *Input) void {
        if (self.state.map.texture_scale > 0.0625) {
            self.state.map.texture_scale /= 2.0;
            self.state.map.update();
        }
    }

    fn onSkyLighter(self: *Input) void {
        self.state.sky_hsv.y -= 0.5;
        if (self.state.sky_hsv.y < 0.0) self.state.sky_hsv.y += 360.0;
    }

    fn onSkyDarker(self: *Input) void {
        self.state.sky_hsv.y += 0.5;
        if (self.state.sky_hsv.y >= 360.0) self.state.sky_hsv.y -= 360.0;
    }

    fn onResetCamera(self: *Input) void {
        self.state.user.reset();
    }

    fn onStartSelection(self: *Input) void {
        self.selection_start = ray.GetMousePosition();
        if (ray.IsKeyDown(ray.KEY_LEFT_SHIFT)) {
            self.is_selecting = true;
        }
    }

    fn onUpdateSelection(self: *Input) void {
        if (self.state.user.mode == .tpv and !(ray.IsKeyDown(ray.KEY_LEFT_SHIFT))) {
            self.state.user.orbit();
        }
    }

    fn onEndSelection(self: *Input) void {
        self.last_ground_click = null;
        defer self.is_selecting = false;
        const mouse_curr = ray.GetMousePosition();
        const mouse_start = self.selection_start;
        if (self.is_selecting) {
            const rect = ray.Rectangle{
                .x = @min(mouse_start.x, mouse_curr.x),
                .y = @min(mouse_start.y, mouse_curr.y),
                .width = @abs(mouse_curr.x - mouse_start.x),
                .height = @abs(mouse_curr.y - mouse_start.y),
            };
            var it = self.state.objects.valueIterator();
            while (it.next()) |obj| {
                const y = self.state.map.getY(.{ obj.x, obj.z }) orelse continue;
                const screen_pos = ray.GetWorldToScreen(.{ .x = obj.x, .y = y + obj.y_offset, .z = obj.z }, self.state.user.camera);
                if (ray.CheckCollisionPointRec(screen_pos, rect)) {
                    self.selected_units.append(obj.id) catch {};
                }
            }
        } else {
            const mouse_ray = ray.GetMouseRay(mouse_curr, self.state.user.camera);
            var closest_dist: f32 = std.math.inf(f32);
            var closest_id: i32 = -1;
            var it = self.state.objects.valueIterator();
            while (it.next()) |obj| {
                const world_y = self.state.map.getY(.{ obj.x, obj.z }) orelse 0;
                const pos = ray.Vector3{ .x = obj.x, .y = world_y + obj.y_offset, .z = obj.z };
                const hit = ray.GetRayCollisionSphere(mouse_ray, pos, 1.0);
                if (hit.hit and hit.distance < closest_dist) {
                    closest_dist = hit.distance;
                    closest_id = obj.id;
                }
            }
            const terrain_hit = ray.GetRayCollisionMesh(mouse_ray, self.state.map.model.meshes[0], ray.MatrixTranslate(self.state.map.world_offset_x, 0, self.state.map.world_offset_z));
            if (closest_id != -1 and (terrain_hit.hit == false or closest_dist < terrain_hit.distance)) {
                self.selected_units.append(closest_id) catch {};
            } else if (terrain_hit.hit) {
                self.last_ground_click = terrain_hit.point;
            }
        }
        if (self.state.hook) |hook| hook(2, -1);
    }

    fn onToggleSpawn(self: *Input) void {
        switch (self.state.user.mode) {
            .tpv => {
                const mouse_ray = ray.GetMouseRay(ray.GetMousePosition(), self.state.user.camera);
                const hit = ray.GetRayCollisionMesh(mouse_ray, self.state.map.model.meshes[0], ray.MatrixIdentity());
                if (hit.hit) {
                    self.state.user.spawn(hit.point);
                }
            },
            .fpv => self.state.user.reset(),
            else => return,
        }
    }

    pub fn draw(self: *Input) void {
        if (ray.IsKeyDown(ray.KEY_H)) {
            ray.DrawRectangle(10, 10, 280, 300, ray.Fade(ray.SKYBLUE, 0.5));
            ray.DrawRectangleLines(10, 10, 280, 300, ray.BLUE);
            ray.DrawText("Controls:", 20, 20, 10, ray.BLACK);
            ray.DrawText("- Right Mouse: Regenerate terrain", 40, 40, 10, ray.DARKGRAY);
            ray.DrawText("- , or .: Decrease/Increase water", 40, 55, 10, ray.DARKGRAY);
            ray.DrawText("- [ or ]: Decrease/Increase roughness", 40, 70, 10, ray.DARKGRAY);
            ray.DrawText("- F / C: Texture Scale Up/Down", 40, 85, 10, ray.DARKGRAY);
            ray.DrawText("- D / N: Sky Day/Night", 40, 100, 10, ray.DARKGRAY);
            ray.DrawText("- Left Mouse: Rotate camera", 40, 115, 10, ray.DARKGRAY);
            ray.DrawText("- Mouse Wheel: Zoom in/out", 40, 130, 10, ray.DARKGRAY);
            ray.DrawText("- Z: Reset camera", 40, 145, 10, ray.DARKGRAY);
            ray.DrawText("- Middle Mouse: Spawn/Remove user", 40, 160, 10, ray.DARKGRAY);
            ray.DrawText("- WASD: Move user (when spawned)", 40, 175, 10, ray.DARKGRAY);
            ray.DrawText(ray.TextFormat("Seed: %d", self.state.map.seed), 40, 200, 10, ray.DARKGRAY);
            ray.DrawText(ray.TextFormat("Roughness: %.2f", self.state.map.noise_weight), 40, 215, 10, ray.DARKGRAY);
            ray.DrawText(ray.TextFormat("Water: %.1f", self.state.map.water_level), 40, 230, 10, ray.DARKGRAY);
            ray.DrawText(ray.TextFormat("Tex Scale: %.1f", self.state.map.texture_scale), 40, 245, 10, ray.DARKGRAY);
            ray.DrawFPS(40, 270);
        } else {
            ray.DrawText("Press H for help", 10, 10, 10, ray.DARKGRAY);
        }
        if (self.is_selecting) {
            const mouse = ray.GetMousePosition();
            const width = mouse.x - self.selection_start.x;
            const height = mouse.y - self.selection_start.y;
            ray.DrawRectangle(@intFromFloat(self.selection_start.x), @intFromFloat(self.selection_start.y), @intFromFloat(width), @intFromFloat(height), ray.Fade(ray.GREEN, 0.3));
            ray.DrawRectangleLines(@intFromFloat(self.selection_start.x), @intFromFloat(self.selection_start.y), @intFromFloat(width), @intFromFloat(height), ray.GREEN);
        }
    }
};

export fn get_last_click_position(x: *f32, y: *f32, z: *f32) bool {
    if (lib_instance) |state| {
        if (state.input.last_ground_click) |pos| {
            x.* = pos.x;
            y.* = pos.y;
            z.* = pos.z;
            return true;
        }
    }
    return false;
}

export fn get_selected_ids(buffer: [*c]i32, capacity: usize) i32 {
    if (lib_instance) |state| {
        const items = state.input.selected_units.items;
        const len = @min(items.len, capacity);
        if (len > 0) {
            @memcpy(buffer[0..len], items[0..len]);
        }
        return @intCast(len);
    }
    return 0;
}

export fn set_selected_ids(buffer: [*c]const i32, count: usize) void {
    if (lib_instance) |state| {
        state.input.selected_units.clearRetainingCapacity();
        if (count == 0) return;
        state.input.selected_units.appendSlice(buffer[0..count]) catch |err| {
            std.debug.print("Error updating selected units: {}\n", .{err});
        };
    }
}

export fn trigger_input_handler(index: usize) void {
    if (lib_instance) |state| {
        if (index < Input.bindings.len) {
            const bind = Input.bindings[index];
            std.debug.print("Directly triggering handler for binding index: {}\n", .{index});
            bind.handler(&state.input);
        } else {
            std.debug.print("Error: Binding index {} out of range (max {})\n", .{ index, Input.bindings.len - 1 });
        }
    }
}

export fn is_key_down(key: i32) bool {
    return ray.IsKeyDown(key);
}

export fn is_mouse_button_down(button: i32) bool {
    return ray.IsMouseButtonDown(button);
}

export fn get_mouse_delta(x: *f32, y: *f32) void {
    const delta = ray.GetMouseDelta();
    x.* = delta.x;
    y.* = delta.y;
}

//}}} INP
//{{{ CHAT

const Chat = struct {
    const chat_ui = @import("chat.zig");
    chat: chat_ui.ChatSystem,
    frozen_bg: ray.RenderTexture2D,
    frozen_src: ray.Rectangle,
    frozen_dst: ray.Rectangle,

    fn init(allocator: std.mem.Allocator, frozen_bg: ray.RenderTexture2D) !Chat {
        var chat = chat_ui.ChatSystem.init(allocator);
        errdefer chat.deinit();
        chat.loadPortrait("assets/face_placeholder.png");
        try chat.setNpcText("Greetings.");
        const tex_w = @as(f32, @floatFromInt(frozen_bg.texture.width));
        const tex_h = @as(f32, @floatFromInt(frozen_bg.texture.height));
        return Chat{
            .chat = chat,
            .frozen_bg = frozen_bg,
            .frozen_src = ray.Rectangle{ .x = 0, .y = 0, .width = tex_w, .height = -tex_h },
            .frozen_dst = ray.Rectangle{ .x = 0, .y = 0, .width = @as(f32, @floatFromInt(WINDOW_WIDTH)), .height = @as(f32, @floatFromInt(WINDOW_HEIGHT)) },
        };
    }

    fn deinit(self: *Chat) void {
        ray.UnloadRenderTexture(self.frozen_bg);
        self.chat.deinit();
    }

    fn update(self: *Chat, hook: ?*const fn (i32, i32) callconv(.C) void) !bool {
        const res = try self.chat.update();
        if (res == .Exit) {
            return false;
        } else if (res == .Submit) {
            if (hook) |h| h(2, -1);
        }
        return true;
    }

    fn draw(self: *Chat) void {
        ray.DrawTexturePro(self.frozen_bg.texture, self.frozen_src, self.frozen_dst, .{ .x = 0, .y = 0 }, 0.0, ray.GRAY);
        self.chat.draw(WINDOW_WIDTH, WINDOW_HEIGHT);
    }
};

export fn start_dialogue(npc_id: i32) void {
    _ = npc_id;
    if (lib_instance) |state| {
        if (state.chat) |*cm| {
            cm.deinit();
            state.chat = null;
        }
        const frozen_bg = ray.LoadRenderTexture(WINDOW_WIDTH, WINDOW_HEIGHT);
        ray.BeginTextureMode(frozen_bg);
        const bg_color = ray.ColorFromHSV(state.sky_hsv.x, state.sky_hsv.y, state.sky_hsv.z);
        ray.ClearBackground(bg_color);
        ray.BeginMode3D(state.user.camera);
        state.drawObjects();
        state.map.draw(state.user.camera.position.x, state.user.camera.position.z);
        ray.EndMode3D();
        ray.EndTextureMode();
        state.chat = Chat.init(state.allocator, frozen_bg) catch |err| {
            std.debug.print("Failed to init Chat: {}\n", .{err});
            ray.UnloadRenderTexture(frozen_bg);
            return;
        };
    }
}

export fn set_chat_portrait(path: [*c]const u8) void {
    if (lib_instance) |state| {
        if (state.chat) |*cm| {
            const path_slice = std.mem.span(path);
            cm.chat.loadPortrait(path_slice);
        }
    }
}

export fn update_chat_text(text: [*c]const u8) void {
    if (lib_instance) |state| {
        if (state.chat) |*cm| {
            const len = std.mem.len(text);
            cm.chat.clearInput();
            cm.chat.setNpcText(text[0..len]) catch {};
        }
    }
}

export fn get_user_input(buffer: [*c]u8, capacity: usize) void {
    if (lib_instance) |state| {
        if (state.chat) |*cm| {
            const len = @min(cm.chat.user_input.items.len, capacity);
            @memcpy(buffer[0..len], cm.chat.user_input.items[0..len]);
            if (len == capacity) buffer[len - 1] = 0;
        }
    }
}

export fn stop_dialogue() void {
    if (lib_instance) |state| {
        if (state.chat) |*cm| {
            cm.deinit();
            state.chat = null;
        }
    }
}

//}}} CHAT
//{{{ MAIN

fn getDungeon(allocator: std.mem.Allocator, seed: u64, size: usize, magnify: usize, dungeon_type: @import("dungeon.zig").DungeonType) ![]f32 {
    const dungeon = @import("dungeon.zig");
    if (magnify == 0 or size % magnify != 0) return error.InvalidMagnification;
    const small_size = size / magnify;
    var wfc_result = try dungeon.spawn(allocator, .{
        .output_width = small_size,
        .output_height = small_size,
        .max_attempts = 5,
        .dungeon_type = dungeon_type,
        .seed = seed,
    });
    defer wfc_result.deinit(allocator);
    const large_map = try allocator.alloc(f32, size * size);
    errdefer allocator.free(large_map);
    var y: usize = 0;
    while (y < size) : (y += 1) {
        var x: usize = 0;
        while (x < size) : (x += 1) {
            const sx = x / magnify;
            const sy = y / magnify;
            const cell_value = wfc_result.map[sy * small_size + sx];
            const height: f32 = switch (cell_value) {
                0 => 0.0,
                1 => 0.2,
                else => 0.1,
            };
            large_map[y * size + x] = height;
        }
    }
    return large_map;
}

pub fn main() !void {
    const builtin = @import("builtin");
    if (builtin.os.tag == .emscripten) return;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    ray.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Zigon Terrain");
    defer ray.CloseWindow();
    ray.SetTargetFPS(60);
    const seed = if (build_config.init_seed >= 0)
        build_config.init_seed
    else
        getSeed();
    var state = try State.create(gpa.allocator(), build_config.map_size, seed);
    defer state.destroy();
    if (terrain_gen.loadBaseMapFromFile(state.allocator, "map.txt", state.map.size)) |map| {
        if (state.map.base_map) |base| state.allocator.free(base);
        state.map.base_map = map;
        try state.map.spawn(state.map.seed);
    } else |_| {
        if (build_config.dungeon_type >= 0) {
            const wfc_map = try getDungeon(state.allocator, state.map.seed, state.map.size, build_config.dungeon_magnify, @enumFromInt(build_config.dungeon_type));
            if (state.map.base_map) |base| state.allocator.free(base);
            state.map.base_map = wfc_map;
            state.map.noise_weight = 0.0;
            state.map.water_level = -0.9;
            try state.map.spawn(state.map.seed);
        }
    }
    while (!ray.WindowShouldClose()) {
        try state.update();
        state.draw();
    }
}

//}}} MAIN
//{{{ WASM

export fn main_wasm() void {
    const builtin = @import("builtin");
    const is_web = builtin.target.os.tag == .emscripten;
    std.debug.print("GOGO: Starting initialization...\n", .{});
    ray.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Walk");
    const allocator = std.heap.c_allocator;
    const seed = getSeed();
    lib_instance = State.create(allocator, build_config.map_size, seed) catch |err| {
        std.debug.print("FATAL: State.create failed: {}\n", .{err});
        return;
    };
    std.debug.print("GOGO: Initialization success! Starting loop...\n", .{});
    if (is_web) {
        const emscripten = struct {
            extern "c" fn emscripten_set_main_loop(
                func: *const fn () callconv(.C) void,
                fps: c_int,
                simulate_infinite_loop: c_int,
            ) void;
        };
        emscripten.emscripten_set_main_loop(gameLoop, 0, 0);
    } else {
        while (!ray.WindowShouldClose()) {
            gameLoop();
        }
        ray.CloseWindow();
        if (lib_instance) |state| state.destroy();
    }
}

export fn gameLoop() void {
    if (lib_instance) |state| {
        state.update() catch |err| {
            std.debug.print("Update error: {}\n", .{err});
        };
        ray.BeginDrawing();
        defer ray.EndDrawing();
        ray.ClearBackground(ray.Color{ .r = 135, .g = 206, .b = 235, .a = 255 });
        ray.BeginMode3D(state.user.camera);
        state.map.draw(state.user.camera.position.x, state.user.camera.position.z);
        render_overlays_3d();
        ray.EndMode3D();
        render_overlays_2d();
        ray.DrawFPS(10, 10);
    } else {
        ray.BeginDrawing();
        defer ray.EndDrawing();
        ray.ClearBackground(ray.RED);
        ray.DrawText("INITIALIZATION FAILED", 20, 20, 20, ray.WHITE);
        ray.DrawText("Open Browser Console (F12) for details", 20, 50, 20, ray.WHITE);
    }
}

//}}} WASM
//{{{ STATE

const State = struct {
    allocator: std.mem.Allocator,
    user: User,
    input: Input,
    map: Map,
    objects: std.AutoHashMap(i32, Object),
    model_cache: std.StringHashMap(ray.Model),
    chat: ?Chat,
    charms: [MAX_CHARMS]Charm,
    hook: ?*const fn (i32, i32) callconv(.C) void,
    sky_hsv: ray.Vector3,
    time: f32,

    pub fn create(allocator: std.mem.Allocator, size: usize, seed: u64) !*State {
        const self = try allocator.create(State);
        self.allocator = allocator;
        self.input = Input.init(self, allocator);
        self.user = User.init(size);
        self.objects = std.AutoHashMap(i32, Object).init(allocator);
        self.model_cache = std.StringHashMap(ray.Model).init(allocator);
        self.sky_hsv = .{ .x = 200.0, .y = 90, .z = 0.9 };
        self.chat = null;
        self.charms = [1]Charm{.{}} ** MAX_CHARMS;
        self.hook = null;
        self.map = try Map.init(allocator, size, seed);
        self.time = 0.0;
        return self;
    }

    pub fn destroy(self: *State) void {
        var it = self.objects.valueIterator();
        while (it.next()) |obj| {
            obj.deinit();
        }
        var cache_it = self.model_cache.iterator();
        while (cache_it.next()) |entry| {
            ray.UnloadModel(entry.value_ptr.*);
            self.allocator.free(entry.key_ptr.*);
        }
        self.model_cache.deinit();
        self.map.deinit();
        self.objects.deinit();
        if (self.chat) |*c| c.deinit();
        for (&self.charms) |*c| c.unload();
        self.input.deinit();
        self.allocator.destroy(self);
    }

    pub fn update(self: *State) !void {
        if (self.chat) |*cm| {
            if (!try cm.update(self.hook)) {
                cm.deinit();
                self.chat = null;
            }
            return;
        }
        if (self.hook) |hook| hook(0, 0);
        self.user.update(&self.map);
        const dt = ray.GetFrameTime();
        self.time += dt;
        var it = self.objects.valueIterator();
        while (it.next()) |obj| {
            obj.update(dt, &self.objects);
        }
        self.input.update();
    }

    pub fn draw(self: *State) void {
        ray.BeginDrawing();
        defer ray.EndDrawing();
        if (self.chat) |*cm| {
            cm.draw();
            return;
        } else {
            ray.ClearBackground(ray.BLACK);
            ray.BeginMode3D(self.user.camera);
            self.drawSky();
            self.map.draw(self.user.camera.position.x, self.user.camera.position.z);
            self.drawObjects();
            for (self.charms) |c| c.draw();
            ray.EndMode3D();
            self.input.draw();
            render_overlays_2d();
        }
    }

    fn drawObjects(self: *State) void {
        var it = self.objects.valueIterator();
        while (it.next()) |obj| {
            obj.draw(&self.map, self.time);
        }
    }

    fn drawSky(self: *State) void {
        const center = self.user.camera.position;
        const radius: f32 = 400.0;
        const time_deg = self.sky_hsv.y;
        const time_rad = time_deg * std.math.pi / 180.0;
        const sun_x = @cos(time_rad) * radius;
        const sun_y = @sin(time_rad) * radius;
        const sun_pos = ray.Vector3{ .x = center.x + sun_x, .y = center.y + sun_y, .z = center.z };
        const Palette = struct {
            zenith: ray.Color,
            horizon: ray.Color,
            sun_core: ray.Color,
            sun_glow: ray.Color,
        };
        const p_sunrise = Palette{
            .zenith = .{ .r = 60, .g = 120, .b = 200, .a = 255 },
            .horizon = .{ .r = 255, .g = 240, .b = 160, .a = 255 },
            .sun_core = .{ .r = 255, .g = 220, .b = 50, .a = 255 },
            .sun_glow = .{ .r = 255, .g = 200, .b = 100, .a = 255 },
        };
        const p_noon = Palette{
            .zenith = .{ .r = 100, .g = 150, .b = 230, .a = 255 },
            .horizon = .{ .r = 135, .g = 206, .b = 235, .a = 255 },
            .sun_core = .{ .r = 255, .g = 255, .b = 240, .a = 255 },
            .sun_glow = .{ .r = 255, .g = 255, .b = 255, .a = 255 },
        };
        const p_sunset = Palette{
            .zenith = .{ .r = 80, .g = 100, .b = 160, .a = 255 },
            .horizon = .{ .r = 220, .g = 180, .b = 210, .a = 255 },
            .sun_core = .{ .r = 255, .g = 200, .b = 180, .a = 255 },
            .sun_glow = .{ .r = 230, .g = 150, .b = 200, .a = 255 },
        };
        const p_night = Palette{
            .zenith = .{ .r = 20, .g = 30, .b = 50, .a = 255 },
            .horizon = .{ .r = 40, .g = 60, .b = 90, .a = 255 },
            .sun_core = .{ .r = 0, .g = 0, .b = 0, .a = 0 },
            .sun_glow = .{ .r = 0, .g = 0, .b = 0, .a = 0 },
        };
        const mix = struct {
            fn col(c1: ray.Color, c2: ray.Color, t: f32) ray.Color {
                return ray.Color{
                    .r = @intCast(@as(i32, @intFromFloat(@as(f32, @floatFromInt(c1.r)) + (@as(f32, @floatFromInt(c2.r)) - @as(f32, @floatFromInt(c1.r))) * t))),
                    .g = @intCast(@as(i32, @intFromFloat(@as(f32, @floatFromInt(c1.g)) + (@as(f32, @floatFromInt(c2.g)) - @as(f32, @floatFromInt(c1.g))) * t))),
                    .b = @intCast(@as(i32, @intFromFloat(@as(f32, @floatFromInt(c1.b)) + (@as(f32, @floatFromInt(c2.b)) - @as(f32, @floatFromInt(c1.b))) * t))),
                    .a = 255,
                };
            }
            fn pal(p1: Palette, p2: Palette, t: f32) Palette {
                return Palette{
                    .zenith = col(p1.zenith, p2.zenith, t),
                    .horizon = col(p1.horizon, p2.horizon, t),
                    .sun_core = col(p1.sun_core, p2.sun_core, t),
                    .sun_glow = col(p1.sun_glow, p2.sun_glow, t),
                };
            }
        }.pal;
        var curr: Palette = undefined;
        if (time_deg < 90.0) {
            curr = mix(p_sunrise, p_noon, time_deg / 90.0);
        } else if (time_deg < 180.0) {
            curr = mix(p_noon, p_sunset, (time_deg - 90.0) / 90.0);
        } else if (time_deg < 270.0) {
            curr = mix(p_sunset, p_night, (time_deg - 180.0) / 90.0);
        } else {
            curr = mix(p_night, p_sunrise, (time_deg - 270.0) / 90.0);
        }
        const y_top_point = center.y + 400.0;
        const y_top_ring = center.y + 200.0;
        const y_bot_ring = center.y - 50.0;
        const y_bot_point = center.y - 400.0;
        ray.rlDisableDepthMask();
        ray.rlDisableBackfaceCulling();
        ray.rlBegin(ray.RL_TRIANGLES);
        const segments = 32;
        const step = 360.0 / @as(f32, @floatFromInt(segments));
        var angle: f32 = 0.0;
        while (angle < 360.0) : (angle += step) {
            const a1_rad = angle * std.math.pi / 180.0;
            const a2_rad = (angle + step) * std.math.pi / 180.0;
            const c1 = @cos(a1_rad);
            const s1 = @sin(a1_rad);
            const c2 = @cos(a2_rad);
            const s2 = @sin(a2_rad);
            ray.rlColor4ub(curr.zenith.r, curr.zenith.g, curr.zenith.b, curr.zenith.a);
            ray.rlVertex3f(center.x, y_top_point, center.z);
            ray.rlVertex3f(center.x + c1 * radius, y_top_ring, center.z + s1 * radius);
            ray.rlVertex3f(center.x + c2 * radius, y_top_ring, center.z + s2 * radius);
            ray.rlColor4ub(curr.zenith.r, curr.zenith.g, curr.zenith.b, curr.zenith.a);
            ray.rlVertex3f(center.x + c1 * radius, y_top_ring, center.z + s1 * radius);
            ray.rlColor4ub(curr.horizon.r, curr.horizon.g, curr.horizon.b, curr.horizon.a);
            ray.rlVertex3f(center.x + c1 * radius, y_bot_ring, center.z + s1 * radius);
            ray.rlVertex3f(center.x + c2 * radius, y_bot_ring, center.z + s2 * radius);
            ray.rlVertex3f(center.x + c2 * radius, y_bot_ring, center.z + s2 * radius);
            ray.rlColor4ub(curr.zenith.r, curr.zenith.g, curr.zenith.b, curr.zenith.a);
            ray.rlVertex3f(center.x + c2 * radius, y_top_ring, center.z + s2 * radius);
            ray.rlVertex3f(center.x + c1 * radius, y_top_ring, center.z + s1 * radius);
            const n_col = ray.Color{ .r = 205, .g = 240, .b = 255, .a = 255 };
            ray.rlColor4ub(curr.horizon.r, curr.horizon.g, curr.horizon.b, curr.horizon.a);
            ray.rlVertex3f(center.x + c2 * radius, y_bot_ring, center.z + s2 * radius);
            ray.rlVertex3f(center.x + c1 * radius, y_bot_ring, center.z + s1 * radius);
            ray.rlColor4ub(n_col.r, n_col.g, n_col.b, n_col.a);
            ray.rlVertex3f(center.x, y_bot_point, center.z);
        }
        ray.rlEnd();
        ray.rlEnableBackfaceCulling();
        ray.rlEnableDepthMask();
        if (sun_pos.y > center.y - 100.0) {
            ray.DrawSphere(sun_pos, 35.0, curr.sun_core);
            ray.DrawSphere(sun_pos, 60.0, ray.ColorAlpha(curr.sun_glow, 0.25));
        }
    }
};

//}}} STATE
//{{{ VIDEO

var lib_instance: ?*State = null;

export fn init_state(size: i32, seed: u64) void {
    if (lib_instance != null) return;
    if (!ray.IsWindowReady()) {
        ray.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Zigon Terrain");
        ray.SetTargetFPS(60);
    }
    lib_instance = State.create(std.heap.c_allocator, @intCast(size), seed) catch |err| {
        std.debug.print("FATAL: State.create failed with error: {}\n", .{err});
        return;
    };
}

export fn close_state() void {
    if (lib_instance) |state| {
        state.destroy();
        lib_instance = null;
    }
    ray.CloseWindow();
}

export fn register_hook(cb: *const fn (i32, i32) callconv(.C) void) void {
    if (lib_instance) |state| state.hook = cb;
}

export fn start_loop() void {
    if (lib_instance == null) return;
    while (!ray.WindowShouldClose()) {
        if (lib_instance) |state| {
            state.update() catch {};
            state.draw();
        }
    }
}

export fn enable_high_dpi() void {
    ray.SetConfigFlags(ray.FLAG_WINDOW_HIGHDPI);
}

export fn get_screen_size(width: *i32, height: *i32) void {
    width.* = ray.GetScreenWidth();
    height.* = ray.GetScreenHeight();
}

export fn get_render_size(width: *i32, height: *i32) void {
    width.* = ray.GetRenderWidth();
    height.* = ray.GetRenderHeight();
}

export fn render_frame() bool {
    if (lib_instance) |state| {
        if (ray.WindowShouldClose()) return false;
        state.update() catch {};
        state.draw();
        return true;
    }
    return false;
}

export fn set_mouse_cursor(visible: bool) void {
    if (visible) {
        ray.EnableCursor();
    } else {
        ray.DisableCursor();
    }
}

export fn capture_frame(buffer: [*c]u8, capacity: usize) void {
    const w = ray.GetRenderWidth();
    const h = ray.GetRenderHeight();
    const size = @as(usize, @intCast(w * h * 4));
    if (size <= capacity) {
        const gl_pixels = ray.rlReadScreenPixels(w, h);
        if (gl_pixels == null) return;
        defer std.c.free(gl_pixels);
        @memcpy(buffer[0..size], gl_pixels[0..size]);
    }
}

//}}} VIDEO
//{{{ CHARM

const MAX_CHARMS: usize = 8;

const Charm = struct {
    model: ?ray.Model = null,
    visible: bool = true,
    init_scale: f32 = 1.0,
    init_rot: ray.Vector3 = .{ .x = 0, .y = 0, .z = 0 },
    init_offset: ray.Vector3 = .{ .x = 0, .y = 0, .z = 0 },
    pos: ray.Vector3 = .{ .x = 0, .y = 0, .z = 0 },
    target: ray.Vector3 = .{ .x = 0, .y = 0, .z = 1 },
    up: ray.Vector3 = .{ .x = 0, .y = 1, .z = 0 },

    pub fn draw(self: @This()) void {
        var model = self.model orelse return;
        if (!self.visible) return;
        const mat_offset = ray.MatrixTranslate(self.init_offset.x, self.init_offset.y, self.init_offset.z);
        const mat_rot = ray.MatrixRotateXYZ(self.init_rot);
        const mat_scale = ray.MatrixScale(self.init_scale, self.init_scale, self.init_scale);
        const mat_local = ray.MatrixMultiply(ray.MatrixMultiply(mat_offset, mat_rot), mat_scale);
        const mat_look = ray.MatrixLookAt(self.pos, self.target, self.up);
        const mat_world = ray.MatrixInvert(mat_look);
        model.transform = ray.MatrixMultiply(mat_local, mat_world);
        ray.DrawModel(model, .{ .x = 0, .y = 0, .z = 0 }, 1.0, ray.GRAY);
    }

    pub fn unload(self: *Charm) void {
        if (self.model) |m| ray.UnloadModel(m);
        self.* = Charm{};
    }
};

fn getCharm(slot: u8) ?*Charm {
    if (lib_instance) |state| {
        if (slot < MAX_CHARMS) return &state.charms[slot];
    }
    return null;
}

export fn load_charm(slot: u8, path: [*c]const u8) void {
    if (getCharm(slot)) |c| {
        if (c.model) |m| ray.UnloadModel(m);
        c.model = null;
        const path_slice = std.mem.span(path);
        if (std.mem.eql(u8, path_slice, "default")) {
            c.model = ray.LoadModelFromMesh(ray.GenMeshCube(8.0, 3.0, 12.0));
        } else if (std.mem.eql(u8, path_slice, "cylinder")) {
            c.model = ray.LoadModelFromMesh(ray.GenMeshCylinder(0.5, 12.0, 8));
        } else if (std.mem.eql(u8, path_slice, "sphere")) {
            c.model = ray.LoadModelFromMesh(ray.GenMeshSphere(1.0, 8, 8));
        } else {
            c.model = ray.LoadModel(path);
        }
    }
}

export fn set_charm_init(slot: u8, scale: f32, rot_x: f32, rot_y: f32, rot_z: f32, off_x: f32, off_y: f32, off_z: f32) void {
    if (getCharm(slot)) |c| {
        c.init_scale = scale;
        c.init_rot = .{ .x = rot_x, .y = rot_y, .z = rot_z };
        c.init_offset = .{ .x = off_x, .y = off_y, .z = off_z };
    }
}

export fn set_charm_transform(slot: u8, px: f32, py: f32, pz: f32, tx: f32, ty: f32, tz: f32, ux: f32, uy: f32, uz: f32) void {
    if (getCharm(slot)) |c| {
        c.pos = .{ .x = px, .y = py, .z = pz };
        c.target = .{ .x = tx, .y = ty, .z = tz };
        c.up = .{ .x = ux, .y = uy, .z = uz };
    }
}

export fn set_charm_visible(slot: u8, visible: bool) void {
    if (getCharm(slot)) |c| {
        c.visible = visible;
    }
}

export fn unload_charm(slot: u8) void {
    if (getCharm(slot)) |c| {
        c.unload();
    }
}
//}}} CHARM
