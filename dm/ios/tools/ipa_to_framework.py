#!/usr/bin/env python3
"""Convert an already-ported NxNative / DmIOS .ipa directly into a Route C DmGame<TitleID>.framework.

Works with zero NSPs, zero prod.keys, and zero Metal shader recompilation:
- Layout 1 (Route C .ipa): extracts Payload/*.app/Frameworks/DmGame*.framework and adapts its name & manifest.
- Layout 2 (Standalone .ipa): extracts the 16 KB-aligned embedded guest module sections (__TEXT,__dm*, __DM*W,__img,
  __DATA,__dm_nro_tab) from Payload/*.app/<CFBundleExecutable> (DmIOS), links them with DmGameMarker.m into a native
  arm64 iOS dynamic library, moves dm/, msl/, pso/, generates Info.plist, profile.tsv, icon.png, and game.manifest.json,
  and atomically publishes <out>/DmGame<TitleID>.framework.
"""
import argparse
import json
import os
import plistlib
import re
import shutil
import struct
import subprocess
import sys
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
IOS_DIR = HERE.parent
DM_DIR = IOS_DIR.parent
REPO_DIR = DM_DIR.parent

MH_MAGIC_64 = 0xFEEDFACF
FAT_MAGIC = 0xCAFEBABE
FAT_CIGAM = 0xBEBAFECA
CPU_TYPE_ARM64 = 0x0100000C
LC_SEGMENT_64 = 0x19
S_ZEROFILL = 0x1
TITLE_ID_RE = re.compile(r'((?:0100|0400)[0-9A-Fa-f]{12})')


def load_order(m):
    return (m != 'rtld', m != 'main', m == 'sdk', int(m[6:]) if m.startswith('subsdk') and m[6:].isdigit() else 0, m)


def strip_apple_double(root):
    for dirpath, dirnames, filenames in os.walk(root):
        for fn in filenames:
            if fn.startswith('._') or fn == '.DS_Store':
                try:
                    os.unlink(os.path.join(dirpath, fn))
                except OSError:
                    pass
        for dn in list(dirnames):
            if dn.startswith('._'):
                shutil.rmtree(os.path.join(dirpath, dn), ignore_errors=True)
                dirnames.remove(dn)


def current_dmsh_chain():
    hdr = (DM_DIR / 'gfx/nvn/dmsh_chain.h').read_text(encoding='utf-8')
    m = re.search(r'^#define\s+DMSH_CHAIN\s+"([^"]+)"', hdr, re.M)
    if not m:
        raise SystemExit('[RED] ipa_to_framework: no DMSH_CHAIN in dm/gfx/nvn/dmsh_chain.h')
    return m.group(1)


def detect_macho_arm64_slice(data):
    if len(data) < 32:
        raise SystemExit('[RED] ipa_to_framework: executable is truncated')
    magic_be = struct.unpack_from('>I', data, 0)[0]
    magic_le = struct.unpack_from('<I', data, 0)[0]
    if magic_le == MH_MAGIC_64:
        return memoryview(data)
    if magic_be in (FAT_MAGIC, FAT_CIGAM):
        endian = '>' if magic_be == FAT_MAGIC else '<'
        nfat = struct.unpack_from(endian + 'I', data, 4)[0]
        off = 8
        for _ in range(nfat):
            cputype, _, slice_off, slice_sz, _ = struct.unpack_from(endian + 'iiIII', data, off)
            off += 20
            if cputype == CPU_TYPE_ARM64:
                return memoryview(data)[slice_off:slice_off + slice_sz]
        raise SystemExit('[RED] ipa_to_framework: fat binary has no arm64 slice')
    raise SystemExit(f'[RED] ipa_to_framework: unsupported Mach-O magic {magic_le:#x}')


