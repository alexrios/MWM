import Cocoa
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var windowManager: WindowManagerBridge!
    var accessibilityManager: AccessibilityManager!
    var windowObserver: WindowObserver!
    var hotkeyManager: HotkeyManager!
    var spaceManager: SpaceManager!
    var testHarness: HotkeyTestHarness?
    var spaceManagerTest: SpaceManagerTest?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon - menu bar app only
        NSApp.setActivationPolicy(.accessory)

        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "MWM"
        }

        // Create menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "About MWM", action: #selector(about), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Request Accessibility Permission", action: #selector(requestAccessibility), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Show Hotkeys", action: #selector(showHotkeys), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Test: Run All Hotkey Tests", action: #selector(runAllHotkeyTests), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Test: Workspace Workflow", action: #selector(runWorkspaceWorkflow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Test: SpaceManager Diagnostic", action: #selector(runSpaceManagerDiagnostic), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Debug: Print Windows", action: #selector(debugPrintWindows), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Debug: Print Space Info", action: #selector(debugPrintSpaceInfo), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu

        // Initialize accessibility manager
        accessibilityManager = AccessibilityManager()

        // Check accessibility permissions
        if accessibilityManager.hasPermission {
            print("✓ Accessibility permissions granted")
            startWindowManagement()
        } else {
            print("✗ Accessibility permissions required")
            showPermissionAlert()
        }
    }

    func startWindowManagement() {
        print("Starting window management...")

        // Initialize Zig core
        windowManager = WindowManagerBridge()
        print("Zig core initialized")

        // Set up window observer
        windowObserver = WindowObserver(bridge: windowManager)
        windowObserver.start()

        // Initialize space manager
        spaceManager = SpaceManager()
        spaceManager.printSpaceInfo()

        // Set up hotkey manager with space manager
        hotkeyManager = HotkeyManager(windowManager: windowManager, windowObserver: windowObserver, spaceManager: spaceManager)
        if hotkeyManager.start() {
            print("✓ Hotkeys enabled")
            hotkeyManager.printRegisteredHotkeys()
        } else {
            print("✗ Failed to enable hotkeys (accessibility permissions required)")
        }

        // Initialize test harness with window state validation
        testHarness = HotkeyTestHarness(
            hotkeyManager: hotkeyManager,
            windowObserver: windowObserver,
            windowManager: windowManager
        )
        hotkeyManager.testHarness = testHarness

        // Initialize space manager test
        spaceManagerTest = SpaceManagerTest(spaceManager: spaceManager)

        print("Window management started")
        print("Window count after startup: \(windowManager.getWindowCount())")
    }

    func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "MWM needs accessibility permissions to manage windows. Please grant permission in System Preferences."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Quit")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            accessibilityManager.openSystemPreferences()
        } else {
            NSApp.terminate(nil)
        }
    }

    @objc func about() {
        let alert = NSAlert()
        alert.messageText = "MWM - macOS Window Manager"
        alert.informativeText = """
        A tiling window manager for macOS

        Core: Zig
        UI: Swift

        Click "Show Hotkeys" to see keyboard shortcuts.
        """
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc func showHotkeys() {
        guard let hkManager = hotkeyManager else {
            let alert = NSAlert()
            alert.messageText = "Hotkeys Not Available"
            alert.informativeText = "Hotkey manager is not initialized. Make sure accessibility permissions are granted."
            alert.alertStyle = .warning
            alert.runModal()
            return
        }

        let alert = NSAlert()
        alert.messageText = "MWM - i3wm-style Shortcuts"
        alert.informativeText = """
        Focus Windows (Cmd = Mod key):
        • Cmd+h/j/k/l - Focus left/down/up/right (vim)
        • Cmd+←/↓/↑/→ - Focus left/down/up/right (arrows)

        Move Windows:
        • Cmd+Shift+h/j/k/l - Move left/down/up/right (vim)
        • Cmd+Shift+←/↓/↑/→ - Move left/down/up/right (arrows)

        Layout:
        • Cmd+r - Retile/refresh layout
        • Cmd+- - Decrease master area
        • Cmd+= - Increase master area

        Window Control:
        • Cmd+Shift+Space - Toggle floating (TODO)
        • Cmd+Shift+f - Close window/Quit

        Inspired by i3wm tiling window manager
        Note: Accessibility permissions required
        """
        alert.alertStyle = .informational
        alert.runModal()

        // Also print to console
        hkManager.printRegisteredHotkeys()
    }

    @objc func requestAccessibility() {
        if accessibilityManager.hasPermission {
            let alert = NSAlert()
            alert.messageText = "Permission Already Granted"
            alert.informativeText = "Accessibility permissions are already enabled."
            alert.runModal()
        } else {
            accessibilityManager.requestPermission()
        }
    }

    @objc func debugPrintWindows() {
        guard let wm = windowManager else {
            let alert = NSAlert()
            alert.messageText = "Window Manager Not Initialized"
            alert.informativeText = "Window manager is not running. Make sure accessibility permissions are granted."
            alert.alertStyle = .warning
            alert.runModal()
            return
        }

        let count = wm.getWindowCount()
        let alert = NSAlert()
        alert.messageText = "Window Manager Debug Info"
        alert.informativeText = """
        Total windows: \(count)

        Check Console.app or run from terminal to see detailed output:
        mise run run
        """
        alert.alertStyle = .informational
        alert.runModal()

        // Also print to stderr (visible in Console.app or terminal)
        print("=== Debug: Print Windows ===")
        print("Total windows tracked: \(count)")
        wm.debugPrintWindows()
    }

    @objc func runAllHotkeyTests() {
        guard let harness = testHarness else {
            showTestHarnessNotAvailable()
            return
        }

        let alert = NSAlert()
        alert.messageText = "Run Automated Hotkey Tests?"
        alert.informativeText = """
        This will simulate all i3wm-style hotkeys and log the results.

        Watch the terminal output to see which hotkeys are detected.
        The test takes about 5 seconds to complete.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Run Tests")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Run tests in background to avoid blocking UI
            DispatchQueue.global(qos: .userInitiated).async {
                let success = harness.runAllTests()
                print("\n" + (success ? "✅ All tests completed" : "❌ Some tests failed"))
            }
        }
    }

    private func showTestHarnessNotAvailable() {
        let alert = NSAlert()
        alert.messageText = "Test Harness Not Available"
        alert.informativeText = "Test harness is not initialized. Make sure accessibility permissions are granted and window management is running."
        alert.alertStyle = .warning
        alert.runModal()
    }

    @objc func runWorkspaceWorkflow() {
        guard let harness = testHarness else {
            showTestHarnessNotAvailable()
            return
        }

        let alert = NSAlert()
        alert.messageText = "Run Workspace Workflow Test?"
        alert.informativeText = """
        This will test workspace switching and window movement:
        • Switch between Spaces 1, 2, 3
        • Move window to different Space
        • Follow window to new Space

        Make sure you have at least 3 Spaces created in Mission Control.
        Watch terminal output for details.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Run Test")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            DispatchQueue.global(qos: .userInitiated).async {
                harness.testWorkspaceWorkflow()
            }
        }
    }

    @objc func runSpaceManagerDiagnostic() {
        guard let test = spaceManagerTest else {
            let alert = NSAlert()
            alert.messageText = "SpaceManager Test Not Available"
            alert.informativeText = "SpaceManager test is not initialized."
            alert.alertStyle = .warning
            alert.runModal()
            return
        }

        let alert = NSAlert()
        alert.messageText = "Run SpaceManager Diagnostic?"
        alert.informativeText = """
        This will test the CGS private API integration:
        • Check if SkyLight framework loaded
        • Verify space detection
        • Test space switching capabilities

        This helps diagnose if workspace features are working.
        Watch terminal output for detailed results.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Run Diagnostic")
        alert.addButton(withTitle: "Run Full Tests")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Quick diagnostic
            DispatchQueue.global(qos: .userInitiated).async {
                test.runQuickDiagnostic()
            }
        } else if response == .alertSecondButtonReturn {
            // Full test suite
            DispatchQueue.global(qos: .userInitiated).async {
                let _ = test.runAllTests()
            }
        }
    }

    @objc func debugPrintSpaceInfo() {
        guard let sm = spaceManager else {
            let alert = NSAlert()
            alert.messageText = "SpaceManager Not Initialized"
            alert.informativeText = "SpaceManager is not running."
            alert.alertStyle = .warning
            alert.runModal()
            return
        }

        print("\n=== Manual Debug Request ===")
        sm.printSpaceInfo()
        sm.forceRefreshSpaces()

        let alert = NSAlert()
        alert.messageText = "Space Information"
        alert.informativeText = """
        Space information printed to console.

        Check Console.app or terminal output.
        """
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager?.stop()
        windowObserver?.stop()
        windowManager?.shutdown()
    }
}
