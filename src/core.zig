const std = @import("std");

// Re-export submodules
pub const window = @import("window.zig");
pub const layout = @import("layout.zig");
pub const bridge = @import("bridge.zig");

// Core state management
pub const WindowManager = struct {
    allocator: std.mem.Allocator,
    windows: std.ArrayList(window.Window),
    current_layout: layout.LayoutType,
    layout_config: layout.LayoutConfig,

    pub fn init(allocator: std.mem.Allocator) WindowManager {
        return .{
            .allocator = allocator,
            .windows = .{},
            .current_layout = .BSP,
            .layout_config = .{
                .gaps = 10,
                .padding = 10,
                .master_ratio = 0.5,
            },
        };
    }

    pub fn deinit(self: *WindowManager) void {
        self.windows.deinit(self.allocator);
    }

    pub fn addWindow(self: *WindowManager, win: window.Window) !void {
        try self.windows.append(self.allocator, win);
    }

    pub fn removeWindow(self: *WindowManager, window_id: u64) void {
        for (self.windows.items, 0..) |win, i| {
            if (win.id == window_id) {
                _ = self.windows.orderedRemove(i);
                return;
            }
        }
    }

    pub fn getWindow(self: *WindowManager, window_id: u64) ?*window.Window {
        for (self.windows.items) |*win| {
            if (win.id == window_id) {
                return win;
            }
        }
        return null;
    }

    pub fn getWindowByIndex(self: *WindowManager, index: usize) ?*window.Window {
        if (index < self.windows.items.len) {
            return &self.windows.items[index];
        }
        return null;
    }

    pub fn getWindowIndex(self: *WindowManager, window_id: u64) ?usize {
        for (self.windows.items, 0..) |win, i| {
            if (win.id == window_id) {
                return i;
            }
        }
        return null;
    }

    pub fn swapWindows(self: *WindowManager, index1: usize, index2: usize) void {
        if (index1 >= self.windows.items.len or index2 >= self.windows.items.len) {
            return;
        }
        const temp = self.windows.items[index1];
        self.windows.items[index1] = self.windows.items[index2];
        self.windows.items[index2] = temp;
    }

    pub fn moveToFront(self: *WindowManager, window_id: u64) bool {
        const index = self.getWindowIndex(window_id) orelse return false;
        if (index == 0) return true; // Already at front

        const win = self.windows.items[index];
        // Shift windows down
        var i = index;
        while (i > 0) : (i -= 1) {
            self.windows.items[i] = self.windows.items[i - 1];
        }
        self.windows.items[0] = win;
        return true;
    }

    pub fn getWindowCount(self: *WindowManager) usize {
        return self.windows.items.len;
    }

    pub fn setLayoutConfig(self: *WindowManager, config: layout.LayoutConfig) void {
        self.layout_config = config;
    }
};

// Import comprehensive tests
test {
    _ = @import("core_test.zig");
}
