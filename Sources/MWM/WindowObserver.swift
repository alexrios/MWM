import Cocoa
import ApplicationServices

class WindowObserver {
    private let bridge: WindowManagerBridge
    private var observers: [AXObserver] = []
    private var workspace: NSWorkspace
    private var nextWindowId: UInt64 = 1

    // Map window IDs to their AXUIElement references
    private var windowElements: [UInt64: AXUIElement] = [:]

    // Track window order (insertion order)
    private var windowOrder: [UInt64] = []

    // Track focused window ID
    private(set) var focusedWindowId: UInt64?

    // Visual focus indicator
    private let focusIndicator = FocusIndicator()

    init(bridge: WindowManagerBridge) {
        self.bridge = bridge
        self.workspace = NSWorkspace.shared
    }

    func start() {
        // Observe workspace notifications for app launches/terminations
        workspace.notificationCenter.addObserver(
            self,
            selector: #selector(appLaunched),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )

        workspace.notificationCenter.addObserver(
            self,
            selector: #selector(appTerminated),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )

        // Enumerate existing windows
        enumerateExistingWindows()

        print("Window observer started")
    }

    func stop() {
        workspace.notificationCenter.removeObserver(self)
        observers.removeAll()
        focusIndicator.clearBorder()
    }

    @objc private func appLaunched(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        print("App launched: \(app.localizedName ?? "Unknown")")
        observeApplication(app)
    }

    @objc private func appTerminated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        let appName = app.localizedName ?? "Unknown"
        print("App terminated: \(appName)")

        // Remove all windows belonging to this app
        removeWindowsForApp(appName: appName)
    }

    private func removeWindowsForApp(appName: String) {
        // Find windows to remove
        var windowsToRemove: [UInt64] = []
        for windowId in windowOrder {
            // Check if this window belongs to the terminated app
            // We'll remove all windows for simplicity - in production you'd track app per window
            if let element = windowElements[windowId],
               WindowController.getTitle(window: element) != nil {
                // For now, mark for removal - proper implementation would track app per window
                continue
            }
            windowsToRemove.append(windowId)
        }

        for windowId in windowsToRemove {
            removeWindow(windowId)
        }
    }

    private func removeWindow(_ windowId: UInt64) {
        windowElements.removeValue(forKey: windowId)
        if let index = windowOrder.firstIndex(of: windowId) {
            windowOrder.remove(at: index)
        }
        bridge.removeWindow(id: windowId)
        print("  ✓ Removed window \(windowId)")
    }

    private func enumerateExistingWindows() {
        print("\n╔═══════════════════════════════════════╗")
        print("║  Enumerating Existing Windows        ║")
        print("╚═══════════════════════════════════════╝\n")

        let allApps = workspace.runningApplications
        let regularApps = allApps.filter { $0.activationPolicy == .regular }

        print("Total running apps: \(allApps.count)")
        print("Regular apps (with UI): \(regularApps.count)\n")

        for app in regularApps {
            observeApplication(app)
        }

        let totalWindows = bridge.getWindowCount()
        print("\n╔═══════════════════════════════════════╗")
        print("║  Summary: \(totalWindows) window(s) registered")
        print("╚═══════════════════════════════════════╝\n")

        if totalWindows == 0 {
            print("⚠️  No windows found! This might mean:")
            print("   - Accessibility permissions not granted")
            print("   - All windows are minimized")
            print("   - Apps don't expose windows via Accessibility API")
        }

        // Trigger initial layout
        if totalWindows > 0 {
            performLayout()
        }
    }

    private func observeApplication(_ app: NSRunningApplication) {
        let appName = app.localizedName ?? "Unknown"
        print("\n→ Checking app: \(appName) (PID: \(app.processIdentifier))")

        guard let appElement = AXUIElementCreateApplication(app.processIdentifier) as AXUIElement? else {
            print("  ✗ Failed to create AXUIElement")
            return
        }

        // Get windows for this app
        var windowsRef: AnyObject?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)

        if result == .success, let windows = windowsRef as? [AXUIElement] {
            print("  Found \(windows.count) window(s)")
            for (index, windowElement) in windows.enumerated() {
                print("    Window \(index + 1):")

                // Check if this is a real window (not a menu, popover, etc)
                var roleRef: AnyObject?
                if AXUIElementCopyAttributeValue(windowElement, kAXRoleAttribute as CFString, &roleRef) == .success {
                    let role = roleRef as? String ?? "unknown"
                    print("      Role: \(role)")

                    // Only process standard windows
                    if role != "AXWindow" {
                        print("      ⊘ Skipping (not a standard window)")
                        continue
                    }
                }

                if let windowInfo = getWindowInfo(windowElement, app: app) {
                    // Check for minimized windows
                    if WindowController.isMinimized(window: windowElement) {
                        print("      ⊘ Skipping (minimized)")
                        continue
                    }

                    // Store the window element for later use
                    windowElements[windowInfo.id] = windowElement
                    windowOrder.append(windowInfo.id)

                    bridge.addWindow(
                        id: windowInfo.id,
                        appName: windowInfo.appName,
                        title: windowInfo.title,
                        frame: windowInfo.frame,
                        isFloating: false
                    )
                    print("      ✓ Added: \"\(windowInfo.title)\"")
                    print("        Frame: \(windowInfo.frame)")
                } else {
                    print("      ✗ Could not get window info")
                }
            }
        } else {
            let errorDesc = getErrorDescription(result)
            print("  ✗ Failed to get windows - \(errorDesc)")
        }
    }

