import Cocoa
import Foundation

// MARK: - CGS Private API Declarations

// Dynamic function loading
private let CGSHandle: UnsafeMutableRawPointer? = {
    // Try multiple possible paths
    let paths = [
        "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight",
        "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"
    ]

    for path in paths {
        if let handle = dlopen(path, RTLD_LAZY) {
            print("✓ SkyLight framework loaded from: \(path)")
            return handle
        }
    }

    print("⚠️  Failed to load SkyLight framework")
    if let error = dlerror() {
        print("  Error: \(String(cString: error))")
    }
    return nil
}()

// Function typedefs for working CGS APIs
private typealias CGSDefaultConnectionFunc = @convention(c) () -> Int32
private typealias CGSCopySpacesFunc = @convention(c) (Int32, Int) -> CFArray?
private typealias CGSGetActiveSpaceFunc = @convention(c) (Int32) -> Int

// Symbolic HotKey API types
private typealias CGSSymbolicHotKey = UInt32
private typealias CGSModifierFlags = UInt64

// Symbolic HotKey API declarations
@_silgen_name("CGSGetSymbolicHotKeyValue")
private func CGSGetSymbolicHotKeyValue(
    _ hotKey: CGSSymbolicHotKey,
    _ enabled: UnsafeMutablePointer<Bool>?,
    _ keyCode: UnsafeMutablePointer<CGKeyCode>?,
    _ modifiers: UnsafeMutablePointer<CGSModifierFlags>?
) -> CGError

@_silgen_name("CGSIsSymbolicHotKeyEnabled")
private func CGSIsSymbolicHotKeyEnabled(_ hotKey: CGSSymbolicHotKey) -> Bool

@_silgen_name("CGSSetSymbolicHotKeyEnabled")
private func CGSSetSymbolicHotKeyEnabled(_ hotKey: CGSSymbolicHotKey, _ enabled: Bool) -> CGError

// Load functions dynamically
private let _CGSDefaultConnection: CGSDefaultConnectionFunc? = {
    guard let handle = CGSHandle else {
        print("  ✗ CGS Connection: No handle")
        return nil
    }

    // Try multiple connection API names
    let names = ["CGSMainConnectionID", "_CGSDefaultConnection", "CGSDefaultConnectionForThread"]
    for name in names {
        if let symbol = dlsym(handle, name) {
            print("  ✓ Connection API loaded: \(name)")
            return unsafeBitCast(symbol, to: CGSDefaultConnectionFunc.self)
        }
    }

    print("  ✗ No CGS Connection API found")
    return nil
}()

private let _CGSCopySpaces: CGSCopySpacesFunc? = {
    guard let handle = CGSHandle else {
        print("  ✗ CGSCopySpaces: No handle")
        return nil
    }
    guard let symbol = dlsym(handle, "CGSCopySpaces") else {
        print("  ✗ CGSCopySpaces: Symbol not found")
        return nil
    }
    print("  ✓ CGSCopySpaces loaded")
    return unsafeBitCast(symbol, to: CGSCopySpacesFunc.self)
}()

private let _CGSGetActiveSpace: CGSGetActiveSpaceFunc? = {
    guard let handle = CGSHandle else {
        print("  ✗ CGSGetActiveSpace: No handle")
        return nil
    }
    guard let symbol = dlsym(handle, "CGSGetActiveSpace") else {
        print("  ✗ CGSGetActiveSpace: Symbol not found")
        return nil
    }
    print("  ✓ CGSGetActiveSpace loaded")
    return unsafeBitCast(symbol, to: CGSGetActiveSpaceFunc.self)
}()

// Note: CGSAddWindowsToSpaces, CGSRemoveWindowsFromSpaces, CGSShowSpaces, and
// CGSCopySpacesForWindows are broken on modern macOS and have been removed.
// See CGS_APIS_BROKEN.md for details.

// Constants
private let kCGSAllSpacesMask = 0x7  // All spaces on all displays

// MARK: - SpaceManager

