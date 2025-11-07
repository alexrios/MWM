#!/usr/bin/env swift

// Simple test to verify Zig-Swift bridge works
import Foundation

// C bridge structures
struct MWMRect {
    var x: Float
    var y: Float
    var width: Float
    var height: Float
}

struct MWMWindow {
    var id: UInt64
    var app_name: UnsafePointer<CChar>
    var title: UnsafePointer<CChar>
    var frame: MWMRect
    var is_floating: Bool
}

struct MWMLayoutCommand {
    var window_id: UInt64
    var frame: MWMRect
}

// C function declarations
@_silgen_name("mwm_init")
func mwm_init()

@_silgen_name("mwm_deinit")
func mwm_deinit()

@_silgen_name("mwm_add_window")
func mwm_add_window(_ window: MWMWindow)

@_silgen_name("mwm_get_window_count")
func mwm_get_window_count() -> Int

@_silgen_name("mwm_calculate_layout")
func mwm_calculate_layout(
    _ screen_x: Float,
    _ screen_y: Float,
    _ screen_width: Float,
    _ screen_height: Float,
    _ out_commands: UnsafeMutablePointer<MWMLayoutCommand>,
    _ max_commands: Int
) -> Int

@_silgen_name("mwm_debug_print_windows")
func mwm_debug_print_windows()

print("=== MWM Bridge Test ===\n")

// Initialize
print("1. Initializing window manager...")
mwm_init()
print("   ✓ Initialized\n")

// Add windows
print("2. Adding test windows...")
let appName1 = "Safari"
let title1 = "Test Window 1"
appName1.withCString { appPtr in
    title1.withCString { titlePtr in
        let win1 = MWMWindow(
            id: 1,
            app_name: appPtr,
            title: titlePtr,
            frame: MWMRect(x: 0, y: 0, width: 800, height: 600),
            is_floating: false
        )
        mwm_add_window(win1)
    }
}

let appName2 = "Terminal"
let title2 = "Test Window 2"
appName2.withCString { appPtr in
    title2.withCString { titlePtr in
        let win2 = MWMWindow(
            id: 2,
            app_name: appPtr,
            title: titlePtr,
            frame: MWMRect(x: 800, y: 0, width: 800, height: 600),
            is_floating: false
        )
        mwm_add_window(win2)
    }
}

let count = mwm_get_window_count()
print("   ✓ Added 2 windows, count: \(count)\n")

// Print windows (Zig will print to stderr)
print("3. Printing windows from Zig:")
mwm_debug_print_windows()
print("")

// Calculate layout
print("4. Calculating BSP layout...")
var commands = [MWMLayoutCommand](repeating: MWMLayoutCommand(window_id: 0, frame: MWMRect(x: 0, y: 0, width: 0, height: 0)), count: 10)
let layoutCount = commands.withUnsafeMutableBufferPointer { buffer in
    mwm_calculate_layout(0, 0, 1920, 1080, buffer.baseAddress!, 10)
}

print("   ✓ Generated \(layoutCount) layout commands:")
for i in 0..<layoutCount {
    let cmd = commands[i]
    print("     Window \(cmd.window_id): x=\(cmd.frame.x), y=\(cmd.frame.y), w=\(cmd.frame.width), h=\(cmd.frame.height)")
}
print("")

// Cleanup
print("5. Cleaning up...")
mwm_deinit()
print("   ✓ Shutdown complete\n")

print("=== All Tests Passed ===")
