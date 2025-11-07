# MWM

Tiling window manager for macOS. Implements window management logic in Zig with macOS integration in Swift.

## Features

- BSP (Binary Space Partitioning) layout algorithm
- Menu bar application with global hotkeys
- Accessibility API integration for window control
- Configurable gaps, padding, and master ratio

## Architecture

```
┌─────────────────────────────────────┐
│         Swift UI Layer              │
│  - Menu bar app                     │
│  - Accessibility permissions        │
│  - AXUIElement window control       │
│  - Window event observers           │
│  - Hotkey registration              │
└──────────────┬──────────────────────┘
               │ C ABI Bridge
               │
┌──────────────▼──────────────────────┐
│         Zig Core Logic              │
│  - Window registry                  │
│  - Layout algorithms (BSP, etc)     │
│  - Event processing                 │
│  - Configuration management         │
└─────────────────────────────────────┘
```

This separation deliberately keeps platform-agnostic tiling logic in Zig for portability to other window systems (X11, Wayland) while Swift handles macOS-specific APIs.

## Requirements

- macOS 13.0+
- mise (for tool version management)
- Accessibility permissions

## Building

```bash
# Build application
mise run build

# Run tests
mise run test

# Run application
mise run run

# Clean artifacts
mise run clean
```

## Installation

```bash
mise run install
```

Installs binary to `/usr/local/bin/mwm`.

## Usage

1. Grant accessibility permissions when prompted (System Preferences → Security & Privacy → Privacy → Accessibility)
2. Run `mise run run` or launch the application directly
3. See [HOTKEYS.md](HOTKEYS.md) for keyboard shortcuts

Menu options:
- About MWM
- Request Accessibility Permission
- Show Hotkeys
- Debug: Print Windows
- Quit

## Debugging

View logs in Console.app or run `mise run run` for terminal output. Logs include window enumeration, layout calculations, and hotkey events.

## Project Structure

```
mwm/
├── build.zig              # Zig build configuration
├── Package.swift          # Swift package configuration
├── .mise.toml            # Tool versions and tasks
├── include/
│   └── mwm_bridge.h      # C ABI header
├── src/                  # Zig source code
│   ├── core.zig          # Window manager core
│   ├── window.zig        # Window structures
│   ├── layout.zig        # Layout algorithms
│   └── bridge.zig        # C ABI exports
└── Sources/MWM/          # Swift source code
    ├── main.swift
    ├── AppDelegate.swift
    ├── AccessibilityManager.swift
    ├── WindowManagerBridge.swift
    └── WindowObserver.swift
```

## Configuration

Default configuration:
- Gaps: 10px
- Padding: 10px
- Master ratio: 50%

## Roadmap

- [x] Window manipulation commands
- [x] Global hotkey support
- [x] Automated testing
- [ ] Floating window mode
- [ ] Multi-monitor support
- [ ] Additional layout algorithms
- [ ] Configuration file support
- [ ] Per-application window rules
