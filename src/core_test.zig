const std = @import("std");
const testing = std.testing;
const core = @import("core.zig");
const window = @import("window.zig");

test "WindowManager initialization" {
    const allocator = testing.allocator;

    var wm = core.WindowManager.init(allocator);
    defer wm.deinit();

    try testing.expectEqual(@as(usize, 0), wm.windows.items.len);
    try testing.expectEqual(core.layout.LayoutType.BSP, wm.current_layout);
    try testing.expectEqual(@as(u32, 10), wm.layout_config.gaps);
    try testing.expectEqual(@as(u32, 10), wm.layout_config.padding);
    try testing.expectEqual(@as(f32, 0.5), wm.layout_config.master_ratio);
}

test "WindowManager add window" {
    const allocator = testing.allocator;

    var wm = core.WindowManager.init(allocator);
    defer wm.deinit();

    const win = window.Window{
        .id = 1,
        .app_name = "TestApp",
        .title = "Test Window",
        .frame = .{ .x = 0, .y = 0, .width = 100, .height = 100 },
        .is_floating = false,
    };

    try wm.addWindow(win);
    try testing.expectEqual(@as(usize, 1), wm.windows.items.len);
    try testing.expectEqual(@as(u64, 1), wm.windows.items[0].id);
}

test "WindowManager remove window" {
    const allocator = testing.allocator;

    var wm = core.WindowManager.init(allocator);
    defer wm.deinit();

    const win1 = window.Window{
        .id = 1,
        .app_name = "TestApp",
        .title = "Window 1",
        .frame = .{ .x = 0, .y = 0, .width = 100, .height = 100 },
        .is_floating = false,
    };

    const win2 = window.Window{
        .id = 2,
        .app_name = "TestApp",
        .title = "Window 2",
        .frame = .{ .x = 100, .y = 0, .width = 100, .height = 100 },
        .is_floating = false,
    };

    try wm.addWindow(win1);
    try wm.addWindow(win2);
    try testing.expectEqual(@as(usize, 2), wm.windows.items.len);

    wm.removeWindow(1);
    try testing.expectEqual(@as(usize, 1), wm.windows.items.len);
    try testing.expectEqual(@as(u64, 2), wm.windows.items[0].id);
}

test "WindowManager get window by ID" {
    const allocator = testing.allocator;

    var wm = core.WindowManager.init(allocator);
    defer wm.deinit();

    const win = window.Window{
        .id = 42,
        .app_name = "TestApp",
        .title = "Test Window",
        .frame = .{ .x = 0, .y = 0, .width = 100, .height = 100 },
        .is_floating = false,
    };

    try wm.addWindow(win);

    const found = wm.getWindow(42);
    try testing.expect(found != null);
    try testing.expectEqual(@as(u64, 42), found.?.id);

    const not_found = wm.getWindow(999);
    try testing.expect(not_found == null);
}

test "WindowManager get window by index" {
    const allocator = testing.allocator;

    var wm = core.WindowManager.init(allocator);
    defer wm.deinit();

    const win1 = window.Window{
        .id = 1,
        .app_name = "TestApp",
        .title = "Window 1",
        .frame = .{ .x = 0, .y = 0, .width = 100, .height = 100 },
        .is_floating = false,
    };

    const win2 = window.Window{
        .id = 2,
        .app_name = "TestApp",
        .title = "Window 2",
        .frame = .{ .x = 100, .y = 0, .width = 100, .height = 100 },
        .is_floating = false,
    };

    try wm.addWindow(win1);
    try wm.addWindow(win2);

    const first = wm.getWindowByIndex(0);
    try testing.expect(first != null);
    try testing.expectEqual(@as(u64, 1), first.?.id);

    const second = wm.getWindowByIndex(1);
    try testing.expect(second != null);
    try testing.expectEqual(@as(u64, 2), second.?.id);

    const out_of_bounds = wm.getWindowByIndex(10);
    try testing.expect(out_of_bounds == null);
}