def parse_dm_sections(macho):
    magic, cputype, _, _, ncmds, _, _, _ = struct.unpack_from('<IIIIIIII', macho, 0)
    if magic != MH_MAGIC_64 or cputype != CPU_TYPE_ARM64:
        raise SystemExit('[RED] ipa_to_framework: executable is not arm64 MH_MAGIC_64')
    sections = []
    off = 32
    for _ in range(ncmds):
        cmd, cmdsize = struct.unpack_from('<II', macho, off)
        if cmd == LC_SEGMENT_64:
            segname = bytes(macho[off + 8:off + 24]).split(b'\0', 1)[0].decode('ascii', errors='replace')
            nsects = struct.unpack_from('<I', macho, off + 64)[0]
            soff = off + 72
            for _ in range(nsects):
                sectname = bytes(macho[soff:soff + 16]).split(b'\0', 1)[0].decode('ascii', errors='replace')
                s_seg = bytes(macho[soff + 16:soff + 32]).split(b'\0', 1)[0].decode('ascii', errors='replace')
                _, size, file_off, align, _, _, flags = struct.unpack_from('<QQIIIII', macho, soff + 32)
                is_dm_text = (s_seg == '__TEXT' and sectname.startswith('__dm'))
                is_dm_rw = (s_seg.startswith('__DM') and s_seg.endswith('W') and sectname == '__img')
                is_nro_tab = (s_seg == '__DATA' and sectname.startswith('__dm') and sectname.endswith('_nro_tab'))
                if is_dm_text or is_dm_rw or is_nro_tab:
                    sections.append({
                        'segname': s_seg or segname,
                        'sectname': sectname,
                        'size': size,
                        'offset': file_off,
                        'align': max(align, 14) if (is_dm_text or is_dm_rw) else max(align, 3),
                        'is_page_piece': bool(is_dm_text or is_dm_rw),
                        'flags': flags,
                    })
                soff += 80
        off += cmdsize
    return sections


def discover_extra_games_dirs(ipa_path, title_id):
    dirs = []
    candidates = [
        ipa_path.parent / f'{title_id}_build/profile',
        Path('/Volumes/SSD FN501 PRO/Emulations/NativePort/Staging'),
        Path('/Volumes/Nintendo/Games'),
    ]
    for base in candidates:
        if not base.exists():
            continue
        if (base / title_id / 'game.tsv').is_file():
            dirs.append(str(base))
            continue
        try:
            for sub in base.iterdir():
                if sub.name.startswith('.'):
                    continue
                p1 = sub / f'{title_id}_build/profile'
                if (p1 / title_id / 'game.tsv').is_file():
                    dirs.append(str(p1))
                elif sub.is_dir():
                    try:
                        for sub2 in sub.iterdir():
                            if sub2.name.startswith('.'):
                                continue
                            p2 = sub2 / f'{title_id}_build/profile'
                            if (p2 / title_id / 'game.tsv').is_file():
                                dirs.append(str(p2))
                    except OSError:
                        pass
        except OSError:
            pass
    existing = [p for p in os.environ.get('DM_GAMES_DIR', '').split(':') if p]
    return ':'.join(dict.fromkeys(dirs + existing))


