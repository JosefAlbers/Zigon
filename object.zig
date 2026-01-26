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

//}}} INIT
//{{{ PRIM

pub const ShapeType = enum {
    Line,
    Sphere,
    Cube,
    Cylinder,
    Capsule,
    Cone,
    Skip,
};

pub const Kwargs = struct {
    shape: ShapeType,
    color: ray.Color = ray.GRAY,
    radius: ?f32 = null,
    radius_tip: ?f32 = null,
    thickness: ?f32 = null,
    roll: ?f32 = null,
    slices: ?i32 = null,
};

pub fn drawShape(base: ray.Vector3, tip: ray.Vector3, args: Kwargs) void {
    if (args.shape == .Skip) return;
    const diff = ray.Vector3Subtract(tip, base);
    const length = ray.Vector3Length(diff);
    const mid = ray.Vector3Scale(ray.Vector3Add(base, tip), 0.5);
    switch (args.shape) {
        .Skip => return,
        .Line => {
            ray.DrawLine3D(base, tip, args.color);
            return;
        },
        .Capsule => {
            ray.DrawCapsule(base, tip, args.radius orelse 0.1, args.slices orelse 16, 8, args.color);
            return;
        },
        .Sphere => {
            const r = args.radius orelse (length / 2.0);
            ray.DrawSphereEx(mid, r, 8, args.slices orelse 16, args.color);
            return;
        },
        .Cylinder, .Cone => {
            const r1 = args.radius orelse 0.1;
            const r2 = if (args.shape == .Cone) 0.0 else (args.radius_tip orelse r1);

            if (args.roll) |roll| {
                ray.rlPushMatrix();
                defer ray.rlPopMatrix();
                ray.rlTranslatef(base.x, base.y, base.z);
                ray.rlRotatef(roll, 0, 1, 0);
                const local_tip = ray.Vector3Subtract(tip, base);
                ray.DrawCylinderEx(.{ .x = 0, .y = 0, .z = 0 }, local_tip, r1, r2, args.slices orelse 16, args.color);
            } else {
                ray.DrawCylinderEx(base, tip, r1, r2, args.slices orelse 16, args.color);
            }
            return;
        },
        .Cube => {
            ray.rlPushMatrix();
            defer ray.rlPopMatrix();
            ray.rlTranslatef(base.x, base.y, base.z);
            const direction = ray.Vector3Normalize(diff);
            const world_up = ray.Vector3{ .x = 0, .y = 1, .z = 0 };
            if (@abs(ray.Vector3DotProduct(direction, world_up)) < 0.9999) {
                const axis = ray.Vector3CrossProduct(world_up, direction);
                const angle = std.math.acos(ray.Vector3DotProduct(world_up, direction)) * (180.0 / std.math.pi);
                ray.rlRotatef(angle, axis.x, axis.y, axis.z);
            } else if (direction.y < 0) {
                ray.rlRotatef(180, 1, 0, 0);
            }
            if (args.roll) |r| ray.rlRotatef(r, 0, 1, 0);
            const thick = args.thickness orelse 0.1;
            ray.DrawCube(ray.Vector3{ .x = 0, .y = length / 2, .z = 0 }, thick, length, thick, args.color);
        },
    }
}

//}}} PRIM
//{{{ STIL

const ShapeStep = struct {
    offset: ray.Vector3,
    config: Kwargs,
    anim: ?ray.Vector3 = null,
};

const ShapeSequence = struct {
    steps: []const ShapeStep,

    pub fn draw(self: ShapeSequence, root: ray.Vector3, t: f32) void {
        var prev_pos = root;
        for (self.steps) |step| {
            var curr_pos = ray.Vector3Add(root, step.offset);
            if (step.anim) |sa| {
                curr_pos = ray.Vector3Add(curr_pos, ray.Vector3Scale(sa, t));
            }
            drawShape(prev_pos, curr_pos, step.config);
            prev_pos = curr_pos;
        }
    }
};

const rock_sequence = ShapeSequence{ .steps = &[_]ShapeStep{
    .{ .offset = .{ .x = 0, .y = 0.3, .z = 0 }, .config = .{ .shape = .Sphere, .radius = 0.5, .color = ray.GRAY } },
} };

