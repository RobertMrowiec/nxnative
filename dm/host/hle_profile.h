// Runtime game profile (DM_PROFILE -> <framework>/profile.tsv), written by dm/games/game.py profile.
// In the multi-game shell (DmShell) and framework builds, the host is compiled once against one game's game_profile.h defaults,
// then switches every DM_GAME_* constant at startup to the chosen game's profile.tsv when DM_PROFILE is set in the environment.
// When DM_PROFILE is unset (standalone Mac / iOS builds, unit tests) or hle_profile.c is not linked, dm_profile() returns NULL
// and every DM_GAME_* macro evaluates to its compiled game_profile.h constant.
#pragma once
#include <stdint.h>
#include <stddef.h>
#include "game_profile.h"

typedef struct {
    char id[32];
    char name[256];
    uint64_t program_id;
    char romfs_marker[256];
    const char *modules[32];
    char modules_buf[256];
    int nmod;
    uint64_t mem_reserve;
    uint64_t mem_alias;
    uint64_t mem_stack;
    uint64_t app_pool;
    uint64_t mem_used;
    uint64_t sys_resource;
    uint64_t stdalloc_cap;
    char args[512];
    char env[512];
    char launch_param[512];
    int mem_map_limit;
    int screen_aspect;
    int present_display;
    int core_preempt;
    int alloc_big_align;
    int fps_target;
    int fps_max;
    int fps_hold;
    int ue_texture_pool;
    char ue_fps_cvar[64];
    int present_snap;
    int pso_mtl4;
    int enc_thread;
    int shared_font_ttf;   // -1 = decide from SDK & imports, 0 = BFTTF header + TTF, 1 = TTF itself
    int pad_layout;
    int opmode;
    int perf_boost;
    int tex_flush_upload;
    int shader_key_skip_off;
    int shader_key_skip_len;
    int render_cond;
    int tex_dirty_upload;
    int tex_dyn_slots;
    int gpu_ts_segment;
    char upscaler_keys[1024];
    int upscaler_n;
    int vconv_range;
    int has_device_api;
    int nvn_api_major;
    int nvn_api_minor;
    struct { char build[40]; char ver[32]; } display_versions[32];
    int n_display_versions;
} dm_profile_t;

// Weak fallback returns NULL in standalone unit tests that do not link hle_profile.c; hle_profile.c provides the strong definition.
#ifdef DM_HLE_PROFILE_IMPL
const dm_profile_t *dm_profile(void);
#else
__attribute__((weak)) const dm_profile_t *dm_profile(void) { return NULL; }
#endif

static inline int dm_profile_shared_font_ttf(void) {
    const dm_profile_t *p = dm_profile();
    if (p) return p->shared_font_ttf;
#ifdef DM_GAME_SHARED_FONT_TTF
    return DM_GAME_SHARED_FONT_TTF ? 1 : 0;
#else
    return -1;
#endif
}

static inline int dm_profile_nvn_api(int api[2]) {
    const dm_profile_t *p = dm_profile();
    if (p) {
        if (!p->has_device_api) return 0;
        api[0] = p->nvn_api_major;
        api[1] = p->nvn_api_minor;
        return 1;
    }
#ifdef DM_GAME_NVN_API_MAJOR
    api[0] = DM_GAME_NVN_API_MAJOR;
    api[1] = DM_GAME_NVN_API_MINOR;
    return 1;
#else
    return 0;
#endif
}

#ifndef DM_GAME_MULTI

#ifdef DM_GAME_ID
static const char *const dm_compiled_game_id __attribute__((unused)) = DM_GAME_ID;
#undef DM_GAME_ID
#define DM_GAME_ID (dm_profile() ? dm_profile()->id : dm_compiled_game_id)
#endif

#ifdef DM_GAME_NAME
static const char *const dm_compiled_game_name __attribute__((unused)) = DM_GAME_NAME;
#undef DM_GAME_NAME
#define DM_GAME_NAME (dm_profile() ? dm_profile()->name : dm_compiled_game_name)
#endif

#ifdef DM_GAME_PROGRAM_ID
enum { dm_has_compiled_program_id = 1 };
static const uint64_t dm_compiled_program_id __attribute__((unused)) = DM_GAME_PROGRAM_ID;
#undef DM_GAME_PROGRAM_ID
#define DM_GAME_PROGRAM_ID (dm_profile() ? dm_profile()->program_id : dm_compiled_program_id)
#endif

#ifdef DM_GAME_ROMFS_MARKER
static const char *const dm_compiled_romfs_marker __attribute__((unused)) = DM_GAME_ROMFS_MARKER;
#undef DM_GAME_ROMFS_MARKER
#define DM_GAME_ROMFS_MARKER (dm_profile() ? dm_profile()->romfs_marker : dm_compiled_romfs_marker)
#endif

