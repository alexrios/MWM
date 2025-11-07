import Cocoa
import Carbon

// Represents a keyboard shortcut
struct Hotkey: Hashable {
    let keyCode: UInt16
    let modifiers: NSEvent.ModifierFlags

    var carbonModifiers: UInt32 {
        var carbon: UInt32 = 0
        if modifiers.contains(.command) { carbon |= UInt32(cmdKey) }
        if modifiers.contains(.shift) { carbon |= UInt32(shiftKey) }
        if modifiers.contains(.option) { carbon |= UInt32(optionKey) }
        if modifiers.contains(.control) { carbon |= UInt32(controlKey) }
        return carbon
    }

    // Implement Hashable manually since NSEvent.ModifierFlags doesn't conform to Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(keyCode)
        hasher.combine(modifiers.rawValue)
    }

    static func == (lhs: Hotkey, rhs: Hotkey) -> Bool {
        return lhs.keyCode == rhs.keyCode && lhs.modifiers == rhs.modifiers
    }
}

// Hotkey action types
enum HotkeyAction {
    case focusNext
    case focusPrevious
    case swapNext
    case swapPrevious
    case moveToMaster
    case cycleMaster
    case increaseRatio
    case decreaseRatio
    case toggleFloating
    case retile
    case quit
    // Directional movement
    case moveLeft
    case moveRight
    case moveUp
    case moveDown
    // Directional focus
    case focusLeft
    case focusRight
    case focusUp
    case focusDown
    // Workspace (Space) operations
    case switchToSpace(Int)
    case moveWindowToSpace(Int)

    var description: String {
        switch self {
        case .focusNext: return "Focus Next Window"
        case .focusPrevious: return "Focus Previous Window"
        case .swapNext: return "Swap with Next"
        case .swapPrevious: return "Swap with Previous"
        case .moveToMaster: return "Move to Master"
        case .cycleMaster: return "Cycle Master"
        case .increaseRatio: return "Increase Master Ratio"
        case .decreaseRatio: return "Decrease Master Ratio"
        case .toggleFloating: return "Toggle Floating"
        case .retile: return "Retile Windows"
        case .quit: return "Quit"
        case .moveLeft: return "Move Window Left"
        case .moveRight: return "Move Window Right"
        case .moveUp: return "Move Window Up"
        case .moveDown: return "Move Window Down"
        case .focusLeft: return "Focus Window Left"
        case .focusRight: return "Focus Window Right"
        case .focusUp: return "Focus Window Up"
        case .focusDown: return "Focus Window Down"
        case .switchToSpace(let num): return "Switch to Space \(num)"
        case .moveWindowToSpace(let num): return "Move Window to Space \(num)"
        }
    }
}

class HotkeyManager {
    private var hotkeys: [Hotkey: HotkeyAction] = [:]
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var windowManager: WindowManagerBridge
    private weak var windowObserver: WindowObserver?
    private var spaceManager: SpaceManager?

    // Test harness for automated testing
    weak var testHarness: HotkeyTestHarness?

    init(windowManager: WindowManagerBridge, windowObserver: WindowObserver, spaceManager: SpaceManager? = nil) {
        self.windowManager = windowManager
        self.windowObserver = windowObserver
        self.spaceManager = spaceManager
        registerDefaultHotkeys()
    }

    deinit {
        stop()
    }

