# Keyboard Shortcuts

MWM uses **i3wm-inspired** keyboard shortcuts for a familiar tiling window manager experience.

## Philosophy

- **Mod key** = `Cmd` (Command key on macOS)
- **Mod+keys** = Focus and navigation
- **Mod+Shift+keys** = Move and modify windows
- **Vim keys** (h/j/k/l) and **Arrow keys** both supported

## Complete Shortcuts Reference

### Focus Windows

**Vim-style keys:**
- `Cmd+h` - Focus left (master if in stack, or last window if in master)
- `Cmd+j` - Focus down (next window)
- `Cmd+k` - Focus up (previous window)
- `Cmd+l` - Focus right (first stack window if in master, cycle in stack otherwise)

**Arrow keys:**
- `Cmd+←` - Focus left
- `Cmd+↓` - Focus down
- `Cmd+↑` - Focus up
- `Cmd+→` - Focus right

### Move Windows

**Vim-style keys:**
- `Cmd+Shift+h` - Move window left
  - If in stack → Move to master position
  - If in master → Move to end of stack
- `Cmd+Shift+j` - Move window down in stack
- `Cmd+Shift+k` - Move window up in stack
- `Cmd+Shift+l` - Move window right
  - If in master → Move to stack
  - If in stack → Move down in stack

**Arrow keys:**
- `Cmd+Shift+←` - Move window left
- `Cmd+Shift+↓` - Move window down
- `Cmd+Shift+↑` - Move window up
- `Cmd+Shift+→` - Move window right

### Layout Control

- `Cmd+r` - Retile/refresh layout
- `Cmd+-` - Decrease master area ratio (by 5%, min 10%)
- `Cmd+=` - Increase master area ratio (by 5%, max 90%)

### Window Control

- `Cmd+Shift+Space` - Toggle floating mode (TODO)
- `Cmd+Shift+f` - Quit MWM

## Tips

- **Focus cycling**: Use `Cmd+j/k` or arrow keys to quickly cycle through windows
- **Master area**: The left side of the screen - usually for your main work window
- **Stack area**: The right side - for supporting windows
- **Quick rearrange**: `Cmd+Shift+h` instantly moves any window to master position

## Examples

**Workflow 1: Focusing windows**
```
1. Cmd+j → Focus next window
2. Cmd+j → Focus next window again
3. Cmd+k → Focus previous window
```

**Workflow 2: Moving to master**
```
1. Cmd+j → Focus the window you want
2. Cmd+Shift+h → Move it to master position
```

**Workflow 3: Adjusting layout**
```
1. Cmd+- → Make master area smaller
2. Cmd+= → Make master area larger
3. Cmd+r → Retile if needed
```
