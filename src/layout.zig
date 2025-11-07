const std = @import("std");
const window = @import("window.zig");

pub const LayoutType = enum {
    BSP,
    Columns,
    Rows,
    Floating,
};

pub const LayoutConfig = struct {
    gaps: u32 = 10,
    padding: u32 = 10,
    master_ratio: f32 = 0.5,
};

pub const LayoutCommand = struct {
    window_id: u64,
    frame: window.Rect,
};

// BSP (Binary Space Partitioning) Layout
pub const BSP = struct {
    config: LayoutConfig,

    pub fn init(config: LayoutConfig) BSP {
        return .{ .config = config };
    }

    pub fn calculate(
        self: *BSP,
        allocator: std.mem.Allocator,
        windows: []const window.Window,
        screen_frame: window.Rect,
    ) ![]LayoutCommand {
        if (windows.len == 0) return &[_]LayoutCommand{};

        var commands: std.ArrayList(LayoutCommand) = .{};
        errdefer commands.deinit(allocator);

        // Apply padding to screen frame
        const working_frame = window.Rect{
            .x = screen_frame.x + @as(f32, @floatFromInt(self.config.padding)),
            .y = screen_frame.y + @as(f32, @floatFromInt(self.config.padding)),
            .width = screen_frame.width - @as(f32, @floatFromInt(self.config.padding * 2)),
            .height = screen_frame.height - @as(f32, @floatFromInt(self.config.padding * 2)),
        };

        if (windows.len == 1) {
            try commands.append(allocator, .{
                .window_id = windows[0].id,
                .frame = working_frame,
            });
            return commands.toOwnedSlice(allocator);
        }

        // Simple BSP: split vertically for first window, then horizontally
        const gaps_f32 = @as(f32, @floatFromInt(self.config.gaps));

        // Master window takes left half
        const master_width = working_frame.width * self.config.master_ratio - gaps_f32 / 2.0;
        try commands.append(allocator, .{
            .window_id = windows[0].id,
            .frame = .{
                .x = working_frame.x,
                .y = working_frame.y,
                .width = master_width,
                .height = working_frame.height,
            },
        });

        // Stack remaining windows on right
        const stack_x = working_frame.x + master_width + gaps_f32;
        const stack_width = working_frame.width - master_width - gaps_f32;
        const stack_count = windows.len - 1;
        const stack_height = (working_frame.height - gaps_f32 * @as(f32, @floatFromInt(stack_count - 1))) / @as(f32, @floatFromInt(stack_count));

        for (windows[1..], 0..) |win, i| {
            const y_offset = @as(f32, @floatFromInt(i)) * (stack_height + gaps_f32);
            try commands.append(allocator, .{
                .window_id = win.id,
                .frame = .{
                    .x = stack_x,
                    .y = working_frame.y + y_offset,
                    .width = stack_width,
                    .height = stack_height,
                },
            });
        }

        return commands.toOwnedSlice(allocator);
    }
};

test "BSP layout single window" {
    var bsp = BSP.init(.{});
    const windows = [_]window.Window{.{
        .id = 1,
        .app_name = "Test",
        .title = "Window 1",
        .frame = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
        .is_floating = false,
    }};

    const screen = window.Rect{ .x = 0, .y = 0, .width = 1920, .height = 1080 };
    const commands = try bsp.calculate(std.testing.allocator, &windows, screen);
    defer std.testing.allocator.free(commands);

    try std.testing.expectEqual(@as(usize, 1), commands.len);
    try std.testing.expectEqual(@as(u64, 1), commands[0].window_id);
}

test "BSP layout two windows" {
    var bsp = BSP.init(.{ .gaps = 10, .padding = 10, .master_ratio = 0.6 });
    const windows = [_]window.Window{
        .{
            .id = 1,
            .app_name = "Test",
            .title = "Window 1",
            .frame = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            .is_floating = false,
        },
        .{
            .id = 2,
            .app_name = "Test",
            .title = "Window 2",
            .frame = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            .is_floating = false,
        },
    };

    const screen = window.Rect{ .x = 0, .y = 0, .width = 1920, .height = 1080 };
    const commands = try bsp.calculate(std.testing.allocator, &windows, screen);
    defer std.testing.allocator.free(commands);

    try std.testing.expectEqual(@as(usize, 2), commands.len);
    try std.testing.expectEqual(@as(u64, 1), commands[0].window_id);
    try std.testing.expectEqual(@as(u64, 2), commands[1].window_id);
}