test "WindowManager get window index" {
    const allocator = testing.allocator;

    var wm = core.WindowManager.init(allocator);
    defer wm.deinit();

    const win1 = window.Window{
        .id = 100,
        .app_name = "TestApp",
        .title = "Window 1",
        .frame = .{ .x = 0, .y = 0, .width = 100, .height = 100 },
        .is_floating = false,
    };

    const win2 = window.Window{
        .id = 200,
        .app_name = "TestApp",
        .title = "Window 2",
        .frame = .{ .x = 100, .y = 0, .width = 100, .height = 100 },
        .is_floating = false,
    };

    try wm.addWindow(win1);
    try wm.addWindow(win2);

    const idx1 = wm.getWindowIndex(100);
    try testing.expect(idx1 != null);
    try testing.expectEqual(@as(usize, 0), idx1.?);

    const idx2 = wm.getWindowIndex(200);
    try testing.expect(idx2 != null);
    try testing.expectEqual(@as(usize, 1), idx2.?);

    const not_found = wm.getWindowIndex(999);
    try testing.expect(not_found == null);
}

test "WindowManager swap windows" {
    const allocator = testing.allocator;

    var wm = core.WindowManager.init(allocator);
    defer wm.deinit();

    const win1 = window.Window{
        .id = 1,
        .app_name = "TestApp",
        .title = "Window 1",
        .frame = .{ .x = 0, .y = 0, .width = 100, .height = 100 },
        .is_floating = false,
    };

    const win2 = window.Window{
        .id = 2,
        .app_name = "TestApp",
        .title = "Window 2",
        .frame = .{ .x = 100, .y = 0, .width = 100, .height = 100 },
        .is_floating = false,
    };

    try wm.addWindow(win1);
    try wm.addWindow(win2);

    // Before swap
    try testing.expectEqual(@as(u64, 1), wm.windows.items[0].id);
    try testing.expectEqual(@as(u64, 2), wm.windows.items[1].id);

    // Swap
    wm.swapWindows(0, 1);

    // After swap
    try testing.expectEqual(@as(u64, 2), wm.windows.items[0].id);
    try testing.expectEqual(@as(u64, 1), wm.windows.items[1].id);
}

test "WindowManager move window to front" {
    const allocator = testing.allocator;

    var wm = core.WindowManager.init(allocator);
    defer wm.deinit();

    const win1 = window.Window{
        .id = 1,
        .app_name = "TestApp",
        .title = "Window 1",
        .frame = .{ .x = 0, .y = 0, .width = 100, .height = 100 },
        .is_floating = false,
    };

    const win2 = window.Window{
        .id = 2,
        .app_name = "TestApp",
        .title = "Window 2",
        .frame = .{ .x = 100, .y = 0, .width = 100, .height = 100 },
        .is_floating = false,
    };

    const win3 = window.Window{
        .id = 3,
        .app_name = "TestApp",
        .title = "Window 3",
        .frame = .{ .x = 200, .y = 0, .width = 100, .height = 100 },
        .is_floating = false,
    };

    try wm.addWindow(win1);
    try wm.addWindow(win2);
    try wm.addWindow(win3);

    // Before: [1, 2, 3]
    try testing.expectEqual(@as(u64, 1), wm.windows.items[0].id);
    try testing.expectEqual(@as(u64, 2), wm.windows.items[1].id);
    try testing.expectEqual(@as(u64, 3), wm.windows.items[2].id);

    // Move window 3 to front
    const result = wm.moveToFront(3);
    try testing.expect(result);

    // After: [3, 1, 2]
    try testing.expectEqual(@as(u64, 3), wm.windows.items[0].id);
    try testing.expectEqual(@as(u64, 1), wm.windows.items[1].id);
    try testing.expectEqual(@as(u64, 2), wm.windows.items[2].id);

    // Try to move non-existent window
    const failed = wm.moveToFront(999);
    try testing.expect(!failed);
}

test "WindowManager window count" {
    const allocator = testing.allocator;

    var wm = core.WindowManager.init(allocator);
    defer wm.deinit();

    try testing.expectEqual(@as(usize, 0), wm.getWindowCount());

    const win = window.Window{
        .id = 1,
        .app_name = "TestApp",
        .title = "Test Window",
        .frame = .{ .x = 0, .y = 0, .width = 100, .height = 100 },
        .is_floating = false,
    };

    try wm.addWindow(win);
    try testing.expectEqual(@as(usize, 1), wm.getWindowCount());
}

test "WindowManager set layout config" {
    const allocator = testing.allocator;

    var wm = core.WindowManager.init(allocator);
    defer wm.deinit();

    wm.setLayoutConfig(.{
        .gaps = 20,
        .padding = 15,
        .master_ratio = 0.6,
    });

    try testing.expectEqual(@as(u32, 20), wm.layout_config.gaps);
    try testing.expectEqual(@as(u32, 15), wm.layout_config.padding);
    try testing.expectEqual(@as(f32, 0.6), wm.layout_config.master_ratio);
}
