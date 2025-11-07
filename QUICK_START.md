# MWM Quick Start Guide

## Installation

```bash
# Build the project
mise run build

# Run MWM
mise run run
```

## First-Time Setup

### 1. Grant Accessibility Permissions
When prompted:
- Open **System Preferences → Security & Privacy → Privacy → Accessibility**
- Add MWM to the list and enable it

### 2. Enable Workspace Shortcuts (Required for Space features)
- Open **System Preferences → Keyboard → Shortcuts → Mission Control**
- Enable "Switch to Desktop 1" through "Switch to Desktop 9"
- Ensure they use `^1` through `^9` (Ctrl+number, default)

### 3. Create Multiple Spaces
- Open Mission Control (F3 or swipe up with 3 fingers)
- Click the "+" button to add at least one more Space
- You should have at least 2 Spaces for workspace features

## Essential Hotkeys

### Window Focus
- `Cmd+H` / `Cmd+←` - Focus left window
- `Cmd+J` / `Cmd+↓` - Focus down window
- `Cmd+K` / `Cmd+↑` - Focus up window
- `Cmd+L` / `Cmd+→` - Focus right window

### Window Movement
- `Cmd+Shift+H` / `Cmd+Shift+←` - Move window left
- `Cmd+Shift+J` / `Cmd+Shift+↓` - Move window down
- `Cmd+Shift+K` / `Cmd+Shift+↑` - Move window up
- `Cmd+Shift+L` / `Cmd+Shift+→` - Move window right

### Layout
- `Cmd+R` - Retile/refresh layout
- `Cmd+-` - Decrease master area
- `Cmd+=` - Increase master area

### Workspaces (Spaces)
- `Cmd+1-9` - Switch to Space 1-9
- `Cmd+Shift+1-9` - Move focused window to Space 1-9

### System
- `Cmd+Shift+F` - Quit MWM

## Testing Window Movement

1. **Start MWM**: `mise run run`
2. **Focus a window**: Use `Cmd+H/J/K/L` or click on a window
3. **Move to another Space**: Press `Cmd+Shift+2` (or any number 1-9)
4. **Verify**: You should see:
   - Mouse briefly moves to window title bar
   - Space transition animation plays (~500ms)
   - Window appears on target Space

## Documentation

- **[README.md](README.md)** - Full documentation
- **[HOTKEYS.md](HOTKEYS.md)** - Complete shortcuts reference
- **[CHANGELOG.md](CHANGELOG.md)** - Version history
- **[docs/WINDOW_MOVEMENT_TEST_GUIDE.md](docs/WINDOW_MOVEMENT_TEST_GUIDE.md)** - Window movement testing

## Troubleshooting

**"No focused window found"**
- Solution: Use `Cmd+H/J/K/L` to focus a window first

**"Failed to get symbolic hotkey"**
- Solution: Enable Mission Control shortcuts in System Preferences

**Window doesn't move**
- Make sure window is managed by MWM (not Finder, System dialogs)
- Check console output for errors

**Wrong window moved**
- This was a bug that's now fixed
- Make sure you're running the latest version

## Resources

- GitHub Issues: Report problems
- Testing Guide: `docs/WINDOW_MOVEMENT_TEST_GUIDE.md`

---

**Welcome to MWM!** For complete documentation, see [README.md](README.md)
