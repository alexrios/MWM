# Window Movement Test Guide

## Implementation Summary

MWM now uses **Amethyst's drag-and-switch approach** to move windows between Spaces. This simulates manually dragging a window while switching Spaces.

## Prerequisites

1. **System Preferences Setup**:
   - Go to System Preferences → Keyboard → Keyboard Shortcuts → Mission Control
   - Ensure "Switch to Desktop 1", "Switch to Desktop 2", etc. are enabled
   - The shortcuts can be any keys (Ctrl+1, Ctrl+2, etc.) - MWM will detect them automatically

2. **Multiple Spaces**:
   - Make sure you have at least 2 Spaces created
   - Open Mission Control (F3 or swipe up with 3 fingers) to verify

## How to Test

### Step 1: Start MWM

```bash
# Kill any existing instances
pkill -9 mwm

# Start MWM (it will output to console)
mise run run
```

### Step 2: Focus a Window

**IMPORTANT**: The window MUST be one of the windows managed by MWM (not the terminal running MWM).

**Option A**: Use MWM's focus hotkeys (recommended)
- `Cmd+H` - Focus left window
- `Cmd+J` - Focus down window
- `Cmd+K` - Focus up window
- `Cmd+L` - Focus right window

**Option B**: Click on any managed window
- Click on Google Chrome, Floorp, or any other GUI application
- MWM will automatically detect and sync the focused window

### Step 3: Move the Window to Another Space

Press `Cmd+Shift+[1-9]` to move the focused window to Space 1-9.

Example: `Cmd+Shift+2` moves the window to Space 2.

### Expected Behavior

When you press the hotkey, you should see:

1. **Console output** (verbose debugging):
   ```
   🎬 DEBUG: HotkeyManager.moveWindowToSpace called
     Requested space number: 2
     ✅ SpaceManager available
     ✅ WindowObserver available
     ✅ Focused window ID (MWM internal): 1
     ✅ Got window element
     ✅ Real macOS CGWindowID: 12345
     📝 Window title: "Google Chrome"
     ✅ Window frame: (10.0, 38.0, 741.0, 924.0)
     → Calling spaceManager.moveWindowToSpaceNumber(...)

   🚀 Moving window 12345 to space 2
     ✅ Got space switch hotkey: keyCode=19, flags=123
   ```

2. **Visual animation** (~500ms):
   - Mouse cursor briefly jumps to the window's title bar
   - Space transition animation plays
   - Window appears on the target Space

3. **Result**:
   - The window is now on the target Space
   - You can switch to that Space with `Cmd+2` to verify

## Troubleshooting

### "No focused window found"

**Cause**: MWM hasn't tracked which window is focused.

**Solution**:
- Use MWM's focus hotkeys (Cmd+H/J/K/L) to explicitly focus a window first
- Or click on a managed window, then try again

### "System-focused window is not managed by MWM"

**Cause**: You're trying to move a window that MWM doesn't manage (like the terminal, Finder, or system windows).

**Solution**: Focus a regular GUI application window (Chrome, Floorp, etc.) instead.

### "Failed to get symbolic hotkey"

**Cause**: The Space shortcut is not enabled in System Preferences.

**Solution**:
- Go to System Preferences → Keyboard → Keyboard Shortcuts → Mission Control
- Enable the "Switch to Desktop X" shortcuts

### Wrong window moved (terminal goes fullscreen)

**Cause**: This was a bug in the previous version where we grabbed the system-focused window instead of MWM's tracked window.

**Solution**: This has been fixed. MWM now only moves windows it's managing and tracking.

## Testing Checklist

- [ ] Start MWM from terminal
- [ ] Focus a managed window (use `Cmd+H` or click on Chrome/Floorp)
- [ ] Press `Cmd+Shift+2` (or another number)
- [ ] Verify console shows debug output with correct window title
- [ ] Verify space transition animation plays
- [ ] Verify window appears on target Space
- [ ] Switch to target Space with `Cmd+2` to confirm window moved
- [ ] Test moving window back with `Cmd+Shift+1`

## Known Limitations

1. **Visible animation**: Unlike broken CGS APIs, this approach shows the space transition animation
2. **Speed**: Takes ~500ms (50ms grab + 400ms animation) instead of instant
3. **Requires shortcuts**: Mission Control shortcuts must be configured in System Preferences
4. **User input blocked**: During the 500ms operation, user input is blocked
5. **MWM-managed only**: Can only move windows that MWM is tracking

## Implementation Details

The implementation uses:
- `CGSGetSymbolicHotKeyValue` - Gets user's configured space-switch hotkey
- `CGSIsSymbolicHotKeyEnabled` - Checks if hotkey is enabled
- `CGSSetSymbolicHotKeyEnabled` - Temporarily enables if disabled
- Mouse event simulation - Grabs window by simulating title bar drag
- Keyboard event simulation - Triggers space switch while holding window

This is the **only working approach** for moving windows between Spaces on modern macOS without SIP disabled.