class SpaceManager {
    private let connection: Int32
    private var spaceCache: [Int] = []
    private var lastCacheUpdate: Date = .distantPast
    private let cacheRefreshInterval: TimeInterval = 5.0  // Refresh every 5 seconds

    init() {
        guard let connFunc = _CGSDefaultConnection else {
            print("Warning: CGSDefaultConnection not available")
            self.connection = 0
            return
        }
        self.connection = connFunc()
        refreshSpaceCache()
        print("SpaceManager initialized (connection: \(connection))")
    }

    // MARK: - Space Query

    /// Get all space IDs from the system
    func getAllSpaces() -> [Int] {
        // Use cached spaces if recent
        if Date().timeIntervalSince(lastCacheUpdate) < cacheRefreshInterval {
            return spaceCache
        }

        refreshSpaceCache()
        return spaceCache
    }

    /// Get the currently active space ID
    func getCurrentSpace() -> Int {
        guard let func_get = _CGSGetActiveSpace else {
            print("Warning: CGSGetActiveSpace not available")
            return 0
        }
        return func_get(connection)
    }

    /// Get the space number (1-based index) for a space ID
    func getSpaceNumber(for spaceID: Int) -> Int? {
        let spaces = getAllSpaces()
        guard let index = spaces.firstIndex(of: spaceID) else {
            return nil
        }
        return index + 1  // 1-based
    }

    /// Get the current space number (1-9)
    func getCurrentSpaceNumber() -> Int? {
        let currentSpaceID = getCurrentSpace()
        return getSpaceNumber(for: currentSpaceID)
    }

    // MARK: - Space Switching

    /// Switch to a space by its ID
    func switchToSpace(_ spaceID: Int) {
        // CGSShowSpaces doesn't work reliably, so use keyboard shortcut simulation instead
        print("⚠️  Note: Using keyboard shortcut simulation for space switching")
        print("   (CGSShowSpaces API doesn't work on this macOS version)")

        // Get space number
        if let spaceNum = getSpaceNumber(for: spaceID) {
            simulateSpaceSwitch(toSpace: spaceNum)
        } else {
            print("Warning: Could not find space number for ID \(spaceID)")
        }
    }

    /// Simulate keyboard shortcut to switch spaces (Ctrl+Number)
    private func simulateSpaceSwitch(toSpace number: Int) {
        guard number >= 1 && number <= 9 else { return }

        // Map number to key code (1-9)
        let keyCodes: [CGKeyCode] = [
            0x12,  // 1
            0x13,  // 2
            0x14,  // 3
            0x15,  // 4
            0x17,  // 5
            0x16,  // 6
            0x1A,  // 7
            0x1C,  // 8
            0x19   // 9
        ]

        guard number - 1 < keyCodes.count else { return }
        let keyCode = keyCodes[number - 1]

        // Create keyboard events with Ctrl modifier
        if let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
           let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) {

            // Set Control modifier (macOS default for space switching)
            keyDown.flags = .maskControl
            keyUp.flags = .maskControl

            // Post events
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)

