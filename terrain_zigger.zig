const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
});

const WINDOW_WIDTH: i32 = 600;
const WINDOW_HEIGHT: i32 = 450;
const TERRAIN_SIZE: i32 = 128;
const CUBE_SIZE: f32 = 1.0;
const INITIAL_WATER_LEVEL: f32 = 5.0;

fn fade(t: f32) f32 {
    return t * t * t * (t * (t * 6 - 15) + 10);
}

fn lerp(t: f32, a: f32, b: f32) f32 {
    return a + t * (b - a);
}

fn grad(hash: i32, x: f32, y: f32, z: f32) f32 {
    const h = hash & 15;
    const u = if (h < 8) x else y;
    const v = if (h < 4) y else if (h == 12 or h == 14) x else z;
    return (if ((h & 1) == 0) u else -u) + (if ((h & 2) == 0) v else -v);
}

fn noise(x: f32, y: f32, z: f32, p: []const i32) f32 {
    const X = @as(u8, @intFromFloat(x)) & 255;
    const Y = @as(u8, @intFromFloat(y)) & 255;
    const Z = @as(u8, @intFromFloat(z)) & 255;
    const x_floor = x - @floor(x);
    const y_floor = y - @floor(y);
    const z_floor = z - @floor(z);
    const u = fade(x_floor);
    const v = fade(y_floor);
    const w = fade(z_floor);

    const A = @as(u8, @intCast(p[X])) +% Y;
    const AA = @as(u8, @intCast(p[A])) +% Z;
    const AB = @as(u8, @intCast(p[A +% 1])) +% Z;
    const B = @as(u8, @intCast(p[X +% 1])) +% Y;
    const BA = @as(u8, @intCast(p[B])) +% Z;
    const BB = @as(u8, @intCast(p[B +% 1])) +% Z;

    return lerp(w, lerp(v, lerp(u, grad(p[@intCast(AA)], x_floor, y_floor, z_floor), grad(p[@intCast(BA)], x_floor - 1, y_floor, z_floor)), lerp(u, grad(p[@intCast(AB)], x_floor, y_floor - 1, z_floor), grad(p[@intCast(BB)], x_floor - 1, y_floor - 1, z_floor))), lerp(v, lerp(u, grad(p[@intCast(AA +% 1)], x_floor, y_floor, z_floor - 1), grad(p[@intCast(BA +% 1)], x_floor - 1, y_floor, z_floor - 1)), lerp(u, grad(p[@intCast(AB +% 1)], x_floor, y_floor - 1, z_floor - 1), grad(p[@intCast(BB +% 1)], x_floor - 1, y_floor - 1, z_floor - 1))));
}

fn generatePermutation(allocator: std.mem.Allocator, seed: i32) ![]i32 {
    var rng = std.rand.DefaultPrng.init(@intCast(seed));
    var random = rng.random();

    const perm = try allocator.alloc(i32, 512);
    var source = try allocator.alloc(i32, 256);
    defer allocator.free(source);

    for (source, 0..) |*value, index| {
        value.* = @intCast(index);
    }

    var i: usize = 255;
    while (i > 0) : (i -= 1) {
        const j = random.intRangeAtMost(usize, 0, i);
        const temp = source[i];
        source[i] = source[j];
        source[j] = temp;
    }

    for (perm, 0..) |*value, index| {
        value.* = source[index % 256];
    }

    return perm;
}

fn fbm(x: f32, y: f32, octaves: u32, persistence: f32, lacunarity: f32, scale: f32, p: []const i32) f32 {
    var value: f32 = 0;
    var amplitude: f32 = 1;
    var frequency: f32 = 1;

    var i: u32 = 0;
    while (i < octaves) : (i += 1) {
        value += amplitude * noise(x * frequency / scale, y * frequency / scale, 0, p);
        amplitude *= persistence;
        frequency *= lacunarity;
    }

    return value;
}

