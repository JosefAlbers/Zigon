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
// const WINDOW_WIDTH: i32 = 1920;
// const WINDOW_HEIGHT: i32 = 1000;
const CUBE_BASE: f32 = 1.0;
const CUBE_HEIGHT: f32 = 20.0 * CUBE_BASE;

fn getSeed() u64 {
    return @as(u64, @intCast(std.time.timestamp()));
}

//}}} INIT
//{{{ MAP

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
            .water_level = 5.0,
            .noise_weight = 0.9,
            .texture_scale = 1.0,
        };

        const initial_mesh = ray.GenMeshPlane(self.rendered_size, self.rendered_size, @intCast(size - 1), @intCast(size - 1));
        self.model = ray.LoadModelFromMesh(initial_mesh);

        if (seed == 0) {
            self.base_map = null;
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
        const config = terrain_gen.TerrainConfig{ .seed = seed, .size = self.size, .base_map = self.base_map, .noise_weight = self.noise_weight };

        const new_terrain = try terrain_gen.generateTerrain(self.allocator, config);
        self.allocator.free(self.terrain);
        self.terrain = new_terrain;

        var mesh = self.model.meshes[0];
        for (0..self.size) |z| {
            for (0..self.size) |x| {
                const idx = z * self.size + x;
                mesh.vertices[idx * 3 + 1] = self.terrain[idx] * CUBE_HEIGHT;
            }
        }

        const v_count: i32 = @intCast(mesh.vertexCount);
        ray.UpdateMeshBuffer(mesh, 0, mesh.vertices, v_count * 3 * @sizeOf(f32), 0);
        self.update();
        self.seed = seed;
    }

    pub fn update(self: *Map) void {
        const new_w: i32 = @intFromFloat(@as(f32, @floatFromInt(self.size)) * self.texture_scale);
        const resized = (self.image.width != new_w) or (self.image.data == null);

        if (resized) {
            const new_image = ray.GenImageColor(new_w, new_w, ray.BLANK);
            const pixels: []terrain_gen.Color = @as([*]terrain_gen.Color, @ptrCast(@alignCast(new_image.data)))[0..@intCast(new_w * new_w)];
            terrain_gen.writeTextureBuffer(pixels, self.terrain, self.size, self.texture_scale, self.water_level, CUBE_HEIGHT);
            const new_texture = ray.LoadTextureFromImage(new_image);
            ray.SetTextureFilter(new_texture, ray.TEXTURE_FILTER_POINT);
            if (self.model.materialCount > 0) {
                self.model.materials[0].maps[ray.MATERIAL_MAP_DIFFUSE].texture = new_texture;
            }
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

    pub fn draw(self: *Map) void {
        ray.DrawModel(self.model, .{ .x = 0, .y = 0, .z = 0 }, 1.0, ray.WHITE);
        ray.DrawCube(.{ .x = 0, .y = self.water_level, .z = 0 }, self.rendered_size, 0.1, self.rendered_size, ray.ColorAlpha(ray.SKYBLUE, 0.5));
    }

    fn getXZ(self: *Map, xz: @Vector(2, f32)) ?@Vector(2, f32) {
        const g_xz = (xz + @as(@Vector(2, f32), @splat(self.rendered_size * 0.5))) / @as(@Vector(2, f32), @splat(CUBE_BASE));
        if (@reduce(.Or, g_xz < @as(@Vector(2, f32), @splat(0))) or @reduce(.Or, g_xz >= @as(@Vector(2, f32), @splat(@floatFromInt(self.size))))) return null;
        return g_xz;
    }

    fn getY(self: *Map, xz: @Vector(2, f32), needs_translation: bool) ?f32 {
        const g_xz = if (needs_translation)
            self.getXZ(xz) orelse return null
        else
            xz;
        // const raw_h = terrain_gen.getWeightedAverageHeight(self.terrain, g_xz[0], g_xz[1], 1, self.size, 8.0) orelse return null; //: v1
        const raw_h = terrain_gen.getBilinearHeight(self.terrain, g_xz, self.size) orelse return null; //: v2
        return raw_h * CUBE_HEIGHT;
    }

    fn getXYZ(self: *Map, xz: @Vector(2, f32)) ?@Vector(3, f32) {
        if (@reduce(.Or, xz < @as(@Vector(2, f32), @splat(0))) or @reduce(.Or, xz >= @as(@Vector(2, f32), @splat(@floatFromInt(self.size))))) return null;
        const w_xz = (xz * @as(@Vector(2, f32), @splat(CUBE_BASE))) - @as(@Vector(2, f32), @splat(self.rendered_size * 0.5));
        const w_y = self.getY(xz, false) orelse return null;
        return .{ w_xz[0], w_y, w_xz[1] };
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

//}}} MAP
//{{{ OBJ

const Object = struct {
    id: i32,
    obj_type: object_gen.ObjectType,
    x: f32,
    z: f32,
    y_offset: f32,
    yaw: f32,
    target_x: ?f32 = null,
    target_z: ?f32 = null,
    speed: f32 = 5.0,
    state: f32 = 0.0,

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
            self.yaw = std.math.atan2(dx, dz) * (180.0 / std.math.pi);
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

    pub fn draw(self: *Object, map: *Map, t: f32) void {
        if (map.getXYZ(.{ self.x, self.z })) |pos| {
            object_gen.drawObject(self.obj_type, pos[0], pos[1] + self.y_offset, pos[2], self.yaw, t * self.state);
        }
    }
};

export fn spawn_object(id: i32, type_id: i32, x: f32, z: f32, y_off: f32) void {
    if (lib_instance) |state| {
        const obj = Object{
            .id = id,
            .obj_type = @enumFromInt(type_id),
            .x = x,
            .z = z,
            .y_offset = y_off,
            .yaw = 0.0,
        };
        state.objects.put(id, obj) catch {};
    }
}

export fn spawn_object_by_name(id: i32, type_name: [*c]const u8, x: f32, z: f32, y_off: f32) void {
    if (lib_instance) |state| {
        const name_slice = std.mem.span(type_name);
        const obj_type = object_gen.ObjectType.fromString(name_slice);
        const obj = Object{
            .id = id,
            .obj_type = obj_type,
            .x = x,
            .z = z,
            .y_offset = y_off,
            .yaw = 0.0,
        };
        state.objects.put(id, obj) catch {};
    }
}

export fn despawn_object(id: i32) void {
    if (lib_instance) |state| {
        _ = state.objects.remove(id);
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

//}}} OBJ
//{{{ INP

const Input = struct {
    state: *State,
    last_ground_click: ray.Vector3 = .{ .x = 0, .y = 0, .z = 0 },
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
        self.state.user.reset();
    }

    fn onWaterUp(self: *Input) void {
        self.state.map.water_level += 0.8;
        self.state.map.update();
    }

    fn onWaterDown(self: *Input) void {
        self.state.map.water_level -= 0.8;
        self.state.map.update();
    }

    fn onRoughnessUp(self: *Input) void {
        self.state.map.noise_weight += 0.05;
        self.state.map.spawn(self.state.map.seed) catch {};
    }

    fn onRoughnessDown(self: *Input) void {
        self.state.map.noise_weight = @max(0, self.state.map.noise_weight - 0.05);
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
        self.state.sky_hsv.z = @min(1.0, self.state.sky_hsv.z + 0.01);
    }

    fn onSkyDarker(self: *Input) void {
        self.state.sky_hsv.z = @max(0.05, self.state.sky_hsv.z - 0.01);
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
        if (!(ray.IsKeyDown(ray.KEY_LEFT_SHIFT))) {
            self.state.user.orbit();
        }
    }

    fn onEndSelection(self: *Input) void {
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
                const pos = self.state.map.getXYZ(.{ obj.x, obj.z }) orelse continue;
                const screen_pos = ray.GetWorldToScreen(.{ .x = pos[0], .y = pos[1] + obj.y_offset, .z = pos[2] }, self.state.user.camera);
                if (ray.CheckCollisionPointRec(screen_pos, rect)) {
                    self.selected_units.append(obj.id) catch {};
                }
            }
        } else {
            var ray_pos = mouse_curr;
            if (self.state.user.mode == .fpv) {
                ray_pos.x = @as(f32, @floatFromInt(WINDOW_WIDTH)) / 2.0;
                ray_pos.y = @as(f32, @floatFromInt(WINDOW_HEIGHT)) / 2.0;
            }
            const mouse_ray = ray.GetMouseRay(ray_pos, self.state.user.camera);
            var closest_dist: f32 = std.math.inf(f32);
            var closest_id: i32 = -1;
            var it_closest = self.state.objects.valueIterator();
            while (it_closest.next()) |obj| {
                const pos = self.state.map.getXYZ(.{ obj.x, obj.z }) orelse continue;
                const hit = ray.GetRayCollisionSphere(mouse_ray, .{ .x = pos[0], .y = pos[1] + obj.y_offset, .z = pos[2] }, 1.0);
                if (hit.hit and hit.distance < closest_dist) {
                    closest_dist = hit.distance;
                    closest_id = obj.id;
                }
            }
            const terrain_hit = ray.GetRayCollisionMesh(mouse_ray, self.state.map.model.meshes[0], ray.MatrixIdentity());
            const terrain_blocked = terrain_hit.hit and (terrain_hit.distance < closest_dist);
            if (closest_id != -1 and !terrain_blocked) {
                self.selected_units.append(closest_id) catch {};
            } else if (terrain_hit.hit) {
                const half_size = self.state.map.rendered_size / 2.0;
                self.last_ground_click = .{
                    .x = (terrain_hit.point.x + half_size) / CUBE_BASE,
                    .y = terrain_hit.point.y,
                    .z = (terrain_hit.point.z + half_size) / CUBE_BASE,
                };
            }
            if (self.state.hook) |hook| hook(2, -1);
        }
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

export fn get_last_click_position(x: *f32, y: *f32, z: *f32) void {
    if (lib_instance) |state| {
        x.* = state.input.last_ground_click.x;
        y.* = state.input.last_ground_click.y;
        z.* = state.input.last_ground_click.z;
    }
}

export fn get_selected_count() i32 {
    if (lib_instance) |state| return @intCast(state.input.selected_units.items.len);
    return 0;
}

export fn get_selected_ids(buffer: [*c]i32, capacity: usize) void {
    if (lib_instance) |state| {
        const len = @min(state.input.selected_units.items.len, capacity);
        @memcpy(buffer[0..len], state.input.selected_units.items[0..len]);
    }
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

//}}} INP
//{{{ USER

const User = struct {
    camera: ray.Camera3D,
    mode: enum { fpv, tpv },
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
                if (map.getY(.{ self.camera.position.x, self.camera.position.z }, true)) |h| {
                    if (h > old_pos.y) {
                        self.camera.position = old_pos;
                    } else {
                        self.camera.position.y = h + self.height;
                    }
                } else {
                    self.camera.position = old_pos;
                }
            },
            .tpv => {
                const wheel = ray.GetMouseWheelMove();
                if (wheel != 0) self.zoom(wheel);
            },
        }
    }

    fn spawn(self: *User, pos: ray.Vector3) void {
        self.camera.position = .{ .x = pos.x, .y = pos.y + self.height, .z = pos.z };
        self.camera.target = .{ .x = 0.0, .y = pos.y, .z = 0.0 };
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
            const half = @as(f32, @floatFromInt(state.map.size)) * CUBE_BASE / 2.0;
            x.* = (state.user.camera.position.x + half) / CUBE_BASE;
            z.* = (state.user.camera.position.z + half) / CUBE_BASE;
            y.* = state.user.camera.position.y;
            return true;
        }
    }
    return false;
}

//}}} USER
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
        state.map.draw();
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
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    ray.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Terrain Zigger");
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
            try state.map.spawn(state.map.seed);
        }
    }
    while (!ray.WindowShouldClose()) {
        try state.update();
        state.draw();
    }
}

