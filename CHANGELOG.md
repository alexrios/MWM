# Changelog

All notable changes to MWM (Mac Window Manager) will be documented in this file.

## [Current] - 2025-01-07

### Added
- **Workspace (Space) Support**: Full integration with macOS Spaces (Mission Control)
  - Space switching via `Cmd+1-9` hotkeys
  - Window movement between Spaces via `Cmd+Shift+1-9` hotkeys
  - Automatic Space detection using CGS private APIs
  - Dynamic symbolic hotkey detection for reliable operation

- **Space Management Infrastructure** (`SpaceManager.swift`)
  - `CGSCopySpaces` integration for Space enumeration
  - `CGSGetActiveSpace` for current Space detection
  - `CGSMainConnectionID` for connection management
  - Keyboard shortcut simulation for Space switching (Ctrl+1-9)
  - Amethyst-style drag-and-switch for window movement
  - Symbolic HotKey APIs for user hotkey detection:
    - `CGSGetSymbolicHotKeyValue` - Gets configured hotkeys
    - `CGSIsSymbolicHotKeyEnabled` - Checks hotkey status
    - `CGSSetSymbolicHotKeyEnabled` - Temporarily enables hotkeys

- **Focus Synchronization** (`WindowObserver.swift`)
  - `syncFocusedWindowFromSystem()` - Detects currently focused window
  - Automatic focus tracking for window operations
  - Prevents incorrect window targeting during operations

### Changed
- **Window Movement Implementation**
  - Switched from broken CGS APIs to Amethyst's drag-and-switch approach
  - Removed non-functional `CGSAddWindowsToSpaces` and `CGSRemoveWindowsFromSpaces`
  - Now simulates mouse drag + space switch for reliable window movement
  - Added ~500ms visible animation (50ms grab + 400ms space transition)

### Fixed
- Window movement no longer grabs wrong windows (e.g., terminal running MWM)
- Space switching now works reliably across macOS versions
- Focus detection properly syncs with system state

### Documentation
- Created comprehensive technical documentation in `docs/` directory
- Added `WINDOW_MOVEMENT_TEST_GUIDE.md` for testing instructions
- Documented CGS API limitations in `CGS_APIS_BROKEN.md`
- Explained Amethyst's approach in `AMETHYST_SOLUTION.md`
- Analyzed alternatives in `WINDOW_MOVEMENT_ALTERNATIVES.md`
- Updated README with accurate implementation details

### Development
- Removed 18+ test files and scripts from root directory
- Cleaned up broken/unused CGS API declarations
- Organized technical documentation into `docs/` directory
- Improved debug logging for troubleshooting

### Technical Notes
This implementation uses Amethyst's proven approach for window movement because:
1. CGS window movement APIs exist but don't function on macOS 13+
2. Drag-and-switch simulation is the only reliable method
3. Works without SIP disabled
4. Compatible across macOS versions

## Requirements
- macOS 13.0+
- Accessibility permissions
- Mission Control keyboard shortcuts enabled (System Preferences → Keyboard → Shortcuts → Mission Control)
- At least 2 Spaces created

## Known Limitations
- Window movement shows visible animation (~500ms)
- Requires Mission Control shortcuts to be configured
- Can only move windows managed by MWM
- Brief mouse cursor movement during operation