    private func registerDefaultHotkeys() {
        // ============================================
        // i3wm-Style Hotkeys (Cmd = Mod key)
        // ============================================

        // FOCUS - Vim keys (Cmd+h/j/k/l)
        hotkeys[Hotkey(keyCode: 0x04, modifiers: [.command])] = .focusLeft    // Cmd+h
        hotkeys[Hotkey(keyCode: 0x26, modifiers: [.command])] = .focusDown    // Cmd+j
        hotkeys[Hotkey(keyCode: 0x28, modifiers: [.command])] = .focusUp      // Cmd+k
        hotkeys[Hotkey(keyCode: 0x25, modifiers: [.command])] = .focusRight   // Cmd+l

        // FOCUS - Arrow keys (Cmd+Arrows)
        hotkeys[Hotkey(keyCode: 0x7B, modifiers: [.command])] = .focusLeft    // Cmd+←
        hotkeys[Hotkey(keyCode: 0x7D, modifiers: [.command])] = .focusDown    // Cmd+↓
        hotkeys[Hotkey(keyCode: 0x7E, modifiers: [.command])] = .focusUp      // Cmd+↑
        hotkeys[Hotkey(keyCode: 0x7C, modifiers: [.command])] = .focusRight   // Cmd+→

        // MOVE - Vim keys (Cmd+Shift+h/j/k/l)
        hotkeys[Hotkey(keyCode: 0x04, modifiers: [.command, .shift])] = .moveLeft    // Cmd+Shift+h
        hotkeys[Hotkey(keyCode: 0x26, modifiers: [.command, .shift])] = .moveDown    // Cmd+Shift+j
        hotkeys[Hotkey(keyCode: 0x28, modifiers: [.command, .shift])] = .moveUp      // Cmd+Shift+k
        hotkeys[Hotkey(keyCode: 0x25, modifiers: [.command, .shift])] = .moveRight   // Cmd+Shift+l

        // MOVE - Arrow keys (Cmd+Shift+Arrows)
        hotkeys[Hotkey(keyCode: 0x7B, modifiers: [.command, .shift])] = .moveLeft    // Cmd+Shift+←
        hotkeys[Hotkey(keyCode: 0x7D, modifiers: [.command, .shift])] = .moveDown    // Cmd+Shift+↓
        hotkeys[Hotkey(keyCode: 0x7E, modifiers: [.command, .shift])] = .moveUp      // Cmd+Shift+↑
        hotkeys[Hotkey(keyCode: 0x7C, modifiers: [.command, .shift])] = .moveRight   // Cmd+Shift+→

        // LAYOUT CONTROL
        hotkeys[Hotkey(keyCode: 0x0F, modifiers: [.command])] = .retile              // Cmd+r (retile/refresh)

        // Resize master area
        hotkeys[Hotkey(keyCode: 0x1B, modifiers: [.command])] = .decreaseRatio       // Cmd+- (minus)
        hotkeys[Hotkey(keyCode: 0x18, modifiers: [.command])] = .increaseRatio       // Cmd+= (equal/plus)

        // WINDOW CONTROL
        hotkeys[Hotkey(keyCode: 0x31, modifiers: [.command, .shift])] = .toggleFloating  // Cmd+Shift+Space
        hotkeys[Hotkey(keyCode: 0x03, modifiers: [.command, .shift])] = .quit            // Cmd+Shift+f (close - similar to i3's Mod+Shift+q)

        // WORKSPACE (SPACE) SWITCHING - Cmd+1 through Cmd+9
        hotkeys[Hotkey(keyCode: 0x12, modifiers: [.command])] = .switchToSpace(1)  // Cmd+1
        hotkeys[Hotkey(keyCode: 0x13, modifiers: [.command])] = .switchToSpace(2)  // Cmd+2
        hotkeys[Hotkey(keyCode: 0x14, modifiers: [.command])] = .switchToSpace(3)  // Cmd+3
        hotkeys[Hotkey(keyCode: 0x15, modifiers: [.command])] = .switchToSpace(4)  // Cmd+4
        hotkeys[Hotkey(keyCode: 0x17, modifiers: [.command])] = .switchToSpace(5)  // Cmd+5
        hotkeys[Hotkey(keyCode: 0x16, modifiers: [.command])] = .switchToSpace(6)  // Cmd+6
        hotkeys[Hotkey(keyCode: 0x1A, modifiers: [.command])] = .switchToSpace(7)  // Cmd+7
        hotkeys[Hotkey(keyCode: 0x1C, modifiers: [.command])] = .switchToSpace(8)  // Cmd+8
        hotkeys[Hotkey(keyCode: 0x19, modifiers: [.command])] = .switchToSpace(9)  // Cmd+9

        // MOVE WINDOW TO SPACE - Cmd+Shift+1 through Cmd+Shift+9
        hotkeys[Hotkey(keyCode: 0x12, modifiers: [.command, .shift])] = .moveWindowToSpace(1)  // Cmd+Shift+1
        hotkeys[Hotkey(keyCode: 0x13, modifiers: [.command, .shift])] = .moveWindowToSpace(2)  // Cmd+Shift+2
        hotkeys[Hotkey(keyCode: 0x14, modifiers: [.command, .shift])] = .moveWindowToSpace(3)  // Cmd+Shift+3
        hotkeys[Hotkey(keyCode: 0x15, modifiers: [.command, .shift])] = .moveWindowToSpace(4)  // Cmd+Shift+4
        hotkeys[Hotkey(keyCode: 0x17, modifiers: [.command, .shift])] = .moveWindowToSpace(5)  // Cmd+Shift+5
        hotkeys[Hotkey(keyCode: 0x16, modifiers: [.command, .shift])] = .moveWindowToSpace(6)  // Cmd+Shift+6
        hotkeys[Hotkey(keyCode: 0x1A, modifiers: [.command, .shift])] = .moveWindowToSpace(7)  // Cmd+Shift+7
        hotkeys[Hotkey(keyCode: 0x1C, modifiers: [.command, .shift])] = .moveWindowToSpace(8)  // Cmd+Shift+8
        hotkeys[Hotkey(keyCode: 0x19, modifiers: [.command, .shift])] = .moveWindowToSpace(9)  // Cmd+Shift+9

        print("Registered \(hotkeys.count) default hotkeys (i3wm-style + workspace switching)")
    }

