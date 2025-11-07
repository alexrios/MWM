import Foundation

// C bridge structures matching Zig types
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

// C function declarations from Zig
@_silgen_name("mwm_init")
func mwm_init()

@_silgen_name("mwm_deinit")
func mwm_deinit()

@_silgen_name("mwm_add_window")
func mwm_add_window(_ window: MWMWindow)

@_silgen_name("mwm_remove_window")
func mwm_remove_window(_ window_id: UInt64)

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

@_silgen_name("mwm_set_layout_config")
func mwm_set_layout_config(_ gaps: UInt32, _ padding: UInt32, _ master_ratio: Float)

@_silgen_name("mwm_get_master_ratio")
func mwm_get_master_ratio() -> Float

@_silgen_name("mwm_debug_print_windows")
func mwm_debug_print_windows()

@_silgen_name("mwm_get_window_id_at_index")
func mwm_get_window_id_at_index(_ index: Int) -> UInt64

@_silgen_name("mwm_get_window_index")
func mwm_get_window_index(_ window_id: UInt64) -> Int

@_silgen_name("mwm_swap_windows")
func mwm_swap_windows(_ index1: Int, _ index2: Int)

@_silgen_name("mwm_move_to_front")
func mwm_move_to_front(_ window_id: UInt64) -> Bool

// Swift wrapper for Zig window manager
class WindowManagerBridge {
    init() {
        mwm_init()
        print("Zig window manager initialized")
    }

    deinit {
        mwm_deinit()
        print("Zig window manager shutdown")
    }

    func addWindow(id: UInt64, appName: String, title: String, frame: NSRect, isFloating: Bool = false) {
        appName.withCString { appNamePtr in
            title.withCString { titlePtr in
                let mwmRect = MWMRect(
                    x: Float(frame.origin.x),
                    y: Float(frame.origin.y),
                    width: Float(frame.size.width),
                    height: Float(frame.size.height)
                )

                let mwmWindow = MWMWindow(
                    id: id,
                    app_name: appNamePtr,
                    title: titlePtr,
                    frame: mwmRect,
                    is_floating: isFloating
                )

                mwm_add_window(mwmWindow)
            }
        }
    }

    func removeWindow(id: UInt64) {
        mwm_remove_window(id)
    }

    func getWindowCount() -> Int {
        return mwm_get_window_count()
    }

    func calculateLayout(screenFrame: NSRect) -> [(windowId: UInt64, frame: NSRect)] {
        let maxCommands = 100
        var commands = [MWMLayoutCommand](repeating: MWMLayoutCommand(window_id: 0, frame: MWMRect(x: 0, y: 0, width: 0, height: 0)), count: maxCommands)

        let count = commands.withUnsafeMutableBufferPointer { buffer in
            mwm_calculate_layout(
                Float(screenFrame.origin.x),
                Float(screenFrame.origin.y),
                Float(screenFrame.size.width),
                Float(screenFrame.size.height),
                buffer.baseAddress!,
                maxCommands
            )
        }

        return commands.prefix(count).map { cmd in
            let frame = NSRect(
                x: CGFloat(cmd.frame.x),
                y: CGFloat(cmd.frame.y),
                width: CGFloat(cmd.frame.width),
                height: CGFloat(cmd.frame.height)
            )
            return (windowId: cmd.window_id, frame: frame)
        }
    }

    func setLayoutConfig(gaps: UInt32, padding: UInt32, masterRatio: Float) {
        mwm_set_layout_config(gaps, padding, masterRatio)
    }

    func getMasterRatio() -> Float {
        return mwm_get_master_ratio()
    }

    func debugPrintWindows() {
        mwm_debug_print_windows()
    }

    func shutdown() {
        mwm_deinit()
    }

    // Window ordering methods
    func getWindowIdAtIndex(_ index: Int) -> UInt64 {
        return mwm_get_window_id_at_index(index)
    }

    func getWindowIndex(_ windowId: UInt64) -> Int {
        return mwm_get_window_index(windowId)
    }

    func swapWindows(index1: Int, index2: Int) {
        mwm_swap_windows(index1, index2)
    }

    func moveToFront(_ windowId: UInt64) -> Bool {
        return mwm_move_to_front(windowId)
    }
}