//}}} MAIN
//{{{ STATE

const State = struct {
    allocator: std.mem.Allocator,
    user: User,
    input: Input,
    map: Map,
    objects: std.AutoHashMap(i32, Object),
    chat: ?Chat,
    hook: ?*const fn (i32, i32) callconv(.C) void,
    sky_hsv: ray.Vector3,
    time: f32,

    pub fn create(allocator: std.mem.Allocator, size: usize, seed: u64) !*State {
        const self = try allocator.create(State);
        self.allocator = allocator;
        self.input = Input.init(self, allocator);
        self.user = User.init(size);
        self.objects = std.AutoHashMap(i32, Object).init(allocator);
        self.sky_hsv = .{ .x = 200.0, .y = 0.4, .z = 0.9 };
        self.chat = null;
        self.hook = null;
        self.map = try Map.init(allocator, size, seed);
        self.time = 0.0;
        return self;
    }

    pub fn destroy(self: *State) void {
        self.input.deinit();
        self.map.deinit();
        self.objects.deinit();
        if (self.chat) |*cm| cm.deinit();
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

    fn drawObjects(self: *State) void {
        var it = self.objects.valueIterator();
        while (it.next()) |obj| {
            obj.draw(&self.map, self.time);
        }
    }

    pub fn draw(self: *State) void {
        ray.BeginDrawing();
        defer ray.EndDrawing();
        if (self.chat) |*cm| {
            cm.draw();
            return;
        } else {
            const bg_color = ray.ColorFromHSV(self.sky_hsv.x, self.sky_hsv.y, self.sky_hsv.z);
            ray.ClearBackground(bg_color);
            ray.BeginMode3D(self.user.camera);
            self.drawObjects();
            self.map.draw();
            ray.EndMode3D();
            self.input.draw();
        }
    }
};

var lib_instance: ?*State = null;

export fn init_state(seed: u64, size: i32) void {
    if (lib_instance != null) return;
    if (!ray.IsWindowReady()) {
        ray.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Terrain Zigger");
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

//}}} STATE
