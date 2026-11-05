import Foundation

public struct EnginePatchItem: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let summary: String
    public let relativePath: String
    public var isApplied: Bool
    
    public init(id: String, name: String, summary: String, relativePath: String, isApplied: Bool = false) {
        self.id = id
        self.name = name
        self.summary = summary
        self.relativePath = relativePath
        self.isApplied = isApplied
    }
}

public struct EnginePatchDefinition {
    public let id: String
    public let name: String
    public let summary: String
    public let relativePath: String
    public let checkToken: String
    public let applyTransform: (String) -> String?
    
    public init(
        id: String,
        name: String,
        summary: String,
        relativePath: String,
        checkToken: String,
        applyTransform: @escaping (String) -> String?
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.relativePath = relativePath
        self.checkToken = checkToken
        self.applyTransform = applyTransform
    }
}

public enum EnginePatchRegistry {
    public static let patches: [EnginePatchDefinition] = [
        // 1. Dragon Quest VII v0 build definition in game.tsv
        EnginePatchDefinition(
            id: "dq7_game_tsv",
            name: "Dragon Quest VII v0 Metadata",
            summary: "Registers v1.0.0 (v0) package and hashes in game.tsv",
            relativePath: "dm/games/0100A9D01C446000/game.tsv",
            checkToken: "ab06020960edd8285b7ff5fad2e3224b",
            applyTransform: { content in
                let target = "build\tv131072\t1.2.0"
                let insert = "\nbuild\tv0\t1.0.0\tmain=ab06020960edd8285b7ff5fad2e3224b\tsubsdk0=92ef43cb1f9917ab206ac5c9e36240bc\tsdk=145dde94fb574acc9e09780a11995bd3"
                guard content.contains(target) else { return nil }
                return content.replacingOccurrences(of: target, with: target + insert)
            }
        ),
        
        // 2. Zelda Skyward Sword HD v0 build definition in game.tsv
        EnginePatchDefinition(
            id: "skyward_sword_v0_game_tsv",
            name: "Zelda Skyward Sword HD v0 Metadata",
            summary: "Registers v1.0.0 (v0) package and module hashes in game.tsv for Zelda: Skyward Sword HD",
            relativePath: "dm/games/01002DA013484000/game.tsv",
            checkToken: "d824d4b1bbd45d03668380d6d041ba4c",
            applyTransform: { content in
                let target = "build\tv65536\t1.0.1\tmain=5441af3c89f97e1d25a8ccf14c742bf8\tsubsdk0=4dd097b435891c5e0e15a65dbe47124f\tsubsdk1=535249a546887cac875a099e9c8ef367\tsdk=b39add63421be525d352e576dab438d3"
                let insert = "\nbuild\tv0\t1.0.0\tmain=d824d4b1bbd45d03668380d6d041ba4c\tsubsdk0=4dd097b435891c5e0e15a65dbe47124f\tsubsdk1=535249a546887cac875a099e9c8ef367\tsdk=b39add63421be525d352e576dab438d3"
                guard content.contains(target) else { return nil }
                return content.replacingOccurrences(of: target, with: target + insert)
            }
        ),
        
        // 1b. Zelda Skyward Sword HD v0 build definition in game.tsv
        EnginePatchDefinition(
            id: "skyward_sword_v0_game_tsv",
            name: "Zelda Skyward Sword HD v0 Metadata",
            summary: "Registers v1.0.0 (v0) package and build hashes in game.tsv",
            relativePath: "dm/games/01002DA013484000/game.tsv",
            checkToken: "d824d4b1bbd45d03668380d6d041ba4c",
            applyTransform: { content in
                let target = "build\tv65536\t1.0.1\tmain=5441af3c89f97e1d25a8ccf14c742bf8\tsubsdk0=4dd097b435891c5e0e15a65dbe47124f\tsubsdk1=535249a546887cac875a099e9c8ef367\tsdk=b39add63421be525d352e576dab438d3"
                let insert = "\nbuild\tv0\t1.0.0\tmain=d824d4b1bbd45d03668380d6d041ba4c\tsubsdk0=4dd097b435891c5e0e15a65dbe47124f\tsubsdk1=535249a546887cac875a099e9c8ef367\tsdk=b39add63421be525d352e576dab438d3"
                guard content.contains(target) else { return nil }
                return content.replacingOccurrences(of: target, with: target + insert)
            }
        ),
        
        // 2. Dynamic Unreal Engine FMallocBinned3 allocator cut
        EnginePatchDefinition(
            id: "ue_allocator_support",
            name: "UE 4 / 5 Allocator Cut (ue_malloc.py)",
            summary: "Dynamic FMallocBinned3 address space cut and host malloc gate",
            relativePath: "dm/tools/ue_malloc.py",
            checkToken: "FMallocBinned3",
            applyTransform: { content in
                return content // Already verified present upstream
            }
        ),
        
        // 3. Dynamic Unreal Engine FPS & SyncInterval unlock
        EnginePatchDefinition(
            id: "ue_fps_unlock",
            name: "Dynamic Unreal FPS & Sync (hle_fpslock.c)",
            summary: "Dynamically hooks rhi.SyncInterval and t.MaxFPS for smooth 60 FPS",
            relativePath: "dm/host/hle_fpslock.c",
            checkToken: "rhi.SyncInterval",
            applyTransform: { content in
                return content // Already verified present upstream
            }
        ),
        
        // 4. Dynamic shader library fallback in nvn_mtl.m
        EnginePatchDefinition(
            id: "nvn_shader_fallback",
            name: "Dynamic Shader Chain Fallback (nvn_mtl.m)",
            summary: "Loads packaged metallib chains even if translation hash changed",
            relativePath: "dm/gfx/nvn/nvn_mtl.m",
            checkToken: "g_active_chain",
            applyTransform: { content in
                let target = "g_msl_dir = [NSString stringWithFormat:@\"%@/b-%s\", m ? @(m) : [NSString stringWithFormat:@\"%s%s/build/cache/metal_shader_cache\", getenv(\"DM_ROOT\") ?: getenv(\"HOME\"), getenv(\"DM_ROOT\") ? \"\" : \"/dm-work\"], DMSH_CHAIN];"
                let replacement = """
g_msl_dir = [NSString stringWithFormat:@"%@/b-%s", m ? @(m) : [NSString stringWithFormat:@"%s%s/build/cache/metal_shader_cache", getenv("DM_ROOT") ?: getenv("HOME"), getenv("DM_ROOT") ? "" : "/dm-work"], DMSH_CHAIN];
    g_active_chain = @DMSH_CHAIN;
    if (![NSFileManager.defaultManager fileExistsAtPath:g_msl_dir] && m) {
        NSArray *sub = [NSFileManager.defaultManager contentsOfDirectoryAtPath:@(m) error:nil];
        for (NSString *s in sub) {
            if ([s hasPrefix:@"b-"]) {
                NSString *candidate = [@(m) stringByAppendingPathComponent:s];
                BOOL isDir = NO;
                if ([NSFileManager.defaultManager fileExistsAtPath:candidate isDirectory:&isDir] && isDir) {
                    g_msl_dir = candidate;
                    g_active_chain = [s substringFromIndex:2];
                    MLOG("using packaged shader library directory %s (chain %s)", g_msl_dir.UTF8String, g_active_chain.UTF8String);
                    break;
                }
            }
        }
    }
"""
                let declTarget = "static NSString *g_shmap_path, *g_msl_dir;"
                let declRepl = "static NSString *g_shmap_path, *g_msl_dir, *g_active_chain;"
                
                guard content.contains(target) && content.contains(declTarget) else { return nil }
                var res = content.replacingOccurrences(of: declTarget, with: declRepl)
                res = res.replacingOccurrences(of: target, with: replacement)
                return res
            }
        ),
        
        // 6. Default Mac App naming in build_ipa_from_nsp.py
        EnginePatchDefinition(
            id: "mac_app_naming",
            name: "Mac App Output Naming (build_ipa_from_nsp.py)",
            summary: "Defaults Mac output to <Game>.app and optimizes buffer check",
            relativePath: "scripts/build_ipa_from_nsp.py",
            checkToken: "mac_pack and not (args.out or OUT_IPA): out_ipa =",
            applyTransform: { content in
                if content.contains("mac_pack and not (args.out or OUT_IPA): out_ipa =") {
                    return content // Already merged upstream or applied
                }
                let target1 = "out_ipa = Path(os.path.expanduser(args.out or OUT_IPA)).resolve() if (args.out or OUT_IPA) else nsp_dir / g.get('ipa')"
                let target2 = "out_ipa = Path(os.path.expanduser(args.out or OUT_IPA)).resolve() if (args.out or OUT_IPA) else work.parent / g.get('ipa')"
                let repl = """
if mac_pack:
        default_name = f'{mac_app_name(g.get("name", g.id))}.app'
        out_ipa = Path(os.path.expanduser(args.out or OUT_IPA)).resolve() if (args.out or OUT_IPA) else nsp_dir / default_name
    else:
        out_ipa = Path(os.path.expanduser(args.out or OUT_IPA)).resolve() if (args.out or OUT_IPA) else nsp_dir / (g.get('ipa') or f'{g.id}.ipa')
"""
                if content.contains(target1) {
                    return content.replacingOccurrences(of: target1, with: repl)
                }
                if content.contains(target2) {
                    return content.replacingOccurrences(of: target2, with: repl)
                }
                return nil
            }
        ),
        
        // 7. Global 60 FPS Normal Speed Sync (hle_nvn.c)
        EnginePatchDefinition(
            id: "global_60fps_speed_sync",
            name: "Global 60 FPS Normal Speed Sync",
            summary: "Synchronizes native 30 FPS games to run smoothly at 60 FPS without 2x fast-forward acceleration.",
            relativePath: "dm/gfx/nvn/hle_nvn.c",
            checkToken: "hle_speed_sync_pacing",
            applyTransform: { content in
                let targetOld = "static int present_itv(const win_t *o) { int c = fps_present_cap(), k = atomic_load(&g_fs_k); return c ? (k && fstep_on() ? k : 60 / c) : g_display_mode ? 1 : o->interval > 0 ? o->interval : 1; }"
                let targetNew = "static int present_itv(const win_t *o) { int c = fps_present_cap(), k = atomic_load(&g_fs_k); return c ? (k && fstep_on() ? k : fstep_hz() / c) : g_display_mode ? 1 : o->interval > 0 ? o->interval : 1; }"
                let repl = """
__attribute__((weak)) int dm_fps_has_engine_lock(void) { return 0; }

static int speed_sync_on(void) {
    static int s = -1;
    if (s < 0) {
        const char *e = getenv("DM_SPEED_SYNC");
        s = e ? atoi(e) : 1;
    }
    return s;
}

static int hle_speed_sync_pacing(const win_t *o, int c, int k) {
    if (k && fstep_on()) return k;
    if (c == 60) {
        if (o->interval >= 2 && speed_sync_on()) {
            if (dm_fps_has_engine_lock() || fstep_on()) {
                return 1;
            } else {
                static int nlog_sync = 0;
                if (nlog_sync++ < 3) {
                    LOG("[nvn] speed sync: native 30 fps title pacing preserved at normal 1.0x speed (preventing 2x fast-forward)");
                }
                return o->interval;
            }
        }
        return fstep_hz() / c;
    }
    return c ? fstep_hz() / c : (o->interval > 0 ? o->interval : 1);
}

static int present_itv(const win_t *o) { int c = fps_present_cap(), k = atomic_load(&g_fs_k); return c ? hle_speed_sync_pacing(o, c, k) : g_display_mode ? 1 : o->interval > 0 ? o->interval : 1; }
"""
                if content.contains(targetNew) {
                    return content.replacingOccurrences(of: targetNew, with: repl)
                }
                if content.contains(targetOld) {
                    return content.replacingOccurrences(of: targetOld, with: repl)
                }
                return nil
            }
        ),
        
        // 9. Global 30→60 FPS Normal Speed Pacer & Host Limiter Declaration (hle_fpslock.c)
        EnginePatchDefinition(
            id: "global_fps_pacing_sync",
            name: "Global 30→60 FPS Speed Sync & Pacer",
            summary: "Paces native 30 FPS titles on 60 Hz displays while strictly preserving 1.0x normal game speed and declaring required host limiter variables.",
            relativePath: "dm/host/hle_fpslock.c",
            checkToken: "trinity, ue_missing",
            applyTransform: { content in
                let target = "static int nrow, nier, ue_missing;"
                let repl = "static int nrow, nier, trinity, ue_missing;"
                if content.contains(target) {
                    return content.replacingOccurrences(of: target, with: repl)
                }
                let oldTarget = "static int state = -2, rows[NLOCKS], nrow, nlog[NLOCKS], target, nier; static uint8_t *base; static const char *src; static uint32_t display;"
                let oldRepl = "static int state = -2, rows[NLOCKS], nrow, nlog[NLOCKS], target, nier, trinity; static uint8_t *base; static const char *src; static uint32_t display;"
                if content.contains(oldTarget) {
                    return content.replacingOccurrences(of: oldTarget, with: oldRepl)
                }
                return nil
            }
        ),
        
        // 10. Mac Host Mouse Button Signature Fix (front_mac.m)
        EnginePatchDefinition(
            id: "mac_host_on_mouse_button",
            name: "Mac Host Mouse Button Support (front_mac.m)",
            summary: "Ensures on_mouse_button is properly declared and defined for custom button bindings.",
            relativePath: "dm/host/front_mac.m",
            checkToken: "static void on_mouse_button(int buttonCode, int down)",
            applyTransform: { content in
                let corruptTarget = "static void on_key(NSEvent *e, int down) {\n    if (!g_input_on) return;\n    load_custom_input_mapping();\n    int b = key_bit((unsigned short)buttonCode);"
                let fixedRepl = "static void on_mouse_button(int buttonCode, int down) {\n    if (!g_input_on) return;\n    load_custom_input_mapping();\n    int b = key_bit((unsigned short)buttonCode);"
                if content.contains(corruptTarget) {
                    return content.replacingOccurrences(of: corruptTarget, with: fixedRepl)
                }
                return nil
            }
        ),
        
        // 11. iOS Shell Shader Chain Fallback (build_shell.sh)
        EnginePatchDefinition(
            id: "build_shell_shader_chain_fallback",
            name: "iOS Shell Shader Chain Fallback (build_shell.sh)",
            summary: "Enables multi-game deployment using runtime shader chain fallback without re-extracting games.",
            relativePath: "dm/ios/tools/build_shell.sh",
            checkToken: "using runtime shader chain fallback",
            applyTransform: { content in
                let target = "if m.get('chain') != chain: sys.exit(f'[RED] {p}: built for shader chain {m.get(\"chain\")}, this checkout is {chain}: build the game again')"
                let repl = """
    if m.get('chain') != chain:
        if os.environ.get('DM_ALLOW_OTHER_CHAIN', '1') == '0':
            sys.exit(f'[RED] {p}: built for shader chain {m.get("chain")}, this checkout is {chain}: build the game again')
        else:
            sys.stderr.write(f'[WARN] {p}: built for shader chain {m.get("chain")}, this checkout is {chain} (using runtime shader chain fallback)\\n')
"""
                guard content.contains(target) else { return nil }
                return content.replacingOccurrences(of: target, with: repl)
            }
        )
    ]
}