const tree_sequence = ShapeSequence{ .steps = &[_]ShapeStep{
    .{ .offset = .{ .x = 0, .y = 1.0, .z = 0 }, .config = .{ .shape = .Cylinder, .radius = 0.3, .radius_tip = 0.2, .color = ray.BROWN } },
    .{ .offset = .{ .x = 0, .y = 2.5, .z = 0 }, .config = .{ .shape = .Cone, .radius = 0.6, .color = ray.DARKGREEN } },
} };

const house_sequence = ShapeSequence{ .steps = &[_]ShapeStep{
    .{ .offset = .{ .x = 0, .y = 1, .z = 0 }, .config = .{ .shape = .Cube, .thickness = 1.5, .color = ray.GRAY } },
    .{ .offset = .{ .x = 0, .y = 2, .z = 0 }, .config = .{ .shape = .Cone, .radius = 1.5, .slices = 4, .color = ray.MAROON, .roll = 45 } },
} };

const bird_sequence = ShapeSequence{
    .steps = &[_]ShapeStep{
        .{ .offset = .{ .x = 0.4, .y = 0, .z = 0 }, .config = .{ .shape = .Line, .color = ray.BLACK }, .anim = .{ .x = 0, .y = 0.4, .z = 0 } },
        .{ .offset = .{ .x = -0.4, .y = 0, .z = 0 }, .config = .{ .shape = .Skip }, .anim = .{ .x = 0, .y = 0.4, .z = 0 } },
        .{ .offset = .{ .x = 0, .y = 0, .z = 0 }, .config = .{ .shape = .Line, .color = ray.BLACK } },
    },
};

const rain_sequence = ShapeSequence{
    .steps = &[_]ShapeStep{
        .{ .offset = .{ .x = 0, .y = 0, .z = 0 }, .config = .{ .shape = .Skip }, .anim = .{ .x = 0, .y = -1, .z = 0 } },
        .{ .offset = .{ .x = 0, .y = -0.2, .z = 0 }, .config = .{ .shape = .Line, .color = ray.RED }, .anim = .{ .x = 0, .y = -1, .z = 0 } },
    },
};

const human_sequence = ShapeSequence{
    .steps = &[_]ShapeStep{
        .{ .offset = .{ .x = 0, .y = 0.1, .z = 0 }, .config = .{ .shape = .Skip } },
        .{ .offset = .{ .x = 0, .y = 0.6, .z = 0 }, .config = .{ .shape = .Cylinder, .radius = 0.2, .radius_tip = 0.15, .color = ray.BLUE } },
        .{ .offset = .{ .x = 0, .y = 1, .z = 0 }, .config = .{ .shape = .Sphere, .radius = 0.15, .color = ray.BEIGE } },
    },
};

const feet_sequence = ShapeSequence{
    .steps = &[_]ShapeStep{
        .{ .offset = .{ .x = -0.1, .y = 0, .z = 0 }, .config = .{ .shape = .Cone, .slices = 4, .radius = 0.1, .color = ray.BLACK }, .anim = .{ .x = 0, .y = 0, .z = 0.1 } },
        .{ .offset = .{ .x = 0, .y = 0, .z = 0 }, .config = .{ .shape = .Skip } },
        .{ .offset = .{ .x = 0.1, .y = 0, .z = 0 }, .config = .{ .shape = .Cone, .slices = 4, .radius = 0.1, .color = ray.BLACK }, .anim = .{ .x = 0, .y = 0, .z = -0.1 } },
    },
};

const sword_sequence = ShapeSequence{
    .steps = &[_]ShapeStep{
        .{ .offset = .{ .x = 0, .y = 0.2, .z = 0 }, .config = .{ .shape = .Cylinder, .radius = 0.03, .color = ray.BROWN }, .anim = .{ .x = 0, .y = 0.025, .z = 0.05 } },
        .{ .offset = .{ .x = 0, .y = 1.6, .z = 0 }, .config = .{ .shape = .Cone, .radius = 0.03, .color = ray.LIGHTGRAY }, .anim = .{ .x = 0, .y = 0.2, .z = 0.4 } },
    },
};

//}}} STIL
//{{{ MAIN

