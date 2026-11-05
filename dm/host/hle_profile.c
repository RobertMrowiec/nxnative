// Runtime game profile loader (DM_PROFILE -> <framework>/profile.tsv).
// Reads KEY<TAB>VALUE lines written by dm/games/game.py profile once per process.
#define DM_HLE_PROFILE_IMPL 1
#include "dm.h"
#include "hle_profile.h"
#include <ctype.h>
#include <pthread.h>
#include <stdatomic.h>

static pthread_once_t g_prof_once = PTHREAD_ONCE_INIT;
static dm_profile_t g_prof;
static const dm_profile_t *g_prof_active;
static _Atomic int g_prof_ready;

static int parse_flag(const char *v) {
    if (!strcmp(v, "on") || !strcmp(v, "true")) return 1;
    if (!strcmp(v, "off") || !strcmp(v, "false")) return 0;
    return (int)strtol(v, NULL, 0);
}

static uint64_t parse_u64_hex_or_auto(const char *v, int default_hex) {
    while (*v && isspace((unsigned char)*v)) v++;
    if (!strncmp(v, "0x", 2) || !strncmp(v, "0X", 2)) return strtoull(v, NULL, 16);
    return strtoull(v, NULL, default_hex ? 16 : 0);
}

static void count_upscalers(dm_profile_t *p) {
    p->upscaler_n = 0;
    for (const char *k = p->upscaler_keys; *k; ) {
        size_t n = 0;
        while (k[n] && k[n] != ',') n++;
        if (n >= 16) p->upscaler_n++;
        k += k[n] == ',' ? n + 1 : n;
    }
}

static void set_kv(dm_profile_t *p, const char *key, const char *val) {
    if (!strcmp(key, "title_id") || !strcmp(key, "id")) {
        strlcpy(p->id, val, sizeof p->id);
        if (!p->program_id) p->program_id = parse_u64_hex_or_auto(val, 1);
    } else if (!strcmp(key, "program_id")) {
        p->program_id = parse_u64_hex_or_auto(val, 1);
    } else if (!strcmp(key, "name")) {
        strlcpy(p->name, val, sizeof p->name);
    } else if (!strcmp(key, "romfs_marker")) {
        strlcpy(p->romfs_marker, val, sizeof p->romfs_marker);
    } else if (!strcmp(key, "modules")) {
        strlcpy(p->modules_buf, val, sizeof p->modules_buf);
        p->nmod = 0;
        char *save = NULL;
        for (char *tok = strtok_r(p->modules_buf, " \t", &save); tok && p->nmod < 31; tok = strtok_r(NULL, " \t", &save))
            p->modules[p->nmod++] = tok;
        p->modules[p->nmod] = NULL;
    } else if (!strcmp(key, "mem_reserve")) {
        p->mem_reserve = parse_u64_hex_or_auto(val, 0);
    } else if (!strcmp(key, "mem_alias")) {
        p->mem_alias = parse_u64_hex_or_auto(val, 0);
    } else if (!strcmp(key, "mem_stack")) {
        p->mem_stack = parse_u64_hex_or_auto(val, 0);
    } else if (!strcmp(key, "app_pool")) {
        p->app_pool = parse_u64_hex_or_auto(val, 0);
    } else if (!strcmp(key, "mem_used")) {
        p->mem_used = parse_u64_hex_or_auto(val, 0);
    } else if (!strcmp(key, "sys_resource")) {
        p->sys_resource = parse_u64_hex_or_auto(val, 0);
    } else if (!strcmp(key, "stdalloc_cap")) {
        p->stdalloc_cap = parse_u64_hex_or_auto(val, 0);
    } else if (!strcmp(key, "mem_map_limit")) {
        p->mem_map_limit = parse_flag(val);
    } else if (!strcmp(key, "screen_aspect")) {
        p->screen_aspect = parse_flag(val);
    } else if (!strcmp(key, "present_interval")) {
        p->present_display = !strcmp(val, "display") ? 1 : !strcmp(val, "game") ? 0 : parse_flag(val);
    } else if (!strcmp(key, "core_preempt")) {
        p->core_preempt = parse_flag(val);
    } else if (!strcmp(key, "alloc_big_align")) {
        p->alloc_big_align = parse_flag(val);
    } else if (!strcmp(key, "fps_target")) {
        p->fps_target = (int)strtol(val, NULL, 0);
    } else if (!strcmp(key, "fps_max")) {
        p->fps_max = (int)strtol(val, NULL, 0);
    } else if (!strcmp(key, "fps_hold")) {
        p->fps_hold = parse_flag(val);
    } else if (!strcmp(key, "ue_texture_pool")) {
        p->ue_texture_pool = (int)strtol(val, NULL, 0);
    } else if (!strcmp(key, "ue_fps_cvar")) {
        if (*val) strlcpy(p->ue_fps_cvar, val, sizeof p->ue_fps_cvar);
    } else if (!strcmp(key, "present_snap")) {
        p->present_snap = parse_flag(val);
    } else if (!strcmp(key, "pso_mtl4")) {
        p->pso_mtl4 = parse_flag(val);
    } else if (!strcmp(key, "enc_thread")) {
        p->enc_thread = parse_flag(val);
    } else if (!strcmp(key, "shared_font")) {
        p->shared_font_ttf = !strcmp(val, "ttf") ? 1 : !strcmp(val, "bfttf") ? 0 : parse_flag(val);
    } else if (!strcmp(key, "pad_layout")) {
        p->pad_layout = !strcmp(val, "simple") ? 0 : !strcmp(val, "full") ? 1 : !strcmp(val, "touch") ? 2 : (int)strtol(val, NULL, 0);
    } else if (!strcmp(key, "op_mode")) {
        p->opmode = !strcmp(val, "console") ? 1 : !strcmp(val, "handheld") ? 0 : parse_flag(val);
    } else if (!strcmp(key, "perf_mode")) {
        p->perf_boost = !strcmp(val, "boost") ? 1 : !strcmp(val, "follow") ? 0 : parse_flag(val);
    } else if (!strcmp(key, "tex_flush_upload")) {
        p->tex_flush_upload = parse_flag(val);
    } else if (!strcmp(key, "shader_key_skip_off")) {
        p->shader_key_skip_off = (int)strtol(val, NULL, 0);
    } else if (!strcmp(key, "shader_key_skip_len")) {
        p->shader_key_skip_len = (int)strtol(val, NULL, 0);
    } else if (!strcmp(key, "shader_key_skip")) {
        const char *plus = strchr(val, '+');
        if (plus) {
            p->shader_key_skip_off = (int)strtol(val, NULL, 0);
            p->shader_key_skip_len = (int)strtol(plus + 1, NULL, 0);
        }
    } else if (!strcmp(key, "render_cond")) {
        p->render_cond = parse_flag(val);
    } else if (!strcmp(key, "tex_dirty_upload")) {
        p->tex_dirty_upload = parse_flag(val);
    } else if (!strcmp(key, "tex_dyn_slots")) {
        p->tex_dyn_slots = parse_flag(val);
    } else if (!strcmp(key, "gpu_timestamps")) {
        p->gpu_ts_segment = !strcmp(val, "segment") ? 1 : !strcmp(val, "submission") ? 0 : parse_flag(val);
    } else if (!strcmp(key, "upscaler_keys")) {
        strlcpy(p->upscaler_keys, val, sizeof p->upscaler_keys);
        count_upscalers(p);
    } else if (!strcmp(key, "vconv_range")) {
        p->vconv_range = parse_flag(val);
    } else if (!strcmp(key, "launch_param")) {
        strlcpy(p->launch_param, val, sizeof p->launch_param);
    } else if (!strcmp(key, "game_args")) {
        strlcpy(p->args, val, sizeof p->args);
    } else if (!strcmp(key, "game_env")) {
        strlcpy(p->env, val, sizeof p->env);
    } else if (!strcmp(key, "device_api")) {
        int maj = 0, min = 0;
        if (sscanf(val, "%d.%d", &maj, &min) == 2) {
            p->has_device_api = 1;
            p->nvn_api_major = maj;
            p->nvn_api_minor = min;
        }
    } else if (!strcmp(key, "display_version")) {
        if (p->n_display_versions < 32) {
            const char *tab = strchr(val, '\t');
            if (tab) {
                size_t blen = (size_t)(tab - val);
                if (blen >= sizeof p->display_versions[0].build) blen = sizeof p->display_versions[0].build - 1;
                memcpy(p->display_versions[p->n_display_versions].build, val, blen);
                p->display_versions[p->n_display_versions].build[blen] = '\0';
                strlcpy(p->display_versions[p->n_display_versions].ver, tab + 1, sizeof p->display_versions[0].ver);
                p->n_display_versions++;
            }
        }
    }
}

