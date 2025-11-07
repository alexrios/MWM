import Cocoa

// Check for command-line arguments
let arguments = CommandLine.arguments

if arguments.contains("--test") {
    // Test mode: run automated tests and exit
    print("🧪 Running in test mode...\n")

    // Initialize NSApplication for run loop support (but don't show GUI)
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)

    // Initialize components
    let windowManager = WindowManagerBridge()
    let windowObserver = WindowObserver(bridge: windowManager)
    windowObserver.start()

    let hotkeyManager = HotkeyManager(windowManager: windowManager, windowObserver: windowObserver)
    guard hotkeyManager.start() else {
        print("✗ Failed to start hotkey manager (accessibility permissions required)")
        exit(1)
    }

    let testHarness = HotkeyTestHarness(
        hotkeyManager: hotkeyManager,
        windowObserver: windowObserver,
        windowManager: windowManager
    )
    hotkeyManager.testHarness = testHarness

    // Schedule test execution after a short delay to ensure everything is initialized
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        let testSuccess = testHarness.runAllTests()

        // Cleanup
        hotkeyManager.stop()
        windowObserver.stop()
        windowManager.shutdown()

        // Exit with appropriate code
        exit(testSuccess ? 0 : 1)
    }

    // Run the app briefly to process events
    // Tests will exit the app when complete
    app.run()
} else {
    // Normal mode: run GUI app
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