    func start() -> Bool {
        // Check for accessibility permissions
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
        let options = [key: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            print("Accessibility permissions required for hotkeys")
            return false
        }

        // Create event tap
        let eventMask = (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                return autoreleasepool {
                    guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                    let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                    return manager.handleEvent(proxy: proxy, type: type, event: event)
                }
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("Failed to create event tap")
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        print("✓ Hotkey manager started")
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            runLoopSource = nil
        }

        print("Hotkey manager stopped")
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Handle tap disabled events
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }

        // Get key code and modifiers
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))

        // Filter to just the modifiers we care about
        let relevantModifiers: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        let modifiers = flags.intersection(relevantModifiers)

        let hotkey = Hotkey(keyCode: keyCode, modifiers: modifiers)

        // Check if this is a registered hotkey
        if let action = hotkeys[hotkey] {
            print("Hotkey pressed: \(action.description)")

            // Notify test harness if in test mode
            if let harness = testHarness {
                let hotkeyDesc = formatHotkey(keyCode: keyCode, modifiers: modifiers)
                harness.recordResult(hotkey: hotkeyDesc, action: action.description, detected: true)
            }

            executeAction(action)
            // Consume the event (don't pass it along)
            return nil
        }

        // Not our hotkey, pass it through
        return Unmanaged.passRetained(event)
    }

    private func executeAction(_ action: HotkeyAction) {
        guard let observer = windowObserver else {
            print("Window observer not available")
            return
        }

        switch action {
        case .focusNext:
            focusNextWindow()

        case .focusPrevious:
            focusPreviousWindow()

        case .swapNext:
            swapWithNext()

        case .swapPrevious:
            swapWithPrevious()

        case .moveToMaster:
            moveToMaster()

        case .cycleMaster:
            cycleMaster()

        case .increaseRatio:
            let currentRatio = windowManager.getMasterRatio()
            let newRatio = min(currentRatio + 0.05, 0.9)
            print("Increasing master ratio: \(currentRatio) → \(newRatio)")
            windowManager.setLayoutConfig(gaps: 10, padding: 10, masterRatio: newRatio)
            observer.performLayout()

        case .decreaseRatio:
            let currentRatio = windowManager.getMasterRatio()
            let newRatio = max(currentRatio - 0.05, 0.1)
            print("Decreasing master ratio: \(currentRatio) → \(newRatio)")
            windowManager.setLayoutConfig(gaps: 10, padding: 10, masterRatio: newRatio)
            observer.performLayout()

        case .toggleFloating:
            toggleFloating()

        case .retile:
            print("Retiling all windows")
            observer.performLayout()

        case .quit:
            print("Quit hotkey pressed")
            // Don't actually quit if in test mode
            if testHarness == nil {
                NSApp.terminate(nil)
            }

        // Directional movement
        case .moveLeft:
            moveWindowInDirection(.left)

        case .moveRight:
            moveWindowInDirection(.right)

        case .moveUp:
            moveWindowInDirection(.up)

        case .moveDown:
            moveWindowInDirection(.down)

        // Directional focus
        case .focusLeft:
            focusWindowInDirection(.left)

        case .focusRight:
            focusWindowInDirection(.right)

        case .focusUp:
            focusWindowInDirection(.up)

        case .focusDown:
            focusWindowInDirection(.down)

        // Workspace operations
        case .switchToSpace(let number):
            switchToSpace(number)

        case .moveWindowToSpace(let number):
            moveWindowToSpace(number)
        }
    }

    enum Direction {
        case left, right, up, down
    }

    private func moveWindowInDirection(_ direction: Direction) {
        guard let observer = windowObserver else { return }
        guard let currentId = observer.focusedWindowId else {
            print("No focused window to move")
            return
        }

        let index = windowManager.getWindowIndex(currentId)
        guard index >= 0 else {
            print("Focused window not found in manager")
            return
        }

        let count = windowManager.getWindowCount()
        guard count > 1 else {
            print("Only one window, cannot move")
            return
        }

        var targetIndex = index

        switch direction {
        case .left:
            // In BSP layout, left means:
            // - If in stack (index > 0), move to master (index 0)
            // - If in master (index 0), swap with last in stack
            if index == 0 {
                targetIndex = count - 1
                print("Moving master window to end of stack")
            } else {
                targetIndex = 0
                print("Moving stack window to master")
            }

        case .right:
            // In BSP layout, right means:
            // - If in master (index 0), swap with first in stack
            // - If in stack, move toward end of stack
            if index == 0 {
                targetIndex = 1
                print("Moving master window to stack")
            } else if index < count - 1 {
                targetIndex = index + 1
                print("Moving down in stack")
            } else {
                print("Already at bottom of stack")
                return
            }

        case .up:
            // Move up in the stack (toward master)
            if index > 0 {
                targetIndex = index - 1
                print("Moving up in stack (toward master)")
            } else {
                print("Already at master position")
                return
            }

        case .down:
            // Move down in the stack (away from master)
            if index < count - 1 {
                targetIndex = index + 1
                print("Moving down in stack")
            } else {
                print("Already at bottom of stack")
                return
            }
        }

        // Perform the swap
        print("Swapping window at index \(index) with \(targetIndex)")
        windowManager.swapWindows(index1: index, index2: targetIndex)
        observer.performLayout()

        // Keep focus on the moved window
        // The window ID stays the same, it just moved to a different position
        _ = observer.focusWindow(currentId)
    }

    private func focusWindowInDirection(_ direction: Direction) {
        guard let observer = windowObserver else { return }

        let windowIds = observer.getAllWindowIds()
        guard !windowIds.isEmpty else {
            print("No windows to focus")
            return
        }

        let currentIndex: Int
        if let currentId = observer.focusedWindowId,
           let index = windowIds.firstIndex(of: currentId) {
            currentIndex = index
        } else {
            currentIndex = 0
        }

        var targetIndex = currentIndex

        switch direction {
        case .left:
            // Focus master (index 0) if in stack, or last window if in master
            if currentIndex == 0 {
                targetIndex = windowIds.count - 1
                print("Focusing left: last window in stack")
            } else {
                targetIndex = 0
                print("Focusing left: master window")
            }

        case .right:
            // Focus first in stack if in master, otherwise cycle in stack
            if currentIndex == 0 {
                targetIndex = windowIds.count > 1 ? 1 : 0
                print("Focusing right: first stack window")
            } else {
                targetIndex = (currentIndex % (windowIds.count - 1)) + 1
                print("Focusing right: next in stack")
            }

        case .up:
            // Focus previous window (wrapping)
            targetIndex = currentIndex == 0 ? windowIds.count - 1 : currentIndex - 1
            print("Focusing up: previous window")

        case .down:
            // Focus next window (wrapping)
            targetIndex = (currentIndex + 1) % windowIds.count
            print("Focusing down: next window")
        }

        let targetWindowId = windowIds[targetIndex]
        _ = observer.focusWindow(targetWindowId)
    }

    private func focusNextWindow() {
        guard let observer = windowObserver else { return }

        let windowIds = observer.getAllWindowIds()
        guard !windowIds.isEmpty else {
            print("No windows to focus")
            return
        }

        var nextIndex = 0
        if let currentId = observer.focusedWindowId,
           let currentIndex = windowIds.firstIndex(of: currentId) {
            nextIndex = (currentIndex + 1) % windowIds.count
        }

        let nextWindowId = windowIds[nextIndex]
        print("Focusing next window: \(nextWindowId)")
        _ = observer.focusWindow(nextWindowId)
    }

    private func focusPreviousWindow() {
        guard let observer = windowObserver else { return }

        let windowIds = observer.getAllWindowIds()
        guard !windowIds.isEmpty else {
            print("No windows to focus")
            return
        }

        var prevIndex = windowIds.count - 1
        if let currentId = observer.focusedWindowId,
           let currentIndex = windowIds.firstIndex(of: currentId) {
            prevIndex = currentIndex == 0 ? windowIds.count - 1 : currentIndex - 1
        }

        let prevWindowId = windowIds[prevIndex]
        print("Focusing previous window: \(prevWindowId)")
        _ = observer.focusWindow(prevWindowId)
    }

    private func swapWithNext() {
        guard let observer = windowObserver else { return }
        guard let currentId = observer.focusedWindowId else {
            print("No focused window to swap")
            return
        }

        let index = windowManager.getWindowIndex(currentId)
        guard index >= 0 else {
            print("Focused window not found in manager")
            return
        }

        let count = windowManager.getWindowCount()
        let nextIndex = (index + 1) % count

        print("Swapping window at index \(index) with \(nextIndex)")
        windowManager.swapWindows(index1: index, index2: nextIndex)
        observer.performLayout()
    }

    private func swapWithPrevious() {
        guard let observer = windowObserver else { return }
        guard let currentId = observer.focusedWindowId else {
            print("No focused window to swap")
            return
        }

        let index = windowManager.getWindowIndex(currentId)
        guard index >= 0 else {
            print("Focused window not found in manager")
            return
        }

        let count = windowManager.getWindowCount()
        let prevIndex = index == 0 ? count - 1 : index - 1

        print("Swapping window at index \(index) with \(prevIndex)")
        windowManager.swapWindows(index1: index, index2: prevIndex)
        observer.performLayout()
    }

    private func moveToMaster() {
        guard let observer = windowObserver else { return }
        guard let currentId = observer.focusedWindowId else {
            print("No focused window to move")
            return
        }

        print("Moving window \(currentId) to master position")
        if windowManager.moveToFront(currentId) {
            observer.performLayout()
            print("✓ Moved to master")
        } else {
            print("✗ Failed to move to master")
        }
    }

    private func cycleMaster() {
        let count = windowManager.getWindowCount()
        guard count > 1 else {
            print("Not enough windows to cycle")
            return
        }

        // Move first window to the end
        _ = windowManager.getWindowIdAtIndex(0) // Get first window ID for potential future use
        windowManager.swapWindows(index1: 0, index2: count - 1)

        print("Cycled master window")
        windowObserver?.performLayout()
    }

    private func toggleFloating() {
        guard let observer = windowObserver else { return }
        guard let currentId = observer.focusedWindowId else {
            print("No focused window")
            return
        }

        // TODO: Implement floating state in Zig core
        print("TODO: Toggle floating for window \(currentId)")
    }

    private func formatHotkey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String {
        let modStr = modifierString(for: modifiers)
        let keyStr = keyCodeString(for: keyCode)
        return "\(modStr)+\(keyStr)"
    }

    func printRegisteredHotkeys() {
        print("\n=== Registered Hotkeys ===")
        for (hotkey, action) in hotkeys.sorted(by: { $0.value.description < $1.value.description }) {
            let modStr = modifierString(for: hotkey.modifiers)
            let keyStr = keyCodeString(for: hotkey.keyCode)
            print("\(modStr)+\(keyStr): \(action)")
        }
        print("========================\n")
    }

    private func modifierString(for modifiers: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("Ctrl") }
        if modifiers.contains(.option) { parts.append("Opt") }
        if modifiers.contains(.shift) { parts.append("Shift") }
        if modifiers.contains(.command) { parts.append("Cmd") }
        return parts.joined(separator: "+")
    }

    private func keyCodeString(for keyCode: UInt16) -> String {
        // Common key codes
        switch keyCode {
        case 0x00: return "A"
        case 0x03: return "F"
        case 0x04: return "H"
        case 0x0C: return "Q"
        case 0x0F: return "R"
        case 0x12: return "1"
        case 0x13: return "2"
        case 0x14: return "3"
        case 0x15: return "4"
        case 0x16: return "6"
        case 0x17: return "5"
        case 0x18: return "="
        case 0x19: return "9"
        case 0x1A: return "7"
        case 0x1B: return "-"
        case 0x1C: return "8"
        case 0x25: return "L"
        case 0x26: return "J"
        case 0x28: return "K"
        case 0x31: return "Space"
        case 0x7B: return "←"
        case 0x7C: return "→"
        case 0x7D: return "↓"
        case 0x7E: return "↑"
        default: return "Key(\(keyCode))"
        }
    }

    // MARK: - Workspace Operations

    private func switchToSpace(_ number: Int) {
        guard let spaceManager = spaceManager else {
            print("SpaceManager not available")
            return
        }

        print("Switching to space \(number)")
        spaceManager.switchToSpaceNumber(number)
    }

    private func moveWindowToSpace(_ number: Int) {
        print("\n🎬 DEBUG: HotkeyManager.moveWindowToSpace called")
        print("  Requested space number: \(number)")

        guard let spaceManager = spaceManager else {
            print("  ❌ SpaceManager not available")
            return
        }
        print("  ✅ SpaceManager available")

        guard let observer = windowObserver else {
            print("  ❌ WindowObserver not available")
            return
        }
        print("  ✅ WindowObserver available")

        // Try to get MWM's internally tracked focused window
        var windowId = observer.focusedWindowId

        // If MWM hasn't tracked a focused window yet, sync from system
        if windowId == nil {
            print("  ⚙️  MWM hasn't tracked a focused window yet, syncing from system...")
            if observer.syncFocusedWindowFromSystem() {
                windowId = observer.focusedWindowId
            }
        }

        guard let windowId = windowId else {
            print("  ❌ No focused window found")
            print("  💡 Make sure a window is focused and managed by MWM")
            return
        }
        print("  ✅ Focused window ID (MWM internal): \(windowId)")

        // Get window element to extract CGWindowID and frame
        guard let windowElement = observer.getWindowElement(windowId) else {
            print("  ❌ Could not get window element for window \(windowId)")
            return
        }
        print("  ✅ Got window element")

        // Get the CGWindowID from the window element
        var cgWindowID: UInt32 = 0
        let result = _AXUIElementGetWindow(windowElement, &cgWindowID)
        guard result == .success else {
            print("  ❌ Could not get CGWindowID from window element")
            return
        }
        print("  ✅ Real macOS CGWindowID: \(cgWindowID)")

        // Get window title for debugging
        if let title = WindowController.getTitle(window: windowElement) {
            print("  📝 Window title: \"\(title)\"")
        }

        // Get window frame for drag simulation
        guard let frame = WindowController.getFrame(window: windowElement) else {
            print("  ❌ Could not get window frame")
            return
        }
        print("  ✅ Window frame: \(frame)")

        print("  → Calling spaceManager.moveWindowToSpaceNumber(\(cgWindowID), \(number), frame: \(frame))")
        spaceManager.moveWindowToSpaceNumber(UInt64(cgWindowID), spaceNumber: number, windowFrame: frame)

        // After moving, retile the current space
        print("  → Calling performLayout() to retile")
        observer.performLayout()
    }
}