            print("Switched to space \(number) via Ctrl+\(number) shortcut")
        }
    }

    /// Switch to a space by number (1-9)
    func switchToSpaceNumber(_ number: Int) {
        guard number >= 1 && number <= 9 else {
            print("Invalid space number: \(number). Must be 1-9")
            return
        }

        let spaces = getAllSpaces()
        guard number <= spaces.count else {
            print("Space \(number) does not exist. Only \(spaces.count) spaces available.")
            return
        }

        let spaceID = spaces[number - 1]  // Convert to 0-based index
        print("Switching to space \(number) (ID: \(spaceID))")
        switchToSpace(spaceID)
    }

    // MARK: - Window Movement (Amethyst Approach)

    /// Move a window to a different space using drag-and-switch simulation
    func moveWindow(_ windowID: UInt32, toSpace spaceID: Int, windowFrame: CGRect) {
        print("\n🔧 Moving window using drag-and-switch simulation")
        print("  Window ID: \(windowID)")
        print("  Target Space ID: \(spaceID)")

        // Find space number from space ID
        guard let spaceNumber = getSpaceNumber(for: spaceID) else {
            print("  ❌ Could not find space number for ID \(spaceID)")
            return
        }

        print("  Target Space Number: \(spaceNumber)")

        // Get space switch event
        guard let spaceEvent = createSpaceSwitchEvent(for: spaceNumber) else {
            print("  ❌ Could not create space switch event")
            print("  💡 Make sure 'Switch to Desktop \(spaceNumber)' is configured in System Preferences")
            return
        }

        // Simulate window drag + space switch
        simulateWindowDragToSpace(at: windowFrame, spaceEvent: spaceEvent, spaceNumber: spaceNumber)
    }

    /// Create keyboard event for switching to a specific space
    private func createSpaceSwitchEvent(for spaceNumber: Int) -> (keyCode: CGKeyCode, flags: CGEventFlags)? {
        guard spaceNumber >= 1 && spaceNumber <= 16 else {
            return nil
        }

        // Symbolic hotkey IDs: 118 = Desktop 1, 119 = Desktop 2, etc.
        let hotKey: CGSSymbolicHotKey = UInt32(118 + spaceNumber - 1)

        var keyCode: CGKeyCode = 0
        var flags: CGSModifierFlags = 0

        // Get the user's configured hotkey for this space
        let error = CGSGetSymbolicHotKeyValue(hotKey, nil, &keyCode, &flags)
        guard error == .success else {
            print("  ⚠️  Failed to get symbolic hotkey for space \(spaceNumber)")
            return nil
        }

        print("  ✅ Got space switch hotkey: keyCode=\(keyCode), flags=\(flags)")

        // Check if hotkey is enabled, temporarily enable if not
        if !CGSIsSymbolicHotKeyEnabled(hotKey) {
            print("  ⚙️  Temporarily enabling space \(spaceNumber) hotkey")
            let enableError = CGSSetSymbolicHotKeyEnabled(hotKey, true)
            if enableError != .success {
                print("  ⚠️  Failed to enable hotkey")
            }
        }

        return (keyCode, CGEventFlags(rawValue: UInt64(flags)))
    }

    /// Simulate dragging a window while switching spaces (Amethyst's approach)
    private func simulateWindowDragToSpace(at frame: CGRect, spaceEvent: (keyCode: CGKeyCode, flags: CGEventFlags), spaceNumber: Int) {
        // Position in window title bar (offset from top-left)
        let grabPoint = CGPoint(x: frame.origin.x + 50, y: frame.origin.y + 10)

        print("  🖱️  Simulating window grab at: \(grabPoint)")

        // Create mouse events
        guard let mouseMove = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: grabPoint, mouseButton: .left),
              let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: grabPoint, mouseButton: .left),
              let mouseDrag = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: grabPoint, mouseButton: .left),
              let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: grabPoint, mouseButton: .left) else {
            print("  ❌ Failed to create mouse events")
            return
        }

        // Step 1: Move mouse to title bar
        mouseMove.post(tap: .cghidEventTap)

        // Step 2: Grab window (mouse down + drag)
        mouseDown.post(tap: .cghidEventTap)
        mouseDrag.post(tap: .cghidEventTap)

        print("  ⏳ Window grabbed, waiting 50ms...")

        // Step 3: Wait for grab to register (50ms)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            print("  ⌨️  Triggering space switch to \(spaceNumber)...")

            // Trigger space switch while holding window
            if let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: spaceEvent.keyCode, keyDown: true),
               let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: spaceEvent.keyCode, keyDown: false) {
                keyDown.flags = spaceEvent.flags
                keyDown.post(tap: .cghidEventTap)
                keyUp.post(tap: .cghidEventTap)
            }

            print("  ⏳ Waiting for space transition animation (400ms)...")

            // Step 4: Wait for space transition animation (400ms)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                // Release window
                mouseUp.post(tap: .cghidEventTap)
                print("  ✅ Window released on space \(spaceNumber)")
            }
        }
    }

    /// Move a window to a space by number (1-9)
    func moveWindowToSpaceNumber(_ windowID: UInt64, spaceNumber: Int, windowFrame: CGRect) {
        print("\n🎯 Moving window to space \(spaceNumber)")
        print("  Window ID: \(windowID)")

        guard spaceNumber >= 1 && spaceNumber <= 9 else {
            print("  ❌ Invalid space number: \(spaceNumber). Must be 1-9")
            return
        }

        let spaces = getAllSpaces()
        guard spaceNumber <= spaces.count else {
            print("  ❌ Space \(spaceNumber) does not exist. Only \(spaces.count) spaces available.")
            return
        }

        let spaceID = spaces[spaceNumber - 1]
        let windowID32 = UInt32(windowID & 0xFFFFFFFF)

        // Use Amethyst's drag-and-switch approach
        moveWindow(windowID32, toSpace: spaceID, windowFrame: windowFrame)
    }

    // MARK: - Cache Management

    /// Refresh the cached list of spaces
    private func refreshSpaceCache() {
        guard let func_copy = _CGSCopySpaces else {
            print("Warning: CGSCopySpaces not available")
            spaceCache = []
            return
        }

        // Call CGSCopySpaces
        let rawResult = func_copy(connection, kCGSAllSpacesMask)

        // Debug: Check what we got
        if rawResult == nil {
            print("⚠️  CGSCopySpaces returned nil (connection: \(connection), mask: \(kCGSAllSpacesMask))")
            spaceCache = []
            return
        }

        // Try to cast to array
        guard let spacesArray = rawResult as? [Any] else {
            print("⚠️  Could not cast CGS result to array")
            print("  Result type: \(type(of: rawResult))")

            // Try casting to CFArray directly
            if let cfArray = rawResult as CFArray? {
                let count = CFArrayGetCount(cfArray)
                print("  CFArray count: \(count)")

                var spaces: [Int] = []
                for i in 0..<count {
                    if let value = CFArrayGetValueAtIndex(cfArray, i) {
                        let nsValue = Unmanaged<CFTypeRef>.fromOpaque(value).takeUnretainedValue()
                        if let dict = nsValue as? NSDictionary {
                            // Space info is in a dictionary
                            if let spaceID = dict["ManagedSpaceID"] as? Int {
                                spaces.append(spaceID)
                            } else if let spaceID = dict["id64"] as? Int {
                                spaces.append(spaceID)
                            }
                            print("  Space dict keys: \(dict.allKeys)")
                        } else if let num = nsValue as? NSNumber {
                            spaces.append(num.intValue)
                        }
                    }
                }
                spaceCache = spaces
                lastCacheUpdate = Date()
                print("Spaces extracted: \(spaceCache.count) total")
                return
            }

            spaceCache = []
            return
        }

        // Extract space IDs as integers
        spaceCache = spacesArray.compactMap { $0 as? Int }
        lastCacheUpdate = Date()

        if let currentNum = getCurrentSpaceNumber() {
            print("Spaces refreshed: \(spaceCache.count) total, currently on space \(currentNum)")
        } else {
            print("Spaces refreshed: \(spaceCache.count) total")
        }
    }

    /// Force refresh the space cache
    func forceRefreshSpaces() {
        refreshSpaceCache()
    }

    // MARK: - Debugging

    func printSpaceInfo() {
        let spaces = getAllSpaces()
        let currentSpaceID = getCurrentSpace()
        let currentNum = getSpaceNumber(for: currentSpaceID)

        print("\n=== Space Information ===")
        print("Connection ID: \(connection)")
        print("Total spaces: \(spaces.count)")
        print("Current space ID: \(currentSpaceID)")
        if let num = currentNum {
            print("Current space number: \(num)")
        }
        print("Space IDs: \(spaces)")
        print("========================\n")
    }
}
