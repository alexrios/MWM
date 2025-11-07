#ifndef MWM_BRIDGE_H
#define MWM_BRIDGE_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Rect structure matching Zig's CRect
typedef struct {
    float x;
    float y;
    float width;
    float height;
} MWMRect;

// Window structure for passing from Swift to Zig
typedef struct {
    uint64_t id;
    const char *app_name;
    const char *title;
    MWMRect frame;
    bool is_floating;
} MWMWindow;

// Layout command returned from Zig to Swift
typedef struct {
    uint64_t window_id;
    MWMRect frame;
} MWMLayoutCommand;

// Core window manager functions
void mwm_init(void);
void mwm_deinit(void);

// Window management
void mwm_add_window(MWMWindow window);
void mwm_remove_window(uint64_t window_id);
size_t mwm_get_window_count(void);

// Window ordering
uint64_t mwm_get_window_id_at_index(size_t index);
intptr_t mwm_get_window_index(uint64_t window_id);
void mwm_swap_windows(size_t index1, size_t index2);
bool mwm_move_to_front(uint64_t window_id);

// Layout calculation
size_t mwm_calculate_layout(
    float screen_x,
    float screen_y,
    float screen_width,
    float screen_height,
    MWMLayoutCommand *out_commands,
    size_t max_commands
);

// Configuration
void mwm_set_layout_config(uint32_t gaps, uint32_t padding, float master_ratio);

// Debug
void mwm_debug_print_windows(void);

#ifdef __cplusplus
}
#endif

#endif // MWM_BRIDGE_H