def synthesize_profile_tsv(out_tsv, title_id, name, modules, dm_dir, sections_data, display_version):
    ounce = False
    has_set_heap = False
    is_unreal = False
    for sec_info, raw in sections_data:
        if sec_info['segname'] == '__TEXT' and sec_info['sectname'] == '__dmsdkx0':
            if b'spec: Ounce' in raw:
                ounce = True
        elif sec_info['segname'] == '__TEXT' and sec_info['sectname'] == '__dmmainx0':
            if b'_ZN2nn2os17SetMemoryHeapSizeEm' in raw:
                has_set_heap = True
            if b'Unreal' in raw or b'UE4' in raw:
                is_unreal = True

    app_pool = 0x240000000 if ounce else 0xCD500000
    if is_unreal:
        mem_reserve, mem_alias, sys_res = 0x140000000, 0x110000000, 0x2000000
    elif not has_set_heap:
        mem_reserve, mem_alias, sys_res = 0x140000000, 0x118000000, 0x2000000
    else:
        mem_reserve, mem_alias, sys_res = 0x100000000, 0x10000000, 0x0

    total_img = 0
    main_bid = ''
    for m in modules:
        fix = dm_dir / f'{m}.fixups.tsv'
        if fix.is_file():
            txt = fix.read_text(encoding='utf-8', errors='replace')
            hdr = dict(re.findall(r'^# (\w+)\s+(\S+)', txt, re.M))
            if m == 'main' and 'BUILD_ID' in hdr:
                main_bid = hdr['BUILD_ID']
            if 'IMAGE_SIZE' in hdr:
                total_img += int(hdr['IMAGE_SIZE'], 16)
    if total_img == 0:
        for sec_info, _ in sections_data:
            total_img += sec_info['size']
    mem_used = max(0x4000000, ((total_img + 0x1FFFFF) & ~0x1FFFFF) + 0x400000)

    lines = [
        f'# Synthesized runtime game profile for {title_id} ({name}) from IPA',
        f'title_id\t{title_id}',
        f'program_id\t0x{title_id}',
        f'name\t{name}',
        'romfs_marker\t.',
        f'modules\t{" ".join(modules)}',
        f'mem_reserve\t{mem_reserve:#x}',
        f'mem_alias\t{mem_alias:#x}',
        'mem_stack\t0x10000000',
        f'app_pool\t{app_pool:#x}',
        f'mem_used\t{mem_used:#x}',
        f'sys_resource\t{sys_res:#x}',
        'stdalloc_cap\t0x0',
        'mem_map_limit\t0',
        'present_interval\t0',
        'core_preempt\t0',
        'alloc_big_align\t0',
        'fps_target\t0',
        'fps_max\t60',
        'fps_hold\t1',
        'present_snap\t0',
        'pso_mtl4\t0',
        'pad_layout\t0',
        'op_mode\t1',
        'perf_mode\t0',
        'tex_flush_upload\t0',
        'render_cond\t0',
        'tex_dirty_upload\t0',
        'tex_dyn_slots\t0',
        'gpu_timestamps\t0',
        'vconv_range\t0',
        'game_args\t',
        'game_env\t',
    ]
    if main_bid:
        lines.append(f'display_version\t{main_bid}\t{display_version}')
    out_tsv.write_text('\n'.join(lines) + '\n', encoding='utf-8')


def write_framework_info_plist(out_plist, fw_name, display_name, title_id, version, min_os):
    info = {
        'CFBundleDevelopmentRegion': 'en',
        'CFBundleDisplayName': display_name,
        'CFBundleExecutable': fw_name,
        'CFBundleIdentifier': f'org.nxnative.{title_id.lower()}.game',
        'CFBundleInfoDictionaryVersion': '6.0',
        'CFBundleName': fw_name,
        'CFBundlePackageType': 'FMWK',
        'CFBundleShortVersionString': version,
        'CFBundleSupportedPlatforms': ['iPhoneOS'],
        'CFBundleVersion': version,
        'MinimumOSVersion': min_os,
        'UIDeviceFamily': [1, 2],
        'UIRequiredDeviceCapabilities': ['arm64'],
    }
    out_plist.write_bytes(plistlib.dumps(info, fmt=plistlib.FMT_XML))


def pick_and_copy_icon(app_dir, title_id, out_icon):
    candidates = [
        app_dir / 'icon.png',
        app_dir / 'AppIcon76x76@2x~ipad.png',
        app_dir / 'AppIcon60x60@3x.png',
        app_dir / 'AppIcon60x60@2x.png',
    ]
    # Also check macOS ArtworkStore cache if available
    art_dir = Path.home() / 'Library/Application Support/NxNative/Artwork'
    for ext in ('png', 'jpg', 'jpeg'):
        p = art_dir / f'{title_id}.{ext}'
        if p.is_file():
            candidates.insert(0, p)

    for src in candidates:
        if src.is_file():
            r = subprocess.run(
                ['/usr/bin/sips', '-s', 'format', 'png', '-Z', '512', str(src), '--out', str(out_icon)],
                capture_output=True, text=True
            )
            if r.returncode == 0 and out_icon.is_file():
                return
            shutil.copy2(src, out_icon)
            return