pub fn main() !void {
    ray.InitWindow(800, 600, "Modular Toolset");
    defer ray.CloseWindow();
    ray.SetTargetFPS(60);
    const camera = ray.Camera3D{ .position = .{ .x = 12, .y = 12, .z = 12 }, .target = .{ .x = 0, .y = 0, .z = 0 }, .up = .{ .x = 0, .y = 1, .z = 0 }, .fovy = 45, .projection = ray.CAMERA_PERSPECTIVE };

    var prng = std.rand.DefaultPrng.init(0);
    const random = prng.random();

    while (!ray.WindowShouldClose()) {
        const t = @as(f32, @floatCast(ray.GetTime()));
        const active = ray.IsKeyDown(ray.KEY_SPACE);

        ray.BeginDrawing();
        ray.ClearBackground(ray.SKYBLUE);
        ray.BeginMode3D(camera);
        ray.DrawGrid(20, 1.0);

        // Spotlight
        drawShape(.{ .x = 0, .y = 0, .z = 0 }, .{ .x = 0, .y = 20, .z = 0 }, .{ .shape = .Cylinder, .radius = 0.5, .radius_tip = 0.55, .color = ray.Fade(ray.YELLOW, 0.4) });

        // Environment
        rock_sequence.draw(.{ .x = -2, .y = 0, .z = -2 }, 0);
        tree_sequence.draw(.{ .x = 0, .y = 0, .z = 2 }, 0);
        house_sequence.draw(.{ .x = 2, .y = 0, .z = -2 }, 0);
        bird_sequence.draw(.{ .x = @sin(t) * 5.0, .y = 4.0 + @cos(t), .z = @cos(t) * 5.0 }, @sin(t * 15.0));

        // Rain particles
        for (0..10) |_| {
            const rx = (random.float(f32) - 0.5) * 20.0;
            const rz = (random.float(f32) - 0.5) * 20.0;
            rain_sequence.draw(.{ .x = rx, .y = 10, .z = rz }, t);
        }

        // Humans
        const h_pos = [_]ray.Vector3{ .{ .x = -4, .y = 0, .z = 4 }, .{ .x = -1, .y = 0, .z = 4 }, .{ .x = 2, .y = 0, .z = 4 }, .{ .x = 5, .y = 0, .z = 4 } };
        for (h_pos) |p| {
            human_sequence.draw(p, 0);
            feet_sequence.draw(p, if (active) 3 * @sin(t * 10) else @sin(t));
            sword_sequence.draw(.{ .x = p.x + 0.4, .y = p.y + 0.4, .z = p.z }, if (active) 3 * @sin(t * 10) else @sin(t));
        }

        ray.EndMode3D();
        ray.EndDrawing();
    }
}

//}}} MAIN
//{{{ PUB

pub const ObjectType = enum {
    Beam,
    Rock,
    Tree,
    House,
    Bird,
    Rain,
    Human,
    pub fn fromString(s: []const u8) ObjectType {
        return std.meta.stringToEnum(ObjectType, s) orelse .Beam;
    }
};

pub fn drawObject(obj_type: ObjectType, x: f32, y: f32, z: f32, yaw: f32, t: f32) void {
    const pos = ray.Vector3{ .x = x, .y = y, .z = z };
    ray.rlPushMatrix();
    defer ray.rlPopMatrix();
    ray.rlTranslatef(pos.x, pos.y, pos.z);
    ray.rlRotatef(yaw, 0, 1, 0);
    const zero = ray.Vector3{ .x = 0, .y = 0, .z = 0 };
    switch (obj_type) {
        .Human => {
            human_sequence.draw(zero, 0);
            feet_sequence.draw(zero, 3 * @sin(t * 10));
            sword_sequence.draw(.{ .x = zero.x + 0.4, .y = zero.y + 0.4, .z = zero.z }, 3 * @sin(t * 10));
        },
        .Rain => rain_sequence.draw(zero, @rem(t, 1.0) * @max(10, y)),
        .Bird => bird_sequence.draw(zero, @sin(t * 15.0)),
        .House => house_sequence.draw(zero, t),
        .Tree => tree_sequence.draw(zero, t),
        .Rock => rock_sequence.draw(zero, t),
        .Beam => {
            drawShape(.{ .x = 0, .y = 0, .z = 0 }, .{ .x = 0, .y = 20, .z = 0 }, .{ .shape = .Cylinder, .radius = 0.5, .radius_tip = 0.55, .color = ray.Fade(ray.YELLOW, 0.4) });
        },
    }
}

//}}} PUB
