const std = @import("std");
const core = @import("core.zig");
const window = @import("window.zig");
const layout = @import("layout.zig");

// Global allocator for C API
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

// Global window manager instance
var window_manager: ?core.WindowManager = null;

// C-compatible structures
pub const CRect = extern struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
};

pub const CWindow = extern struct {
    id: u64,
    app_name: [*:0]const u8,
    title: [*:0]const u8,
    frame: CRect,
    is_floating: bool,
};

pub const CLayoutCommand = extern struct {
    window_id: u64,
    frame: CRect,
};

// C API exports
export fn mwm_init() void {
    if (window_manager == null) {
        window_manager = core.WindowManager.init(allocator);
    }
}

export fn mwm_deinit() void {
    if (window_manager) |*wm| {
        wm.deinit();
        window_manager = null;
    }
}

export fn mwm_add_window(c_window: CWindow) void {
    if (window_manager) |*wm| {
        const win = window.Window{
            .id = c_window.id,
            .app_name = std.mem.span(c_window.app_name),
            .title = std.mem.span(c_window.title),
            .frame = .{
                .x = c_window.frame.x,
                .y = c_window.frame.y,
                .width = c_window.frame.width,
                .height = c_window.frame.height,
            },
            .is_floating = c_window.is_floating,
        };
        wm.addWindow(win) catch |err| {
            std.debug.print("Error adding window: {}\n", .{err});
        };
    }
}

export fn mwm_remove_window(window_id: u64) void {
    if (window_manager) |*wm| {
        wm.removeWindow(window_id);
    }
}

export fn mwm_get_window_count() usize {
    if (window_manager) |*wm| {
        return wm.getWindowCount();
    }
    return 0;
}

export fn mwm_get_window_id_at_index(index: usize) u64 {
    if (window_manager) |*wm| {
        if (wm.getWindowByIndex(index)) |win| {
            return win.id;
        }
    }
    return 0;
}

export fn mwm_get_window_index(window_id: u64) isize {
    if (window_manager) |*wm| {
        if (wm.getWindowIndex(window_id)) |index| {
            return @intCast(index);
        }
    }
    return -1;
}

export fn mwm_swap_windows(index1: usize, index2: usize) void {
    if (window_manager) |*wm| {
        wm.swapWindows(index1, index2);
    }
}

export fn mwm_move_to_front(window_id: u64) bool {
    if (window_manager) |*wm| {
        return wm.moveToFront(window_id);
    }
    return false;
}

export fn mwm_calculate_layout(
    screen_x: f32,
    screen_y: f32,
    screen_width: f32,
    screen_height: f32,
    out_commands: [*c]CLayoutCommand,
    max_commands: usize,
) usize {
    if (window_manager) |*wm| {
        const screen_frame = window.Rect{
            .x = screen_x,
            .y = screen_y,
            .width = screen_width,
            .height = screen_height,
        };

        var bsp = layout.BSP.init(wm.layout_config);

        const commands = bsp.calculate(
            allocator,
            wm.windows.items,
            screen_frame,
        ) catch |err| {
            std.debug.print("Error calculating layout: {}\n", .{err});
            return 0;
        };
        defer allocator.free(commands);

        const count = @min(commands.len, max_commands);
        for (commands[0..count], 0..) |cmd, i| {
            out_commands[i] = .{
                .window_id = cmd.window_id,
                .frame = .{
                    .x = cmd.frame.x,
                    .y = cmd.frame.y,
                    .width = cmd.frame.width,
                    .height = cmd.frame.height,
                },
            };
        }

        return count;
    }
    return 0;
}

export fn mwm_set_layout_config(gaps: u32, padding: u32, master_ratio: f32) void {
    if (window_manager) |*wm| {
        wm.layout_config = .{
            .gaps = gaps,
            .padding = padding,
            .master_ratio = master_ratio,
        };
    }
}

export fn mwm_get_master_ratio() f32 {
    if (window_manager) |*wm| {
        return wm.layout_config.master_ratio;
    }
    return 0.5;
}

// Debug function
export fn mwm_debug_print_windows() void {
    if (window_manager) |*wm| {
        std.debug.print("=== Window Manager State ===\n", .{});
        std.debug.print("Total windows: {d}\n", .{wm.windows.items.len});
        for (wm.windows.items) |win| {
            std.debug.print("  {any}\n", .{win});
        }
    }
}
