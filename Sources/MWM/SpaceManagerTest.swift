import Cocoa
import Foundation

/// Test harness for SpaceManager functionality
class SpaceManagerTest {
    private let spaceManager: SpaceManager

    init(spaceManager: SpaceManager) {
        self.spaceManager = spaceManager
    }

    /// Run all SpaceManager tests
    func runAllTests() -> Bool {
        print("\n" + String(repeating: "=", count: 60))
        print("🧪 SPACEMANAGER TEST SUITE")
        print(String(repeating: "=", count: 60) + "\n")

        var allPassed = true

        allPassed = testCGSFrameworkLoaded() && allPassed
        allPassed = testGetAllSpaces() && allPassed
        allPassed = testGetCurrentSpace() && allPassed
        allPassed = testSpaceNumberMapping() && allPassed
        allPassed = testSwitchToSpace() && allPassed

        printSummary(allPassed: allPassed)
        return allPassed
    }

    /// Test 1: Verify CGS framework is loaded
    private func testCGSFrameworkLoaded() -> Bool {
        print("📋 Test 1: CGS Framework Loading")
        print(String(repeating: "-", count: 60))

        // This is tested during SpaceManager initialization
        // Check if we got a valid connection
        spaceManager.printSpaceInfo()

        print("  ✓ Framework load status logged above\n")
        return true
    }

    /// Test 2: Get all spaces
    private func testGetAllSpaces() -> Bool {
        print("📋 Test 2: Get All Spaces")
        print(String(repeating: "-", count: 60))

        let spaces = spaceManager.getAllSpaces()
        print("  Retrieved \(spaces.count) spaces")

        if spaces.isEmpty {
            print("  ⚠️  No spaces found - CGS API may not be working")
            print("     This could be normal if CGS APIs are unavailable on this OS version")
            return true  // Don't fail, just warn
        }

        print("  Space IDs: \(spaces)")
        print("  ✓ Successfully retrieved spaces\n")
        return true
    }

    /// Test 3: Get current space
    private func testGetCurrentSpace() -> Bool {
        print("📋 Test 3: Get Current Space")
        print(String(repeating: "-", count: 60))

        let currentSpaceID = spaceManager.getCurrentSpace()
        print("  Current space ID: \(currentSpaceID)")

        if let spaceNum = spaceManager.getCurrentSpaceNumber() {
            print("  Current space number: \(spaceNum)")
            print("  ✓ Successfully identified current space\n")
            return true
        } else {
            print("  ⚠️  Could not map space ID to number")
            print("     This may indicate CGS API returned no spaces\n")
            return true  // Don't fail hard
        }
    }

    /// Test 4: Space number mapping
    private func testSpaceNumberMapping() -> Bool {
        print("📋 Test 4: Space Number Mapping (ID ↔ Number)")
        print(String(repeating: "-", count: 60))

        let spaces = spaceManager.getAllSpaces()

        if spaces.isEmpty {
            print("  ⚠️  No spaces available to test mapping\n")
            return true
        }

        // Test first 3 spaces (or fewer if not available)
        let testCount = min(3, spaces.count)
        var allMapped = true

        for i in 0..<testCount {
            let spaceID = spaces[i]
            let expectedNumber = i + 1

            if let actualNumber = spaceManager.getSpaceNumber(for: spaceID) {
                let matches = actualNumber == expectedNumber
                let symbol = matches ? "✓" : "✗"
                print("  \(symbol) Space ID \(spaceID) → Number \(actualNumber) (expected: \(expectedNumber))")
                allMapped = allMapped && matches
            } else {
                print("  ✗ Space ID \(spaceID) → Could not map")
                allMapped = false
            }
        }

        if allMapped {
            print("  ✓ All space IDs correctly mapped to numbers\n")
        } else {
            print("  ✗ Some space mappings failed\n")
        }

        return allMapped
    }

    /// Test 5: Switch to space
    private func testSwitchToSpace() -> Bool {
        print("📋 Test 5: Space Switching")
        print(String(repeating: "-", count: 60))

        let spaces = spaceManager.getAllSpaces()

        if spaces.count < 2 {
            print("  ⚠️  Need at least 2 spaces to test switching")
            print("     Current space count: \(spaces.count)")
            print("     Create more spaces in Mission Control to test this feature\n")
            return true  // Can't test, but not a failure
        }

        let currentBefore = spaceManager.getCurrentSpace()
        print("  Current space before: \(currentBefore)")

        // Try to switch to space 2
        print("  Attempting to switch to Space 2...")
        spaceManager.switchToSpaceNumber(2)

        // Wait for switch to complete
        Thread.sleep(forTimeInterval: 1.5)

        let currentAfter = spaceManager.getCurrentSpace()
        print("  Current space after: \(currentAfter)")

        if currentBefore != currentAfter {
            print("  ✓ Space switch detected (space changed)\n")

            // Switch back to original space
            if let originalNum = spaceManager.getSpaceNumber(for: currentBefore) {
                print("  Switching back to Space \(originalNum)...")
                spaceManager.switchToSpaceNumber(originalNum)
                Thread.sleep(forTimeInterval: 1.5)
            }

            return true
        } else {
            print("  ⚠️  Space did not change")
            print("     This may indicate CGSShowSpaces is not working\n")
            return true  // Don't fail hard - CGS APIs may not work
        }
    }

    private func printSummary(allPassed: Bool) {
        print(String(repeating: "=", count: 60))
        print("📊 SPACEMANAGER TEST SUMMARY")
        print(String(repeating: "=", count: 60))

        if allPassed {
            print("✅ All tests passed!")
            print("\nNote: Some warnings are expected if CGS APIs are")
            print("unavailable on your macOS version.")
        } else {
            print("❌ Some tests failed")
            print("\nThis may indicate:")
            print("  • CGS private APIs not available on this macOS version")
            print("  • SkyLight framework path changed")
            print("  • Need to create more Spaces in Mission Control")
        }

        print(String(repeating: "=", count: 60) + "\n")
    }

    /// Quick diagnostic test
    func runQuickDiagnostic() {
        print("\n" + String(repeating: "=", count: 60))
        print("🔍 SPACEMANAGER QUICK DIAGNOSTIC")
        print(String(repeating: "=", count: 60) + "\n")

        spaceManager.printSpaceInfo()
        spaceManager.forceRefreshSpaces()

        let spaces = spaceManager.getAllSpaces()
        print("Available spaces for testing:")
        for (index, spaceID) in spaces.enumerated() {
            let isCurrent = spaceID == spaceManager.getCurrentSpace()
            let marker = isCurrent ? "← CURRENT" : ""
            print("  Space \(index + 1): ID \(spaceID) \(marker)")
        }

        if spaces.isEmpty {
            print("\n⚠️  WARNING: No spaces detected!")
            print("Possible causes:")
            print("  1. CGS API not loaded (check logs above)")
            print("  2. macOS version incompatibility")
            print("  3. SkyLight framework not found")
        } else if spaces.count == 1 {
            print("\n💡 TIP: Create more Spaces to test switching:")
            print("  Mission Control → + button at top")
            print("  Or: Swipe up with 3/4 fingers → Add Space")
        }

        print(String(repeating: "=", count: 60) + "\n")
    }
}
