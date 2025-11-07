import Cocoa

/// Visual focus indicator that draws a colored border around the focused window
class FocusIndicator {
    private var borderWindows: [NSWindow] = []
    private let borderWidth: CGFloat = 4
    private let borderColor = NSColor.systemBlue

    init() {}

    /// Show border around the specified window frame
    func showBorder(around frame: NSRect) {
        // Clear old borders first in separate autorelease pool
        autoreleasepool {
            borderWindows.forEach { $0.close() }
            borderWindows.removeAll()
        }

        // Create and show new borders in separate autorelease pool
        autoreleasepool {
            borderWindows = createBorderWindows(for: frame)
            borderWindows.forEach { $0.orderFront(nil) }
        }
    }

    /// Hide the focus border
    func clearBorder() {
        autoreleasepool {
            borderWindows.forEach { $0.close() }
            borderWindows.removeAll()
        }
    }

    /// Create four overlay windows to form a border
    private func createBorderWindows(for frame: NSRect) -> [NSWindow] {
        var windows: [NSWindow] = []

        // Top border
        windows.append(createBorderWindow(
            x: frame.origin.x,
            y: frame.origin.y + frame.size.height - borderWidth,
            width: frame.size.width,
            height: borderWidth
        ))

        // Bottom border
        windows.append(createBorderWindow(
            x: frame.origin.x,
            y: frame.origin.y,
            width: frame.size.width,
            height: borderWidth
        ))

        // Left border
        windows.append(createBorderWindow(
            x: frame.origin.x,
            y: frame.origin.y,
            width: borderWidth,
            height: frame.size.height
        ))

        // Right border
        windows.append(createBorderWindow(
            x: frame.origin.x + frame.size.width - borderWidth,
            y: frame.origin.y,
            width: borderWidth,
            height: frame.size.height
        ))

        return windows
    }

    /// Create a single border overlay window
    private func createBorderWindow(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> NSWindow {
        let rect = NSRect(x: x, y: y, width: width, height: height)

        let window = NSWindow(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.backgroundColor = borderColor
        window.isOpaque = false
        window.alphaValue = 0.8
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isReleasedWhenClosed = false

        return window
    }
}
