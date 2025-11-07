# MWM Documentation

This directory contains documentation for MWM (Mac Window Manager).

## User Documentation

- **[WINDOW_MOVEMENT_TEST_GUIDE.md](WINDOW_MOVEMENT_TEST_GUIDE.md)** - How to test and use window movement between Spaces

## Quick Links

- [Main README](../README.md) - Project overview, installation, and usage
- [Keyboard Shortcuts](../HOTKEYS.md) - All available hotkeys
- [Quick Start Guide](../QUICK_START.md) - Getting started with MWM
- [Changelog](../CHANGELOG.md) - Version history

## Architecture Overview

MWM uses a hybrid approach for workspace (Space) management:

### Space Detection
- Uses CGS Private APIs for detecting Spaces
- `CGSCopySpaces` - List all Spaces
- `CGSGetActiveSpace` - Get current Space
- `CGSMainConnectionID` - Connection management

### Space Switching
- Uses keyboard shortcut simulation (Ctrl+1-9)
- Requires user to enable Mission Control shortcuts

### Window Movement
- Uses Amethyst's drag-and-switch method
- Simulates window drag + space switch
- APIs: `CGSGetSymbolicHotKeyValue`, `CGSIsSymbolicHotKeyEnabled`, `CGSSetSymbolicHotKeyEnabled`
- Timing: ~500ms (visible animation)

See [WINDOW_MOVEMENT_TEST_GUIDE.md](WINDOW_MOVEMENT_TEST_GUIDE.md) for testing and usage instructions.
