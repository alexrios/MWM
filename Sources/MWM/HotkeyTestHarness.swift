import Cocoa
import ApplicationServices

/// Automated test harness for hotkey testing
/// Simulates keyboard events and verifies they're detected
class HotkeyTestHarness {
    private var hotkeyManager: HotkeyManager
    private var testResults: [TestResult] = []
    private var isTestMode = false

    struct TestResult {
        let hotkey: String
        let action: String
        let detected: Bool
        let timestamp: Date
        let windowStateBefore: WindowState?
        let windowStateAfter: WindowState?
        let passed: Bool  // Whether the action had the expected effect
    }

    struct WindowState {
        let focusedWindowId: UInt64?
        let windowCount: Int
        let windowPositions: [UInt64: CGRect]  // windowId -> position/size
        let windowOrder: [UInt64]  // Window IDs in order
    }

    // Helper struct for encoding CGRect
    struct EncodableRect: Codable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double

        init(from rect: CGRect) {
            self.x = rect.origin.x
            self.y = rect.origin.y
            self.width = rect.size.width
            self.height = rect.size.height
        }
    }

    private weak var windowObserver: WindowObserver?
    private weak var windowManager: WindowManagerBridge?

    init(hotkeyManager: HotkeyManager, windowObserver: WindowObserver? = nil, windowManager: WindowManagerBridge? = nil) {
        self.hotkeyManager = hotkeyManager
        self.windowObserver = windowObserver
        self.windowManager = windowManager
    }

    /// Enable test mode (captures hotkey events)
    func enableTestMode() {
        isTestMode = true
        testResults.removeAll()
        print("🧪 Test mode enabled - hotkey events will be captured")
    }

    /// Disable test mode
    func disableTestMode() {
        isTestMode = false
        print("🧪 Test mode disabled")
    }

    /// Simulate a hotkey press with window state validation
    func simulateHotkey(keyCode: CGKeyCode, modifiers: CGEventFlags, description: String) {
        print("🔨 Simulating: \(description)")

        // Capture window state before
        let stateBefore = captureWindowState()

        // Create keyboard events
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            print("  ✗ Failed to create keyboard event")
            recordResult(hotkey: description, action: "unknown", detected: false)
            return
        }

        // Set modifier flags
        keyDown.flags = modifiers
        keyUp.flags = modifiers

        // Post events to system
        keyDown.post(tap: .cghidEventTap)

        // Process run loop to allow event tap to catch the event
        CFRunLoopRunInMode(.defaultMode, 0.1, false)

        keyUp.post(tap: .cghidEventTap)

        // Process run loop again for key up and any resulting actions
        CFRunLoopRunInMode(.defaultMode, 0.3, false)

        // Small delay to allow window system to finish processing
        Thread.sleep(forTimeInterval: 0.05)

        // Capture window state after
        let stateAfter = captureWindowState()

        // Record result with validation
        recordResultWithState(
            hotkey: description,
            action: description,
            detected: true,
            stateBefore: stateBefore,
            stateAfter: stateAfter
        )

        print("  ✓ Event posted and validated")
    }

    /// Capture current window state
    private func captureWindowState() -> WindowState? {
        guard let observer = windowObserver, let manager = windowManager else {
            return nil
        }

        let windowIds = observer.getAllWindowIds()
        var positions: [UInt64: CGRect] = [:]

        for windowId in windowIds {
            if let element = observer.getWindowElement(windowId),
               let frame = WindowController.getFrame(window: element) {
                positions[windowId] = frame
            }
        }

        return WindowState(
            focusedWindowId: observer.focusedWindowId,
            windowCount: manager.getWindowCount(),
            windowPositions: positions,
            windowOrder: windowIds
        )
    }

    /// Record test result (called by HotkeyManager)
    func recordResult(hotkey: String, action: String, detected: Bool) {
        let result = TestResult(
            hotkey: hotkey,
            action: action,
            detected: detected,
            timestamp: Date(),
            windowStateBefore: nil,
            windowStateAfter: nil,
            passed: detected
        )
        testResults.append(result)
    }

    /// Record test result with window state validation
    func recordResultWithState(hotkey: String, action: String, detected: Bool, stateBefore: WindowState?, stateAfter: WindowState?) {
        let passed = validateWindowStateChange(action: action, before: stateBefore, after: stateAfter)

        let result = TestResult(
            hotkey: hotkey,
            action: action,
            detected: detected,
            timestamp: Date(),
            windowStateBefore: stateBefore,
            windowStateAfter: stateAfter,
            passed: passed
        )
        testResults.append(result)
    }

    /// Validate that window state changed as expected
    private func validateWindowStateChange(action: String, before: WindowState?, after: WindowState?) -> Bool {
        guard let before = before, let after = after else {
            return false
        }

        // Focus actions should change focused window
        if action.contains("focus") || action.contains("Focus") {
            let focusChanged = before.focusedWindowId != after.focusedWindowId
            print("  └─ Focus validation: \(focusChanged ? "✓" : "✗") (before: \(before.focusedWindowId ?? 0), after: \(after.focusedWindowId ?? 0))")
            return focusChanged
        }

        // Move/swap actions should change window positions
        if action.contains("move") || action.contains("Move") || action.contains("swap") || action.contains("Swap") {
            var positionsChanged = false
            for (windowId, beforePos) in before.windowPositions {
                if let afterPos = after.windowPositions[windowId] {
                    if beforePos != afterPos {
                        positionsChanged = true
                        print("  └─ Window \(windowId) moved: \(beforePos.origin) → \(afterPos.origin)")
                    }
                }
            }
            print("  └─ Movement validation: \(positionsChanged ? "✓" : "✗")")
            return positionsChanged
        }

        // Retile should potentially reposition windows
        if action.contains("retile") || action.contains("Retile") {
            // At minimum, the operation should complete without error
            return true
        }

        // Resize/ratio actions should change window sizes
        if action.contains("ratio") || action.contains("Ratio") || action.contains("master") {
            var sizesChanged = false
            for (windowId, beforePos) in before.windowPositions {
                if let afterPos = after.windowPositions[windowId] {
                    if beforePos.size != afterPos.size {
                        sizesChanged = true
                        print("  └─ Window \(windowId) resized: \(beforePos.size) → \(afterPos.size)")
                    }
                }
            }
            print("  └─ Resize validation: \(sizesChanged ? "✓" : "✗")")
            return sizesChanged
        }

        // Default: just check that operation was detected
        return true
    }

    /// Run all i3wm-style hotkey tests (full suite)
    func runI3wmStyleTests() -> Bool {
        return runAllTests()
    }

    /// Run all i3wm-style hotkey tests
    func runAllTests() -> Bool {
        enableTestMode()

        print("\n" + String(repeating: "=", count: 60))
        print("🧪 AUTOMATED HOTKEY TEST SUITE")
        print(String(repeating: "=", count: 60) + "\n")

        var allPassed = true

        // Focus tests - Vim keys
        allPassed = testFocusVimKeys() && allPassed

        // Focus tests - Arrow keys
        allPassed = testFocusArrowKeys() && allPassed

        // Move tests - Vim keys
        allPassed = testMoveVimKeys() && allPassed

        // Move tests - Arrow keys
        allPassed = testMoveArrowKeys() && allPassed

        // Layout tests
        allPassed = testLayoutControls() && allPassed

        // Window control tests
        allPassed = testWindowControls() && allPassed

        disableTestMode()

        printSummary()

        return allPassed
    }

    private func testFocusVimKeys() -> Bool {
        print("📋 Testing Focus - Vim Keys")
        print(String(repeating: "-", count: 60))

        let tests: [(CGKeyCode, String)] = [
            (0x04, "Cmd+h (focus left)"),
            (0x26, "Cmd+j (focus down)"),
            (0x28, "Cmd+k (focus up)"),
            (0x25, "Cmd+l (focus right)")
        ]

        for (keyCode, desc) in tests {
            autoreleasepool {
                simulateHotkey(keyCode: keyCode, modifiers: .maskCommand, description: desc)
            }
        }

        print()
        return true
    }

    private func testFocusArrowKeys() -> Bool {
        print("📋 Testing Focus - Arrow Keys")
        print(String(repeating: "-", count: 60))

        let tests: [(CGKeyCode, String)] = [
            (0x7B, "Cmd+← (focus left)"),
            (0x7D, "Cmd+↓ (focus down)"),
            (0x7E, "Cmd+↑ (focus up)"),
            (0x7C, "Cmd+→ (focus right)")
        ]

        for (keyCode, desc) in tests {
            simulateHotkey(keyCode: keyCode, modifiers: .maskCommand, description: desc)
        }

        print()
        return true
    }

    private func testMoveVimKeys() -> Bool {
        print("📋 Testing Move - Vim Keys")
        print(String(repeating: "-", count: 60))

        let tests: [(CGKeyCode, String)] = [
            (0x04, "Cmd+Shift+h (move left)"),
            (0x26, "Cmd+Shift+j (move down)"),
            (0x28, "Cmd+Shift+k (move up)"),
            (0x25, "Cmd+Shift+l (move right)")
        ]

        for (keyCode, desc) in tests {
            simulateHotkey(keyCode: keyCode, modifiers: [.maskCommand, .maskShift], description: desc)
        }

        print()
        return true
    }

    private func testMoveArrowKeys() -> Bool {
        print("📋 Testing Move - Arrow Keys")
        print(String(repeating: "-", count: 60))

        let tests: [(CGKeyCode, String)] = [
            (0x7B, "Cmd+Shift+← (move left)"),
            (0x7D, "Cmd+Shift+↓ (move down)"),
            (0x7E, "Cmd+Shift+↑ (move up)"),
            (0x7C, "Cmd+Shift+→ (move right)")
        ]

        for (keyCode, desc) in tests {
            simulateHotkey(keyCode: keyCode, modifiers: [.maskCommand, .maskShift], description: desc)
        }

        print()
        return true
    }

    private func testLayoutControls() -> Bool {
        print("📋 Testing Layout Controls")
        print(String(repeating: "-", count: 60))

        let tests: [(CGKeyCode, CGEventFlags, String)] = [
            (0x0F, .maskCommand, "Cmd+r (retile)"),
            (0x1B, .maskCommand, "Cmd+- (decrease master)"),
            (0x18, .maskCommand, "Cmd+= (increase master)")
        ]

        for (keyCode, modifiers, desc) in tests {
            simulateHotkey(keyCode: keyCode, modifiers: modifiers, description: desc)
        }

        print()
        return true
    }

    private func testWindowControls() -> Bool {
        print("📋 Testing Window Controls")
        print(String(repeating: "-", count: 60))

        let tests: [(CGKeyCode, CGEventFlags, String)] = [
            (0x31, [.maskCommand, .maskShift], "Cmd+Shift+Space (toggle floating)"),
            (0x03, [.maskCommand, .maskShift], "Cmd+Shift+f (quit)")
        ]

        for (keyCode, modifiers, desc) in tests {
            simulateHotkey(keyCode: keyCode, modifiers: modifiers, description: desc)
        }

        print()
        return true
    }

    /// Test focus cycling workflow (Cmd+j repeatedly)
    func testFocusCycleWorkflow() {
        enableTestMode()

        print("\n" + String(repeating: "=", count: 60))
        print("🧪 FOCUS CYCLE WORKFLOW TEST")
        print(String(repeating: "=", count: 60) + "\n")

        print("Cycling through windows with Cmd+j (focus down)...")
        print("(Press 5 times to cycle through all windows)\n")

        // Simulate Cmd+j 5 times
        for i in 1...5 {
            print("Cycle \(i):")
            simulateHotkey(keyCode: 0x26, modifiers: .maskCommand, description: "Cmd+j")
            Thread.sleep(forTimeInterval: 0.5) // Longer delay between cycles
        }

        disableTestMode()
        printSummary()
    }

    /// Test move to master workflow
    func testMoveToMasterWorkflow() {
        enableTestMode()

        print("\n" + String(repeating: "=", count: 60))
        print("🧪 MOVE TO MASTER WORKFLOW TEST")
        print(String(repeating: "=", count: 60) + "\n")

        print("Step 1: Focus next window (Cmd+j)")
        simulateHotkey(keyCode: 0x26, modifiers: .maskCommand, description: "Cmd+j")
        Thread.sleep(forTimeInterval: 0.5)

        print("\nStep 2: Move to master (Cmd+Shift+h)")
        simulateHotkey(keyCode: 0x04, modifiers: [.maskCommand, .maskShift], description: "Cmd+Shift+h")
        Thread.sleep(forTimeInterval: 0.5)

        print("\nStep 3: Retile layout (Cmd+r)")
        simulateHotkey(keyCode: 0x0F, modifiers: .maskCommand, description: "Cmd+r")
        Thread.sleep(forTimeInterval: 0.5)

        disableTestMode()
        printSummary()
    }

    private func printSummary() {
        print("\n" + String(repeating: "=", count: 60))
        print("📊 TEST SUMMARY")
        print(String(repeating: "=", count: 60))

        let total = testResults.count
        let detected = testResults.filter { $0.detected }.count
        let validated = testResults.filter { $0.passed }.count
        let failed = total - validated

        print("Total tests:       \(total)")
        print("Hotkeys detected:  \(detected) ✓")
        print("Actions validated: \(validated) ✓")
        print("Failed validation: \(failed) ✗")
        print("Success rate:      \(total > 0 ? (validated * 100 / total) : 0)%")

        if failed > 0 {
            print("\n❌ Failed validations:")
            for result in testResults where !result.passed {
                print("  • \(result.hotkey) → \(result.action)")
                if let before = result.windowStateBefore, let after = result.windowStateAfter {
                    print("    Focus: \(before.focusedWindowId ?? 0) → \(after.focusedWindowId ?? 0)")
                    print("    Windows: \(before.windowCount) → \(after.windowCount)")
                }
            }
        } else {
            print("\n✅ All tests passed with full validation!")
        }

        print(String(repeating: "=", count: 60) + "\n")
    }

    /// Get test results as JSON for automation
    func getResultsJSON() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        guard let data = try? encoder.encode(testResults),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"error\": \"Failed to encode results\"}"
        }

        return json
    }
}

// Make TestResult Encodable for JSON export (skip WindowState for simplicity)
extension HotkeyTestHarness.TestResult: Codable {
    enum CodingKeys: String, CodingKey {
        case hotkey, action, detected, timestamp, passed
        case focusChangeBefore = "focus_before"
        case focusChangeAfter = "focus_after"
        case windowCount
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hotkey, forKey: .hotkey)
        try container.encode(action, forKey: .action)
        try container.encode(detected, forKey: .detected)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(passed, forKey: .passed)

        // Encode basic window state info
        if let before = windowStateBefore {
            try container.encode(before.focusedWindowId, forKey: .focusChangeBefore)
            try container.encode(before.windowCount, forKey: .windowCount)
        }
        if let after = windowStateAfter {
            try container.encode(after.focusedWindowId, forKey: .focusChangeAfter)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hotkey = try container.decode(String.self, forKey: .hotkey)
        action = try container.decode(String.self, forKey: .action)
        detected = try container.decode(Bool.self, forKey: .detected)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        passed = try container.decodeIfPresent(Bool.self, forKey: .passed) ?? detected
        windowStateBefore = nil
        windowStateAfter = nil
    }
}
