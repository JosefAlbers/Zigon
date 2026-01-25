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
});

pub const ChatResult = enum {
    None,
    Submit,
    Exit,
};

pub const ChatSystem = struct {
    allocator: std.mem.Allocator,
    npc_message: std.ArrayList(u8),
    user_input: std.ArrayList(u8),
    portrait: ray.Texture2D,
    anim_image: ray.Image,
    anim_frames: i32,
    anim_current: i32,
    anim_timer: f32,
    is_animated: bool,
    const BOX_HEIGHT = 200;
    const MARGIN = 20;

    pub fn init(allocator: std.mem.Allocator) ChatSystem {
        var sys = ChatSystem{
            .allocator = allocator,
            .npc_message = std.ArrayList(u8).init(allocator),
            .user_input = std.ArrayList(u8).init(allocator),
            .portrait = std.mem.zeroes(ray.Texture2D),
            .anim_image = std.mem.zeroes(ray.Image),
            .anim_frames = 0,
            .anim_current = 0,
            .anim_timer = 0.0,
            .is_animated = false,
        };
        sys.npc_message.append(0) catch {};
        sys.user_input.append(0) catch {};
        return sys;
    }

    pub fn deinit(self: *ChatSystem) void {
        self.npc_message.deinit();
        self.user_input.deinit();
        if (self.portrait.id > 0) ray.UnloadTexture(self.portrait);
        if (self.is_animated) ray.UnloadImage(self.anim_image);
    }

    pub fn loadPortrait(self: *ChatSystem, path: []const u8) void {
        if (self.portrait.id > 0) ray.UnloadTexture(self.portrait);
        if (self.is_animated) ray.UnloadImage(self.anim_image);
        self.is_animated = false;
        std.fs.cwd().access(path, .{}) catch {
            var img = ray.GenImageColor(256, 256, ray.BLACK);
            ray.ImageDrawCircle(&img, 128, 128, 90, ray.BEIGE);
            ray.ImageDrawCircle(&img, 100, 110, 10, ray.BLACK);
            ray.ImageDrawCircle(&img, 156, 110, 10, ray.BLACK);
            ray.ImageDrawRectangle(&img, 100, 160, 56, 10, ray.BLACK);
            self.portrait = ray.LoadTextureFromImage(img);
            ray.UnloadImage(img);
            return;
        };

        if (std.mem.endsWith(u8, path, ".gif")) {
            var frame_count: i32 = 0;
            self.anim_image = ray.LoadImageAnim(path.ptr, &frame_count);
            self.portrait = ray.LoadTextureFromImage(self.anim_image);
            self.anim_frames = frame_count;
            self.anim_current = 0;
            self.anim_timer = 0.0;
            self.is_animated = true;
        } else {
            self.portrait = ray.LoadTexture(path.ptr);
        }
    }

    pub fn setNpcText(self: *ChatSystem, text: []const u8) !void {
        self.npc_message.clearRetainingCapacity();
        try self.npc_message.appendSlice(text);
        try self.npc_message.append(0);
    }

    pub fn clearInput(self: *ChatSystem) void {
        self.user_input.clearRetainingCapacity();
        self.user_input.append(0) catch {};
    }

    pub fn update(self: *ChatSystem) !ChatResult {
        if (self.is_animated and self.anim_frames > 0) {
            self.anim_timer += ray.GetFrameTime();
            if (self.anim_timer >= 0.1) {
                self.anim_current += 1;
                if (self.anim_current >= self.anim_frames) self.anim_current = 0;
                const next_frame_addr = @intFromPtr(self.anim_image.data) +
                    @as(usize, @intCast(self.anim_image.width * self.anim_image.height * 4 * self.anim_current));
                ray.UpdateTexture(self.portrait, @ptrFromInt(next_frame_addr));
                self.anim_timer = 0.0;
            }
        }
        var char = ray.GetCharPressed();
        while (char > 0) {
            if (char >= 32 and char <= 125) {
                if (self.user_input.items.len > 0) _ = self.user_input.pop();
                try self.user_input.append(@intCast(char));
                try self.user_input.append(0);
            }
            char = ray.GetCharPressed();
        }
        if (ray.IsKeyPressed(ray.KEY_BACKSPACE)) {
            if (self.user_input.items.len > 1) {
                _ = self.user_input.pop();
                _ = self.user_input.pop();
                try self.user_input.append(0);
            }
        }
        if (ray.IsKeyPressed(ray.KEY_ENTER)) return .Submit;
        if (ray.IsKeyPressed(ray.KEY_ESCAPE)) return .Exit;
        return .None;
    }

    pub fn draw(self: *ChatSystem, screen_width: i32, screen_height: i32) void {
        const sw = @as(f32, @floatFromInt(screen_width));
        const sh = @as(f32, @floatFromInt(screen_height));
        const box_y = sh - BOX_HEIGHT - MARGIN;
        const box_rect = ray.Rectangle{ .x = MARGIN, .y = box_y, .width = sw - (MARGIN * 2), .height = BOX_HEIGHT };
        ray.DrawRectangleRec(box_rect, ray.ColorAlpha(ray.BLACK, 0.8));
        ray.DrawRectangleLinesEx(box_rect, 2.0, ray.GREEN);
        if (self.portrait.id > 0) {
            const p_size = 160.0;
            const p_x = MARGIN + 20;
            const p_y = box_y + (BOX_HEIGHT - p_size) / 2.0;
            ray.BeginScissorMode(@intFromFloat(p_x), @intFromFloat(p_y), @intFromFloat(p_size), @intFromFloat(p_size));
            const emotion_color = ray.SKYBLUE;
            ray.DrawRectangle(@intFromFloat(p_x), @intFromFloat(p_y), @intFromFloat(p_size), @intFromFloat(p_size), emotion_color);
            const scale_w = p_size / @as(f32, @floatFromInt(self.portrait.width));
            const scale_h = p_size / @as(f32, @floatFromInt(self.portrait.height));
            const scale = @max(scale_w, scale_h);
            const final_w = @as(f32, @floatFromInt(self.portrait.width)) * scale;
            const final_h = @as(f32, @floatFromInt(self.portrait.height)) * scale;
            const draw_x = p_x + (p_size - final_w) / 2.0;
            const draw_y = p_y + (p_size - final_h) / 2.0;
            ray.DrawTextureEx(self.portrait, .{ .x = draw_x, .y = draw_y }, 0.0, scale, ray.WHITE);
            ray.EndScissorMode();
            ray.DrawRectangleLines(@intFromFloat(p_x), @intFromFloat(p_y), @intFromFloat(p_size), @intFromFloat(p_size), ray.GREEN);
        }
        const text_start_x = MARGIN + 20 + 220;
        const text_start_y = box_y + 20;
        const npc_cstr: [*c]const u8 = @ptrCast(self.npc_message.items.ptr);
        const user_cstr: [*c]const u8 = @ptrCast(self.user_input.items.ptr);
        ray.DrawText("NPC:", @intFromFloat(text_start_x), @intFromFloat(text_start_y), 20, ray.GREEN);
        ray.DrawText(npc_cstr, @intFromFloat(text_start_x), @intFromFloat(text_start_y + 30), 20, ray.WHITE);
        const input_y = text_start_y + 100;
        ray.DrawText("YOU:", @intFromFloat(text_start_x), @intFromFloat(input_y), 20, ray.DARKGREEN);
        ray.DrawText(user_cstr, @intFromFloat(text_start_x), @intFromFloat(input_y + 30), 20, ray.GREEN);
        if (@mod(@as(i32, @intFromFloat(ray.GetTime() * 2.0)), 2) == 0) {
            const width = ray.MeasureText(user_cstr, 20);
            ray.DrawText("_", @as(i32, @intFromFloat(text_start_x)) + width + 5, @as(i32, @intFromFloat(input_y + 30)), 20, ray.GREEN);
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    ray.InitWindow(800, 600, "Chat UI Test");
    defer ray.CloseWindow();
    ray.SetTargetFPS(60);
    var chat = ChatSystem.init(gpa.allocator());
    defer chat.deinit();
    chat.loadPortrait("assets/transp.png");
    try chat.setNpcText("Hello traveler! System is online.");
    while (!ray.WindowShouldClose()) {
        const res = try chat.update();
        if (res == .Submit) {
            try chat.setNpcText("Message received.");
            chat.clearInput();
        }
        ray.BeginDrawing();
        ray.ClearBackground(ray.DARKGRAY);
        ray.DrawGrid(10, 1.0);
        chat.draw(800, 600);
        ray.EndDrawing();
    }
}