fn generateTerrain(allocator: std.mem.Allocator, seed: i32) ![]f32 {
    var terrain = try allocator.alloc(f32, @as(usize, TERRAIN_SIZE * TERRAIN_SIZE));
    const perm = try generatePermutation(allocator, seed);
    defer allocator.free(perm);

    for (0..TERRAIN_SIZE) |y| {
        for (0..TERRAIN_SIZE) |x| {
            terrain[y * TERRAIN_SIZE + x] = fbm(@floatFromInt(x), @floatFromInt(y), 6, 0.5, 2.0, 50.0, perm);
        }
    }

    // Normalize the terrain
    var min: f32 = terrain[0];
    var max: f32 = terrain[0];
    for (terrain) |value| {
        min = @min(min, value);
        max = @max(max, value);
    }

    for (terrain) |*value| {
        value.* = (value.* - min) / (max - min);
    }

    return terrain;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    ray.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "JosefAlbers/TerrainZigger");
    defer ray.CloseWindow();

    var camera_distance: f32 = 200.0;
    var camera_angle = ray.Vector2{ .x = 0.7, .y = 0.7 };
    var camera = ray.Camera3D{
        .position = .{
            .x = @cos(camera_angle.y) * @cos(camera_angle.x) * camera_distance,
            .y = @sin(camera_angle.x) * camera_distance,
            .z = @sin(camera_angle.y) * @cos(camera_angle.x) * camera_distance,
        },
        .target = .{ .x = 0.0, .y = -20.0, .z = 0.0 },
        .up = .{ .x = 0.0, .y = 1.0, .z = 0.0 },
        .fovy = 45.0,
        .projection = ray.CAMERA_PERSPECTIVE,
    };

    var terrain = try generateTerrain(allocator, @intFromFloat(ray.GetTime() * 1000000.0));
    defer allocator.free(terrain);

    var water_level: f32 = INITIAL_WATER_LEVEL;

    ray.SetTargetFPS(60);

    while (!ray.WindowShouldClose()) {
        // Camera rotation
        if (ray.IsMouseButtonDown(ray.MOUSE_BUTTON_LEFT)) {
            const delta = ray.GetMouseDelta();
            camera_angle.x += delta.y * 0.003;
            camera_angle.y -= delta.x * 0.003;
            camera_angle.x = std.math.clamp(camera_angle.x, -std.math.pi / 3.0, std.math.pi / 3.0);
        }

        // Camera zoom
        const wheel = ray.GetMouseWheelMove();
        if (wheel != 0) {
            camera_distance *= (1.0 - wheel * 0.02);
            camera_distance = std.math.clamp(camera_distance, 10.0, 300.0);
        }

        // Update camera position
        camera.position = .{
            .x = @cos(camera_angle.y) * @cos(camera_angle.x) * camera_distance,
            .y = @sin(camera_angle.x) * camera_distance,
            .z = @sin(camera_angle.y) * @cos(camera_angle.x) * camera_distance,
        };

        // Reset camera
        if (ray.IsKeyPressed(ray.KEY_Z)) {
            camera_angle = .{ .x = 0.7, .y = 0.7 };
            camera_distance = 200.0;
        }

        // Regenerate terrain
        if (ray.IsKeyPressed(ray.KEY_R) or ray.IsMouseButtonPressed(ray.MOUSE_BUTTON_RIGHT)) {
            allocator.free(terrain);
            terrain = try generateTerrain(allocator, @intFromFloat(ray.GetTime() * 1000000.0));
        }

        // Adjust water level
        if (ray.IsKeyDown(ray.KEY_COMMA)) water_level = @max(0.0, water_level - 0.1);
        if (ray.IsKeyDown(ray.KEY_PERIOD)) water_level += 0.1;

        // Drawing
        ray.BeginDrawing();
        defer ray.EndDrawing();

        ray.ClearBackground(ray.RAYWHITE);
        ray.BeginMode3D(camera);

        // Draw terrain
        for (0..TERRAIN_SIZE) |z| {
            for (0..TERRAIN_SIZE) |x| {
                const height = terrain[z * TERRAIN_SIZE + x];
                const cube_height = height * 20.0;
                const pos = ray.Vector3{
                    .x = @as(f32, @floatFromInt(x)) * CUBE_SIZE - @as(f32, @floatFromInt(TERRAIN_SIZE)) * CUBE_SIZE / 2,
                    .y = cube_height / 2,
                    .z = @as(f32, @floatFromInt(z)) * CUBE_SIZE - @as(f32, @floatFromInt(TERRAIN_SIZE)) * CUBE_SIZE / 2,
                };
                var color = ray.ColorFromHSV(120 * height, 0.8, 0.8);
                if (cube_height < water_level * 2) {
                    color.r = @intFromFloat(@as(f32, @floatFromInt(color.r)) * 0.7);
                    color.g = @intFromFloat(@as(f32, @floatFromInt(color.g)) * 0.7);
                    color.b = @intFromFloat(@as(f32, @floatFromInt(color.b)) * 0.7);
                }
                ray.DrawCube(pos, CUBE_SIZE, cube_height, CUBE_SIZE, color);
            }
        }

        // Draw water
        const water_size = @as(f32, @floatFromInt(TERRAIN_SIZE)) * CUBE_SIZE;
        const water_pos = ray.Vector3{ .x = 0, .y = water_level, .z = 0 };
        ray.DrawCube(water_pos, water_size, 0.1, water_size, ray.ColorAlpha(ray.SKYBLUE, 0.5));

        ray.DrawGrid(10, 10.0);
        ray.EndMode3D();

        // Draw UI
        ray.DrawRectangle(10, 10, 245, 162, ray.Fade(ray.SKYBLUE, 0.5));
        ray.DrawRectangleLines(10, 10, 245, 162, ray.BLUE);
        ray.DrawText("Controls:", 20, 20, 10, ray.BLACK);
        ray.DrawText("- R or Right Mouse: Regenerate terrain", 40, 40, 10, ray.DARKGRAY);
        ray.DrawText("- , or .: Decrease/Increase water level", 40, 55, 10, ray.DARKGRAY);
        ray.DrawText("- Left Mouse: Rotate camera", 40, 70, 10, ray.DARKGRAY);
        ray.DrawText("- Mouse Wheel: Zoom in/out", 40, 85, 10, ray.DARKGRAY);
        ray.DrawText("- Z: Reset camera", 40, 100, 10, ray.DARKGRAY);
        ray.DrawText(ray.TextFormat("Camera Angle X: %.2f", camera_angle.x), 20, 120, 10, ray.DARKGRAY);
        ray.DrawText(ray.TextFormat("Camera Angle Y: %.2f", camera_angle.y), 20, 135, 10, ray.DARKGRAY);
        ray.DrawText(ray.TextFormat("Camera Distance: %.2f", camera_distance), 20, 150, 10, ray.DARKGRAY);
        ray.DrawFPS(10, 180);
    }
}
