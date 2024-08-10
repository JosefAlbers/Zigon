const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
});

const WINDOW_WIDTH: i32 = 800;
const WINDOW_HEIGHT: i32 = 450;
const TERRAIN_SIZE: i32 = 128;
const CUBE_SIZE: f32 = 1.0;
const WATER_LEVEL: f32 = 5.0; // Adjust this value to change the water level

fn fade(t: f32) f32 {
    return t * t * t * (t * (t * 6 - 15) + 10);
}

fn lerp(t: f32, a: f32, b: f32) f32 {
    return a + t * (b - a);
}

fn grad(hash: i32, x: f32, y: f32) f32 {
    const h = hash & 15;
    const u = if (h < 8) x else y;
    const v = if (h < 4) y else if (h == 12 or h == 14) x else 0;
    return (if ((h & 1) == 0) u else -u) + (if ((h & 2) == 0) v else -v);
}

fn noise(x: f32, y: f32, seed: i32) f32 {
    const X = @as(i32, @intFromFloat(x)) & 255;
    const Y = @as(i32, @intFromFloat(y)) & 255;
    const x_floor = x - @floor(x);
    const y_floor = y - @floor(y);
    const u = fade(x_floor);
    const v = fade(y_floor);

    const A = (@as(i32, @intCast(seed)) + X) & 255;
    const B = (A + 1) & 255;
    const AA = (A + Y) & 255;
    const AB = (A + Y + 1) & 255;
    const BA = (B + Y) & 255;
    const BB = (B + Y + 1) & 255;

    return lerp(v, lerp(u, grad(AA, x_floor, y_floor), grad(BA, x_floor - 1, y_floor)), lerp(u, grad(AB, x_floor, y_floor - 1), grad(BB, x_floor - 1, y_floor - 1)));
}

fn fbm(x: f32, y: f32, octaves: u32, persistence: f32, lacunarity: f32, scale: f32, seed: i32) f32 {
    var value: f32 = 0;
    var amplitude: f32 = 1;
    var frequency: f32 = 1;

    var i: u32 = 0;
    while (i < octaves) : (i += 1) {
        value += amplitude * noise(x * frequency / scale, y * frequency / scale, seed);
        amplitude *= persistence;
        frequency *= lacunarity;
    }

    return value;
}

fn generateTerrain(allocator: std.mem.Allocator, seed: i32) ![]f32 {
    var terrain = try allocator.alloc(f32, @as(usize, TERRAIN_SIZE * TERRAIN_SIZE));

    var y: i32 = 0;
    while (y < TERRAIN_SIZE) : (y += 1) {
        var x: i32 = 0;
        while (x < TERRAIN_SIZE) : (x += 1) {
            terrain[@intCast(y * TERRAIN_SIZE + x)] = fbm(@floatFromInt(x), @floatFromInt(y), 6, 0.5, 2.0, 50.0, seed);
        }
    }

    // Normalize the terrain
    var min: f32 = terrain[0];
    var max: f32 = terrain[0];
    for (terrain) |value| {
        if (value < min) min = value;
        if (value > max) max = value;
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

    var random_seed = @as(i32, @intFromFloat(@mod(ray.GetTime() * 1000000.0, 2147483647.0)));
    var terrain = try generateTerrain(allocator, random_seed);
    defer allocator.free(terrain);

    var camera = ray.Camera3D{
        .position = .{ .x = 100.0, .y = 100.0, .z = 100.0 },
        .target = .{ .x = 0.0, .y = 0.0, .z = 0.0 },
        .up = .{ .x = 0.0, .y = 1.0, .z = 0.0 },
        .fovy = 45.0,
        .projection = ray.CAMERA_PERSPECTIVE,
    };

    ray.DisableCursor();
    ray.SetTargetFPS(60);

    while (!ray.WindowShouldClose()) {
        ray.UpdateCamera(&camera, ray.CAMERA_FREE);

        if (ray.IsKeyPressed(ray.KEY_Z)) {
            camera.target = .{ .x = 0.0, .y = 0.0, .z = 0.0 };
        }

        // Check for terrain regeneration trigger
        if (ray.IsKeyPressed(ray.KEY_R) or ray.IsMouseButtonPressed(ray.MOUSE_BUTTON_LEFT)) {
            random_seed = @as(i32, @intFromFloat(@mod(ray.GetTime() * 1000000.0, 2147483647.0)));
            allocator.free(terrain);
            terrain = try generateTerrain(allocator, random_seed);
        }

        ray.BeginDrawing();
        defer ray.EndDrawing();

        ray.ClearBackground(ray.RAYWHITE);

        ray.BeginMode3D(camera);

        // Draw terrain
        var z: i32 = 0;
        while (z < TERRAIN_SIZE) : (z += 1) {
            var x: i32 = 0;
            while (x < TERRAIN_SIZE) : (x += 1) {
                const height = terrain[@intCast(z * TERRAIN_SIZE + x)];
                const cube_height = height * 20.0;
                const pos = ray.Vector3{
                    .x = @as(f32, @floatFromInt(x)) * CUBE_SIZE - @as(f32, @floatFromInt(TERRAIN_SIZE)) * CUBE_SIZE / 2,
                    .y = cube_height / 2,
                    .z = @as(f32, @floatFromInt(z)) * CUBE_SIZE - @as(f32, @floatFromInt(TERRAIN_SIZE)) * CUBE_SIZE / 2,
                };
                var color = ray.ColorFromHSV(120 * height, 0.8, 0.8);
                if (cube_height < WATER_LEVEL * 2) {
                    color.r = @intFromFloat(@as(f32, @floatFromInt(color.r)) * 0.7);
                    color.g = @intFromFloat(@as(f32, @floatFromInt(color.g)) * 0.7);
                    color.b = @intFromFloat(@as(f32, @floatFromInt(color.b)) * 0.7);
                }
                ray.DrawCube(pos, CUBE_SIZE, cube_height, CUBE_SIZE, color);
            }
        }

        // Draw water
        const water_size = @as(f32, @floatFromInt(TERRAIN_SIZE)) * CUBE_SIZE;
        const water_pos = ray.Vector3{
            .x = 0,
            .y = WATER_LEVEL,
            .z = 0,
        };
        ray.DrawCube(water_pos, water_size, 0.1, water_size, ray.ColorAlpha(ray.SKYBLUE, 0.5));

        ray.DrawGrid(10, 10.0);

        ray.EndMode3D();

        ray.DrawRectangle(10, 10, 320, 133, ray.Fade(ray.SKYBLUE, 0.5));
        ray.DrawRectangleLines(10, 10, 320, 133, ray.BLUE);
        ray.DrawText("JosefAlbers/TerrainZigger:", 20, 20, 10, ray.BLACK);
        ray.DrawText("- R or Left Mouse Click to regenerate terrain", 40, 40, 10, ray.DARKGRAY);
        ray.DrawText("- Mouse Wheel Pressed to Pan", 40, 60, 10, ray.DARKGRAY);
        ray.DrawText("- Mouse Wheel to Zoom in-out", 40, 80, 10, ray.DARKGRAY);
        ray.DrawText("- Z to zoom to (0, 0, 0)", 40, 100, 10, ray.DARKGRAY);
        ray.DrawText(ray.TextFormat("- Current Seed: %d", random_seed), 40, 120, 10, ray.DARKGRAY);

        ray.DrawFPS(10, 170);
    }
}