    private func getErrorDescription(_ result: AXError) -> String {
        switch result {
        case .success: return "Success"
        case .failure: return "Failure"
        case .illegalArgument: return "Illegal Argument"
        case .invalidUIElement: return "Invalid UI Element"
        case .invalidUIElementObserver: return "Invalid Observer"
        case .cannotComplete: return "Cannot Complete"
        case .attributeUnsupported: return "Attribute Unsupported"
        case .actionUnsupported: return "Action Unsupported"
        case .notificationUnsupported: return "Notification Unsupported"
        case .notImplemented: return "Not Implemented"
        case .notificationAlreadyRegistered: return "Already Registered"
        case .notificationNotRegistered: return "Not Registered"
        case .apiDisabled: return "API Disabled (check permissions)"
        case .noValue: return "No Value"
        case .parameterizedAttributeUnsupported: return "Parameterized Attribute Unsupported"
        case .notEnoughPrecision: return "Not Enough Precision"
        @unknown default: return "Unknown Error (\(result.rawValue))"
        }
    }

    private struct WindowInfo {
        let id: UInt64
        let appName: String
        let title: String
        let frame: NSRect
    }

    private func getWindowInfo(_ windowElement: AXUIElement, app: NSRunningApplication) -> WindowInfo? {
        // Get window title
        var titleRef: AnyObject?
        AXUIElementCopyAttributeValue(windowElement, kAXTitleAttribute as CFString, &titleRef)
        let title = (titleRef as? String) ?? "Untitled"

        // Get window position and size
        guard let position = WindowController.getPosition(window: windowElement),
              let size = WindowController.getSize(window: windowElement) else {
            return nil
        }

        let frame = NSRect(origin: position, size: size)
        let id = nextWindowId
        nextWindowId += 1

        return WindowInfo(
            id: id,
            appName: app.localizedName ?? "Unknown",
            title: title,
            frame: frame
        )
    }

    func performLayout() {
        guard let screen = NSScreen.main else {
            print("✗ No main screen found")
            return
        }

        // Get screen frame (excluding menu bar)
        let screenFrame = screen.visibleFrame
        print("\n=== Layout Calculation ===")
        print("Screen frame: \(screenFrame)")
        print("  Origin: (\(screenFrame.origin.x), \(screenFrame.origin.y))")
        print("  Size: \(screenFrame.size.width) x \(screenFrame.size.height)")

        // Calculate layout from Zig
        let layoutCommands = bridge.calculateLayout(screenFrame: screenFrame)

        print("Calculated layout for \(layoutCommands.count) windows")

        // Apply layout commands to actual windows
        for (windowId, frame) in layoutCommands {
            if let windowElement = windowElements[windowId] {
                // Get current position first
                let currentFrame = WindowController.getFrame(window: windowElement)
                print("  Window \(windowId):")
                print("    Current: \(currentFrame?.debugDescription ?? "unknown")")
                print("    Target:  \(frame)")

                if WindowController.setFrame(window: windowElement, frame: frame) {
                    // Verify the position was actually set
                    if let newFrame = WindowController.getFrame(window: windowElement) {
                        let deltaX = abs(newFrame.origin.x - frame.origin.x)
                        let deltaY = abs(newFrame.origin.y - frame.origin.y)
                        if deltaX < 5 && deltaY < 5 {
                            print("    ✓ Positioned successfully")
                        } else {
                            print("    ⚠ Position set but window moved to: \(newFrame)")
                        }
                    } else {
                        print("    ✓ Position command succeeded")
                    }
                } else {
                    print("    ✗ Failed to position window")
                }
            } else {
                print("  ✗ Window \(windowId) not found in element map")
            }
        }
        print("=== Layout Complete ===\n")
    }

    // Get window element by ID
    func getWindowElement(_ windowId: UInt64) -> AXUIElement? {
        return windowElements[windowId]
    }

    // Focus a specific window by ID
    func focusWindow(_ windowId: UInt64) -> Bool {
        guard let windowElement = windowElements[windowId] else {
            print("Cannot focus window \(windowId): not found")
            return false
        }

        let success = WindowController.focus(window: windowElement)
        if success {
            focusedWindowId = windowId
            print("✓ Focused window \(windowId)")

            // Show focus indicator border - deferred using RunLoop to avoid crashes in event tap
            if let frame = WindowController.getFrame(window: windowElement) {
                RunLoop.main.perform(inModes: [.common]) { [weak self] in
                    self?.focusIndicator.showBorder(around: frame)
                }
            }
        } else {
            print("✗ Failed to focus window \(windowId)")
        }
        return success
    }

    // Get list of all window IDs (in insertion order)
    func getAllWindowIds() -> [UInt64] {
        return windowOrder
    }
}