def resolve_title_id(explicit_tid, launcher_json_path, info_plist, ipa_path):
    if explicit_tid and re.fullmatch(r'[0-9A-Fa-f]{16}', explicit_tid) and explicit_tid != '0100000000000000':
        return explicit_tid.upper()
    if launcher_json_path.is_file():
        try:
            lj = json.loads(launcher_json_path.read_text(encoding='utf-8'))
            g = str(lj.get('game', '')).strip().upper()
            if re.fullmatch(r'[0-9A-F]{16}', g):
                return g
        except (OSError, ValueError):
            pass
    dm_tid = str(info_plist.get('DMTitleID', '')).strip().upper()
    if re.fullmatch(r'[0-9A-F]{16}', dm_tid):
        return dm_tid
    for text in (str(info_plist.get('CFBundleIdentifier', '')), ipa_path.name):
        m = TITLE_ID_RE.search(text)
        if m:
            return m.group(1).upper()
    raise SystemExit(f'[RED] ipa_to_framework: cannot determine 16-hex Switch Title ID from {ipa_path}')


def convert_ipa(ipa_path, out_dir, explicit_tid=None, explicit_name=None):
    ipa_path = Path(ipa_path).resolve()
    out_dir = Path(out_dir).resolve()
    if not ipa_path.is_file():
        raise SystemExit(f'[RED] ipa_to_framework: IPA not found: {ipa_path}')
    out_dir.mkdir(parents=True, exist_ok=True)

    # Fast header scan to verify IPA structure before unpacking
    with zipfile.ZipFile(ipa_path, 'r') as zf:
        app_dirs = sorted({
            parts[1] for name in zf.namelist()
            for parts in [name.split('/')]
            if len(parts) >= 2 and parts[0] == 'Payload' and parts[1].endswith('.app')
        })
        if not app_dirs:
            raise SystemExit(f'[RED] ipa_to_framework: {ipa_path.name} has no Payload/*.app')
        app_rel = f'Payload/{app_dirs[0]}'

    stage_root = out_dir / f'.staging_ipa_{os.getpid()}'
    shutil.rmtree(stage_root, ignore_errors=True)
    extract_dir = stage_root / 'extract'
    extract_dir.mkdir(parents=True, exist_ok=True)

    try:
        # Unpack everything except multi-GB game data / fonts (native C unzip is ~10x faster on 50k+ metallib files)
        uz = subprocess.run([
            '/usr/bin/unzip', '-q', str(ipa_path),
            '-x',
            'Payload/*.app/romfs.img',
            'Payload/*.app/RomFS.img',
            'Payload/*.app/romfs/*',
            'Payload/*.app/aoc/*',
            'Payload/*.app/p0/romfs.img',
            'Payload/*.app/p1/romfs.img',
            'Payload/*.app/p2/romfs.img',
            'Payload/*.app/dm/font/*',
            '*/._*',
            '__MACOSX/*',
            '-d', str(extract_dir),
        ], capture_output=True, text=True)
        # unzip exit code 11 means one or more excluded patterns had no matches (harmless)
        if uz.returncode not in (0, 11):
            raise SystemExit(f'[RED] ipa_to_framework: unzip failed ({uz.returncode}): {uz.stderr.strip()}')

        app_dir = extract_dir / app_rel
        strip_apple_double(app_dir)

        info_path = app_dir / 'Info.plist'
        info = plistlib.loads(info_path.read_bytes()) if info_path.is_file() else {}

        # Case 1: Route C IPA already embeds Frameworks/DmGame*.framework
        fws_in_app = sorted((app_dir / 'Frameworks').glob('DmGame*.framework')) if (app_dir / 'Frameworks').is_dir() else []
        if fws_in_app:
            src_fw = fws_in_app[0]
            man_path = src_fw / 'game.manifest.json'
            man = json.loads(man_path.read_text(encoding='utf-8')) if man_path.is_file() else {}
            tid = resolve_title_id(explicit_tid or man.get('title_id'), src_fw / 'dm/launcher.json', info, ipa_path)
            fw_name = f'DmGame{tid}'
            fw_stage = stage_root / f'{fw_name}.framework'
            os.rename(src_fw, fw_stage)
            old_exe = man.get('framework_executable') or src_fw.stem
            if old_exe != fw_name and (fw_stage / old_exe).is_file():
                os.rename(fw_stage / old_exe, fw_stage / fw_name)
                subprocess.run([
                    '/usr/bin/xcrun', 'install_name_tool', '-id',
                    f'@rpath/{fw_name}.framework/{fw_name}', str(fw_stage / fw_name)
                ], capture_output=True)
            for extra in ('msl', 'pso'):
                if not (fw_stage / extra).is_dir() and (app_dir / extra).is_dir():
                    os.rename(app_dir / extra, fw_stage / extra)
            if not (fw_stage / 'icon.png').is_file():
                pick_and_copy_icon(app_dir, tid, fw_stage / 'icon.png')
            man['title_id'] = tid
            man['framework'] = f'{fw_name}.framework'
            man['framework_executable'] = fw_name
            (fw_stage / 'game.manifest.json').write_text(json.dumps(man, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
            write_framework_info_plist(
                fw_stage / 'Info.plist', fw_name,
                man.get('name') or explicit_name or ipa_path.stem,
                tid, man.get('display_version', '1.0.0'), man.get('min_os', '26.0')
            )
            final_fw = out_dir / f'{fw_name}.framework'
            shutil.rmtree(final_fw, ignore_errors=True)
            os.rename(fw_stage, final_fw)
            subprocess.run(['/usr/bin/xattr', '-cr', str(final_fw)], capture_output=True)
            print(final_fw)
            return final_fw

        # Case 2: Standard standalone IPA (Payload/DmIOS.app/DmIOS)
        dm_src = app_dir / 'dm'
        if not dm_src.is_dir():
            raise SystemExit(f'[RED] ipa_to_framework: {ipa_path.name} has no {app_rel}/dm directory')

        tid = resolve_title_id(explicit_tid, dm_src / 'launcher.json', info, ipa_path)
        fw_name = f'DmGame{tid}'
        display_name = (
            info.get('CFBundleDisplayName')
            or explicit_name
            or info.get('CFBundleName')
            or ipa_path.stem
        )
        if display_name == 'DmIOS' and explicit_name:
            display_name = explicit_name
        display_version = str(info.get('CFBundleShortVersionString') or info.get('CFBundleVersion') or '1.0.0')
        min_os = str(info.get('MinimumOSVersion') or '26.0')

        exe_name = str(info.get('CFBundleExecutable') or 'DmIOS')
        exe_path = app_dir / exe_name
        if not exe_path.is_file():
            raise SystemExit(f'[RED] ipa_to_framework: executable {exe_name} missing in {ipa_path.name}')

        exe_bytes = exe_path.read_bytes()
        macho = detect_macho_arm64_slice(exe_bytes)
        sections = parse_dm_sections(macho)
        if not any(s['segname'] == '__TEXT' and s['sectname'].startswith('__dm') and s['sectname'].endswith('x0') for s in sections):
            raise SystemExit(f'[RED] ipa_to_framework: {exe_name} has no embedded __TEXT,__dm*x0 sections')

        build_tmp = stage_root / 'link'
        build_tmp.mkdir(parents=True, exist_ok=True)
        fw_stage = stage_root / f'{fw_name}.framework'
        fw_stage.mkdir(parents=True, exist_ok=True)

        asm_lines = ['// Generated by ipa_to_framework.py from embedded Mach-O sections']
        rw_segments = []
        sections_for_profile = []

        for idx, s in enumerate(sections):
            seg, sect, sz, foff, align, flags = s['segname'], s['sectname'], s['size'], s['offset'], s['align'], s['flags']
            if seg.startswith('__DM') and seg.endswith('W') and seg not in rw_segments:
                rw_segments.append(seg)
            if sz == 0:
                continue
            if (flags & 0xFF) == S_ZEROFILL or foff == 0:
                asm_lines.append(f'.zerofill {seg},{sect},_dm_zf_{idx},{sz},{align}')
                continue
            avail = max(0, min(sz, len(macho) - foff))
            raw = bytes(macho[foff:foff + avail])
            if len(raw) < sz:
                raw += b'\0' * (sz - len(raw))
            bin_file = build_tmp / f'sec_{idx}.bin'
            bin_file.write_bytes(raw)
            if seg == '__TEXT' and sect in ('__dmmainx0', '__dmsdkx0'):
                sections_for_profile.append((s, raw))
            asm_lines += [
                f'.section {seg},{sect}',
                f'.p2align {align}',
                f'.incbin "{bin_file.as_posix()}"',
            ]
            if s.get('is_page_piece'):
                asm_lines.append('.p2align 14')

        # Release memory of original DmIOS binary before invoking clang
        del macho
        del exe_bytes

        embed_s = build_tmp / 'embed.S'
        embed_s.write_text('\n'.join(asm_lines) + '\n', encoding='utf-8')

        marker_m = DM_DIR / 'ios/framework/DmGameMarker.m'
        clang_cmd = [
            '/usr/bin/xcrun', '-sdk', 'iphoneos', 'clang',
            '-arch', 'arm64',
            f'-mios-version-min={min_os}',
            '-mcpu=apple-a18',
            '-fobjc-arc',
            '-dynamiclib',
            '-install_name', f'@rpath/{fw_name}.framework/{fw_name}',
        ]
        for seg in rw_segments:
            clang_cmd += [f'-Wl,-segprot,{seg},rw,rw']
        clang_cmd += [str(marker_m), str(embed_s), '-o', str(fw_stage / fw_name)]

        cl = subprocess.run(clang_cmd, capture_output=True, text=True)
        if cl.returncode != 0:
            raise SystemExit(f'[RED] ipa_to_framework: clang failed ({cl.returncode}): {cl.stderr.strip()}')
        os.chmod(fw_stage / fw_name, 0o755)

        # Move dm/, msl/, pso/ into framework stage
        shutil.rmtree(dm_src / 'font', ignore_errors=True)
        if (dm_src / 'env.txt').exists():
            (dm_src / 'env.txt').unlink()
        os.rename(dm_src, fw_stage / 'dm')

        if (app_dir / 'msl').is_dir():
            os.rename(app_dir / 'msl', fw_stage / 'msl')
        else:
            (fw_stage / 'msl').mkdir(parents=True, exist_ok=True)

        if (app_dir / 'pso').is_dir():
            os.rename(app_dir / 'pso', fw_stage / 'pso')

        # Ensure dm/launcher.json exists and its "game" matches tid (required by ShellHost GameCatalogue)
        lj_path = fw_stage / 'dm/launcher.json'
        lj_data = {'schema': 1, 'game': tid, 'settings': []}
        if lj_path.is_file():
            try:
                parsed = json.loads(lj_path.read_text(encoding='utf-8'))
                if isinstance(parsed, dict):
                    parsed['game'] = tid
                    lj_data = parsed
            except (OSError, ValueError):
                pass
        lj_path.write_text(json.dumps(lj_data, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')

        # Exact embedded module list from __TEXT,__dm<mod>x0 sections
        embedded_mods = sorted({
            s['sectname'][4:-2] for s in sections
            if s['segname'] == '__TEXT'
            and s['sectname'].startswith('__dm')
            and s['sectname'].endswith('x0')
            and not s['sectname'].endswith('_nro_x0')
            and len(s['sectname']) > 6
        }, key=load_order)
        if not embedded_mods:
            embedded_mods = ['main', 'sdk']

        # Detect shader chain from msl/b-* (or fallback to host chain for vk/gl)
        chain = None
        if (fw_stage / 'msl').is_dir():
            for child in sorted((fw_stage / 'msl').iterdir()):
                if child.is_dir() and re.fullmatch(r'b-[0-9a-fA-F]+', child.name):
                    chain = child.name
                    break
        if not chain:
            chain = 'b-' + current_dmsh_chain()

        # Generate profile.tsv & read romfs_marker / package_version from game.py when available
        extra_games = discover_extra_games_dirs(ipa_path, tid)
        prof_env = os.environ.copy()
        if extra_games:
            prof_env['DM_GAMES_DIR'] = extra_games

        romfs_marker = '.'
        package_version = 'v0'
        prof_tsv = fw_stage / 'profile.tsv'

        gp = subprocess.run(
            [sys.executable, str(DM_DIR / 'games/game.py'), 'profile', tid, str(prof_tsv)],
            env=prof_env, capture_output=True, text=True
        )
        if gp.returncode == 0 and prof_tsv.is_file():
            # Keep profile.tsv's modules in sync with the exact modules embedded in this IPA
            lines = []
            for ln in prof_tsv.read_text(encoding='utf-8').splitlines():
                if ln.startswith('modules\t'):
                    lines.append('modules\t' + ' '.join(embedded_mods))
                elif ln.startswith('romfs_marker\t'):
                    romfs_marker = ln.split('\t', 1)[1].strip() or '.'
                    lines.append(ln)
                else:
                    lines.append(ln)
            prof_tsv.write_text('\n'.join(lines) + '\n', encoding='utf-8')
            pk = subprocess.run(
                [sys.executable, str(DM_DIR / 'games/game.py'), tid, 'package', 'v0'],
                env=prof_env, capture_output=True, text=True
            )
            if pk.returncode == 0 and pk.stdout.strip():
                package_version = pk.stdout.strip()
            if display_name == 'DmIOS':
                nm = subprocess.run(
                    [sys.executable, str(DM_DIR / 'games/game.py'), tid, 'name', tid],
                    env=prof_env, capture_output=True, text=True
                )
                if nm.returncode == 0 and nm.stdout.strip():
                    display_name = nm.stdout.strip()
        else:
            synthesize_profile_tsv(prof_tsv, tid, display_name, embedded_mods, fw_stage / 'dm', sections_for_profile, display_version)

        # RomFS identity (if stamped in the slim IPA)
        romfs_id = ''
        rid_path = app_dir / 'romfs.id'
        if rid_path.is_file():
            line = rid_path.read_text(encoding='utf-8', errors='replace').strip()
            if line.startswith('DMROMFSID1 '):
                romfs_id = line

        # Write Info.plist, icon.png, and game.manifest.json
        write_framework_info_plist(fw_stage / 'Info.plist', fw_name, display_name, tid, display_version, min_os)
        pick_and_copy_icon(app_dir, tid, fw_stage / 'icon.png')

        nro_tsv = fw_stage / 'dm/nro.tsv'
        gen_man_cmd = [
            sys.executable, str(HERE / 'gen_manifest.py'),
            str(fw_stage / 'game.manifest.json'),
            '--game', tid,
            '--name', display_name,
            '--display-version', display_version,
            '--package-version', package_version,
            '--modules', ' '.join(embedded_mods),
            '--chain', chain,
            '--romfs-marker', romfs_marker,
            '--romfs-identity', romfs_id,
            '--min-os', min_os,
            '--framework-name', fw_name,
            '--built-by', 'ipa_to_framework.py',
        ]
        if nro_tsv.is_file():
            gen_man_cmd += ['--nro-table', str(nro_tsv)]
        gm = subprocess.run(gen_man_cmd, capture_output=True, text=True)
        if gm.returncode != 0:
            raise SystemExit(f'[RED] ipa_to_framework: gen_manifest.py failed: {gm.stderr.strip()}')

        strip_apple_double(fw_stage)
        final_fw = out_dir / f'{fw_name}.framework'
        shutil.rmtree(final_fw, ignore_errors=True)
        os.rename(fw_stage, final_fw)
        subprocess.run(['/usr/bin/xattr', '-cr', str(final_fw)], capture_output=True)
        print(final_fw)
        return final_fw
    finally:
        shutil.rmtree(stage_root, ignore_errors=True)


def main(argv=None):
    ap = argparse.ArgumentParser(description='Convert an already-ported .ipa into DmGame<TitleID>.framework.')
    ap.add_argument('ipa', help='Path to the ported .ipa archive')
    ap.add_argument('--out', required=True, help='Output Frameworks directory (e.g. MobileHub/Frameworks)')
    ap.add_argument('--title-id', default='', help='Optional 16-hex Switch Title ID override')
    ap.add_argument('--name', default='', help='Optional display name fallback')
    args = ap.parse_args(argv)
    convert_ipa(args.ipa, args.out, explicit_tid=args.title_id, explicit_name=args.name)


if __name__ == '__main__':
    main()