static void init_runtime_profile(void) {
    const char *path = getenv("DM_PROFILE");
    if (!path || !*path) return;

    FILE *f = fopen(path, "r");
    if (!f) {
        LOG("[RED] DM_PROFILE=%s could not be opened; keeping compiled game profile", path);
        return;
    }

    // Neutral schema defaults matching dm/games/game.py header_one so no constant leaks from another game's compiled header.
    memset(&g_prof, 0, sizeof g_prof);
    g_prof.mem_reserve = 0x100000000ULL;
    g_prof.mem_alias = 0x10000000ULL;
    g_prof.mem_stack = 0x10000000ULL;
    g_prof.app_pool = 0xcd500000ULL;
    g_prof.mem_used = 0x4000000ULL;
    g_prof.sys_resource = 0x2000000ULL;
    g_prof.fps_max = 60;
    g_prof.fps_hold = 1;
    strlcpy(g_prof.ue_fps_cvar, "t.MaxFPS", sizeof g_prof.ue_fps_cvar);
    g_prof.shared_font_ttf = -1;
    g_prof.opmode = 1;

    char line[2048];
    while (fgets(line, sizeof line, f)) {
        size_t len = strlen(line);
        while (len > 0 && (line[len - 1] == '\n' || line[len - 1] == '\r')) line[--len] = '\0';
        char *s = line;
        while (*s == ' ' || *s == '\t') s++;
        if (!*s || *s == '#') continue;
        char *tab = strchr(s, '\t');
        if (!tab) continue;
        *tab = '\0';
        set_kv(&g_prof, s, tab + 1);
    }
    fclose(f);

    if (!g_prof.id[0]) {
        LOG("[RED] DM_PROFILE=%s has no title_id; keeping compiled game profile", path);
        return;
    }
    g_prof_active = &g_prof;
    LOG("runtime profile: %s (%s) from %s (reserve=%#llx alias=%#llx pool=%#llx map_limit=%d)",
        g_prof.id, g_prof.name[0] ? g_prof.name : "unnamed", path,
        (unsigned long long)g_prof.mem_reserve, (unsigned long long)g_prof.mem_alias,
        (unsigned long long)g_prof.app_pool, g_prof.mem_map_limit);
}

const dm_profile_t *dm_profile(void) {
    if (__builtin_expect(atomic_load_explicit(&g_prof_ready, memory_order_acquire), 1)) return g_prof_active;
    pthread_once(&g_prof_once, init_runtime_profile);
    atomic_store_explicit(&g_prof_ready, 1, memory_order_release);
    return g_prof_active;
}
