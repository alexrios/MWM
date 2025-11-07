const std = @import("std");

pub const Rect = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
};

pub const Window = struct {
    id: u64,
    app_name: []const u8,
    title: []const u8,
    frame: Rect,
    is_floating: bool,

    pub fn format(self: Window, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("Window {{ id: {}, app: {s}, title: {s}, frame: ({d}, {d}, {d}x{d}), floating: {} }}", .{
            self.id,
            self.app_name,
            self.title,
            self.frame.x,
            self.frame.y,
            self.frame.width,
            self.frame.height,
            self.is_floating,
        });
    }
};

pub const WindowEvent = enum {
    Created,
    Destroyed,
    Focused,
    Moved,
    Resized,
};