#ifdef DM_GAME_MEM_RESERVE
static const uint64_t dm_compiled_mem_reserve __attribute__((unused)) = DM_GAME_MEM_RESERVE;
#undef DM_GAME_MEM_RESERVE
#define DM_GAME_MEM_RESERVE (dm_profile() ? dm_profile()->mem_reserve : dm_compiled_mem_reserve)
#endif

#ifdef DM_GAME_MEM_ALIAS
static const uint64_t dm_compiled_mem_alias __attribute__((unused)) = DM_GAME_MEM_ALIAS;
#undef DM_GAME_MEM_ALIAS
#define DM_GAME_MEM_ALIAS (dm_profile() ? dm_profile()->mem_alias : dm_compiled_mem_alias)
#endif

#ifdef DM_GAME_MEM_STACK
static const uint64_t dm_compiled_mem_stack __attribute__((unused)) = DM_GAME_MEM_STACK;
#undef DM_GAME_MEM_STACK
#define DM_GAME_MEM_STACK (dm_profile() ? dm_profile()->mem_stack : dm_compiled_mem_stack)
#endif

#ifdef DM_GAME_APP_POOL
static const uint64_t dm_compiled_app_pool __attribute__((unused)) = DM_GAME_APP_POOL;
#undef DM_GAME_APP_POOL
#define DM_GAME_APP_POOL (dm_profile() ? dm_profile()->app_pool : dm_compiled_app_pool)
#endif

#ifdef DM_GAME_MEM_USED
static const uint64_t dm_compiled_mem_used __attribute__((unused)) = DM_GAME_MEM_USED;
#undef DM_GAME_MEM_USED
#define DM_GAME_MEM_USED (dm_profile() ? dm_profile()->mem_used : dm_compiled_mem_used)
#endif

#ifdef DM_GAME_SYS_RESOURCE
static const uint64_t dm_compiled_sys_resource __attribute__((unused)) = DM_GAME_SYS_RESOURCE;
#undef DM_GAME_SYS_RESOURCE
#define DM_GAME_SYS_RESOURCE (dm_profile() ? dm_profile()->sys_resource : dm_compiled_sys_resource)
#endif

#ifdef DM_GAME_STDALLOC_CAP
static const uint64_t dm_compiled_stdalloc_cap __attribute__((unused)) = DM_GAME_STDALLOC_CAP;
#undef DM_GAME_STDALLOC_CAP
#define DM_GAME_STDALLOC_CAP (dm_profile() ? dm_profile()->stdalloc_cap : dm_compiled_stdalloc_cap)
#endif

#ifdef DM_GAME_ARGS
static const char *const dm_compiled_game_args __attribute__((unused)) = DM_GAME_ARGS;
#undef DM_GAME_ARGS
#define DM_GAME_ARGS (dm_profile() ? dm_profile()->args : dm_compiled_game_args)
#endif

#ifdef DM_GAME_ENV
static const char *const dm_compiled_game_env __attribute__((unused)) = DM_GAME_ENV;
#undef DM_GAME_ENV
#define DM_GAME_ENV (dm_profile() ? dm_profile()->env : dm_compiled_game_env)
#endif

#ifdef DM_GAME_LAUNCH_PARAM
static const char *const dm_compiled_launch_param __attribute__((unused)) = DM_GAME_LAUNCH_PARAM;
#undef DM_GAME_LAUNCH_PARAM
#define DM_GAME_LAUNCH_PARAM (dm_profile() ? dm_profile()->launch_param : dm_compiled_launch_param)
#endif

#ifdef DM_GAME_MEM_MAP_LIMIT
static const int dm_compiled_mem_map_limit __attribute__((unused)) = DM_GAME_MEM_MAP_LIMIT;
#undef DM_GAME_MEM_MAP_LIMIT
#define DM_GAME_MEM_MAP_LIMIT (dm_profile() ? dm_profile()->mem_map_limit : dm_compiled_mem_map_limit)
#endif

#ifdef DM_GAME_SCREEN_ASPECT
static const int dm_compiled_screen_aspect __attribute__((unused)) = DM_GAME_SCREEN_ASPECT;
#undef DM_GAME_SCREEN_ASPECT
#define DM_GAME_SCREEN_ASPECT (dm_profile() ? dm_profile()->screen_aspect : dm_compiled_screen_aspect)
#endif

