import Cocoa
import ApplicationServices

// Helper class for controlling windows via Accessibility API
class WindowController {

    // Set window position
    static func setPosition(window: AXUIElement, x: CGFloat, y: CGFloat) -> Bool {
        var position = CGPoint(x: x, y: y)
        guard let positionValue = AXValueCreate(.cgPoint, &position) else {
            return false
        }
        let result = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        return result == .success
    }

    // Set window size
    static func setSize(window: AXUIElement, width: CGFloat, height: CGFloat) -> Bool {
        var size = CGSize(width: width, height: height)
        guard let sizeValue = AXValueCreate(.cgSize, &size) else {
            return false
        }
        let result = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        return result == .success
    }

    // Set window frame (position + size)
    static func setFrame(window: AXUIElement, frame: NSRect) -> Bool {
        let positionSet = setPosition(window: window, x: frame.origin.x, y: frame.origin.y)
        let sizeSet = setSize(window: window, width: frame.size.width, height: frame.size.height)
        return positionSet && sizeSet
    }

    // Get window position
    static func getPosition(window: AXUIElement) -> CGPoint? {
        var positionRef: AnyObject?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef) == .success else {
            return nil
        }

        guard let positionValue = positionRef else {
            return nil
        }

        var position = CGPoint.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position) else {
            return nil
        }

        return position
    }

    // Get window size
    static func getSize(window: AXUIElement) -> CGSize? {
        var sizeRef: AnyObject?
        guard AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success else {
            return nil
        }

        guard let sizeValue = sizeRef else {
            return nil
        }

        var size = CGSize.zero
        guard AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else {
            return nil
        }

        return size
    }

    // Get window frame
    static func getFrame(window: AXUIElement) -> NSRect? {
        guard let position = getPosition(window: window),
              let size = getSize(window: window) else {
            return nil
        }

        return NSRect(origin: position, size: size)
    }

    // Focus a window (bring to front)
    static func focus(window: AXUIElement) -> Bool {
        let result = AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        if result == .success {
            return true
        }
        // Try alternative method
        let raiseResult = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        return raiseResult == .success
    }

    // Get the currently focused window
    static func getFocusedWindow() -> AXUIElement? {
        // Get the frontmost application
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        // Get focused window
        var focusedWindowRef: AnyObject?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindowRef)

        if result == .success, let window = focusedWindowRef {
            return (window as! AXUIElement)
        }

        return nil
    }

    // Get window title
    static func getTitle(window: AXUIElement) -> String? {
        var titleRef: AnyObject?
        guard AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success else {
            return nil
        }
        return titleRef as? String
    }

    // Check if window is minimized
    static func isMinimized(window: AXUIElement) -> Bool {
        var minimizedRef: AnyObject?
        guard AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedRef) == .success else {
            return false
        }

        if let minimized = minimizedRef as? Bool {
            return minimized
        }

        return false
    }

    // Get all windows for an application
    static func getWindows(forApp app: NSRunningApplication) -> [AXUIElement] {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        var windowsRef: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success else {
            return []
        }

        if let windows = windowsRef as? [AXUIElement] {
            return windows
        }

        return []
    }

    // Animate window movement (smooth transition)
    static func animateFrame(window: AXUIElement, to targetFrame: NSRect, duration: TimeInterval = 0.2) {
        guard getFrame(window: window) != nil else {
            // If we can't get current frame, just set directly
            _ = setFrame(window: window, frame: targetFrame)
            return
        }

        // For now, just set directly (smooth animation would require timer/CADisplayLink)
        // TODO: Implement smooth animation with duration parameter
        _ = duration // Suppress unused warning
        _ = setFrame(window: window, frame: targetFrame)
    }
}