#ifdef DM_GAME_PRESENT_DISPLAY
static const int dm_compiled_present_display __attribute__((unused)) = DM_GAME_PRESENT_DISPLAY;
#undef DM_GAME_PRESENT_DISPLAY
#define DM_GAME_PRESENT_DISPLAY (dm_profile() ? dm_profile()->present_display : dm_compiled_present_display)
#endif

#ifdef DM_GAME_CORE_PREEMPT
static const int dm_compiled_core_preempt __attribute__((unused)) = DM_GAME_CORE_PREEMPT;
#undef DM_GAME_CORE_PREEMPT
#define DM_GAME_CORE_PREEMPT (dm_profile() ? dm_profile()->core_preempt : dm_compiled_core_preempt)
#endif

#ifdef DM_GAME_ALLOC_BIG_ALIGN
static const int dm_compiled_alloc_big_align __attribute__((unused)) = DM_GAME_ALLOC_BIG_ALIGN;
#undef DM_GAME_ALLOC_BIG_ALIGN
#define DM_GAME_ALLOC_BIG_ALIGN (dm_profile() ? dm_profile()->alloc_big_align : dm_compiled_alloc_big_align)
#endif

#ifdef DM_GAME_FPS_TARGET
static const int dm_compiled_fps_target __attribute__((unused)) = DM_GAME_FPS_TARGET;
#undef DM_GAME_FPS_TARGET
#define DM_GAME_FPS_TARGET (dm_profile() ? dm_profile()->fps_target : dm_compiled_fps_target)
#endif

#ifdef DM_GAME_FPS_MAX
static const int dm_compiled_fps_max __attribute__((unused)) = DM_GAME_FPS_MAX;
#undef DM_GAME_FPS_MAX
#define DM_GAME_FPS_MAX (dm_profile() ? dm_profile()->fps_max : dm_compiled_fps_max)
#endif

#ifdef DM_GAME_FPS_HOLD
static const int dm_compiled_fps_hold __attribute__((unused)) = DM_GAME_FPS_HOLD;
#undef DM_GAME_FPS_HOLD
#define DM_GAME_FPS_HOLD (dm_profile() ? dm_profile()->fps_hold : dm_compiled_fps_hold)
#endif

#ifdef DM_GAME_UE_TEXTURE_POOL
static const int dm_compiled_ue_texture_pool __attribute__((unused)) = DM_GAME_UE_TEXTURE_POOL;
#undef DM_GAME_UE_TEXTURE_POOL
#define DM_GAME_UE_TEXTURE_POOL (dm_profile() ? dm_profile()->ue_texture_pool : dm_compiled_ue_texture_pool)
#endif

#ifdef DM_GAME_UE_FPS_CVAR
static const char *const dm_compiled_ue_fps_cvar __attribute__((unused)) = DM_GAME_UE_FPS_CVAR;
#undef DM_GAME_UE_FPS_CVAR
#define DM_GAME_UE_FPS_CVAR (dm_profile() ? dm_profile()->ue_fps_cvar : dm_compiled_ue_fps_cvar)
#endif

#ifdef DM_GAME_PRESENT_SNAP
static const int dm_compiled_present_snap __attribute__((unused)) = DM_GAME_PRESENT_SNAP;
#undef DM_GAME_PRESENT_SNAP
#define DM_GAME_PRESENT_SNAP (dm_profile() ? dm_profile()->present_snap : dm_compiled_present_snap)
#endif

#ifdef DM_GAME_PSO_MTL4
static const int dm_compiled_pso_mtl4 __attribute__((unused)) = DM_GAME_PSO_MTL4;
#undef DM_GAME_PSO_MTL4
#define DM_GAME_PSO_MTL4 (dm_profile() ? dm_profile()->pso_mtl4 : dm_compiled_pso_mtl4)
#endif

#ifdef DM_GAME_ENC_THREAD
static const int dm_compiled_enc_thread __attribute__((unused)) = DM_GAME_ENC_THREAD;
#undef DM_GAME_ENC_THREAD
#define DM_GAME_ENC_THREAD (dm_profile() ? dm_profile()->enc_thread : dm_compiled_enc_thread)
#endif

#ifdef DM_GAME_PAD_LAYOUT
static const int dm_compiled_pad_layout __attribute__((unused)) = DM_GAME_PAD_LAYOUT;
#undef DM_GAME_PAD_LAYOUT
#define DM_GAME_PAD_LAYOUT (dm_profile() ? dm_profile()->pad_layout : dm_compiled_pad_layout)
#endif

#ifdef DM_GAME_OPMODE
static const int dm_compiled_opmode __attribute__((unused)) = DM_GAME_OPMODE;
#undef DM_GAME_OPMODE
#define DM_GAME_OPMODE (dm_profile() ? dm_profile()->opmode : dm_compiled_opmode)
#endif

#ifdef DM_GAME_PERF_BOOST
static const int dm_compiled_perf_boost __attribute__((unused)) = DM_GAME_PERF_BOOST;
#undef DM_GAME_PERF_BOOST
#define DM_GAME_PERF_BOOST (dm_profile() ? dm_profile()->perf_boost : dm_compiled_perf_boost)
#endif

#ifdef DM_GAME_TEX_FLUSH_UPLOAD
static const int dm_compiled_tex_flush_upload __attribute__((unused)) = DM_GAME_TEX_FLUSH_UPLOAD;
#undef DM_GAME_TEX_FLUSH_UPLOAD
#define DM_GAME_TEX_FLUSH_UPLOAD (dm_profile() ? dm_profile()->tex_flush_upload : dm_compiled_tex_flush_upload)
#endif

#ifdef DM_GAME_SHADER_KEY_SKIP_OFF
static const int dm_compiled_shader_key_skip_off __attribute__((unused)) = DM_GAME_SHADER_KEY_SKIP_OFF;
#undef DM_GAME_SHADER_KEY_SKIP_OFF
#define DM_GAME_SHADER_KEY_SKIP_OFF (dm_profile() ? dm_profile()->shader_key_skip_off : dm_compiled_shader_key_skip_off)
#endif

#ifdef DM_GAME_SHADER_KEY_SKIP_LEN
static const int dm_compiled_shader_key_skip_len __attribute__((unused)) = DM_GAME_SHADER_KEY_SKIP_LEN;
#undef DM_GAME_SHADER_KEY_SKIP_LEN
#define DM_GAME_SHADER_KEY_SKIP_LEN (dm_profile() ? dm_profile()->shader_key_skip_len : dm_compiled_shader_key_skip_len)
#endif

#ifdef DM_GAME_RENDER_COND
static const int dm_compiled_render_cond __attribute__((unused)) = DM_GAME_RENDER_COND;
#undef DM_GAME_RENDER_COND
#define DM_GAME_RENDER_COND (dm_profile() ? dm_profile()->render_cond : dm_compiled_render_cond)
#endif

#ifdef DM_GAME_TEX_DIRTY_UPLOAD
static const int dm_compiled_tex_dirty_upload __attribute__((unused)) = DM_GAME_TEX_DIRTY_UPLOAD;
#undef DM_GAME_TEX_DIRTY_UPLOAD
#define DM_GAME_TEX_DIRTY_UPLOAD (dm_profile() ? dm_profile()->tex_dirty_upload : dm_compiled_tex_dirty_upload)
#endif

#ifdef DM_GAME_TEX_DYN_SLOTS
static const int dm_compiled_tex_dyn_slots __attribute__((unused)) = DM_GAME_TEX_DYN_SLOTS;
#undef DM_GAME_TEX_DYN_SLOTS
#define DM_GAME_TEX_DYN_SLOTS (dm_profile() ? dm_profile()->tex_dyn_slots : dm_compiled_tex_dyn_slots)
#endif

#ifdef DM_GAME_GPU_TS_SEGMENT
static const int dm_compiled_gpu_ts_segment __attribute__((unused)) = DM_GAME_GPU_TS_SEGMENT;
#undef DM_GAME_GPU_TS_SEGMENT
#define DM_GAME_GPU_TS_SEGMENT (dm_profile() ? dm_profile()->gpu_ts_segment : dm_compiled_gpu_ts_segment)
#endif

#ifdef DM_GAME_UPSCALER_KEYS
static const char *const dm_compiled_upscaler_keys __attribute__((unused)) = DM_GAME_UPSCALER_KEYS;
#undef DM_GAME_UPSCALER_KEYS
#define DM_GAME_UPSCALER_KEYS (dm_profile() ? dm_profile()->upscaler_keys : dm_compiled_upscaler_keys)
#endif

#ifdef DM_GAME_UPSCALER_N
static const int dm_compiled_upscaler_n __attribute__((unused)) = DM_GAME_UPSCALER_N;
#undef DM_GAME_UPSCALER_N
#define DM_GAME_UPSCALER_N (dm_profile() ? dm_profile()->upscaler_n : dm_compiled_upscaler_n)
#endif

#ifdef DM_GAME_VCONV_RANGE
static const int dm_compiled_vconv_range __attribute__((unused)) = DM_GAME_VCONV_RANGE;
#undef DM_GAME_VCONV_RANGE
#define DM_GAME_VCONV_RANGE (dm_profile() ? dm_profile()->vconv_range : dm_compiled_vconv_range)
#endif

#endif /* !DM_GAME_MULTI */
