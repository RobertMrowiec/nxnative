# NxNative Launcher v1.8.4 Release Notes

**Release Date:** October 30, 2026  
**Build:** v1.8.4 (19)  
**Binary:** `NxNative_Launcher.dmg` (Universal Apple Silicon M1–M4)

---

## 🌟 Overview

NxNative Launcher **v1.8.4** is a dedicated quality and stability release addressing all issues reported in Community Support Hub [#1](https://github.com/rennan101/nxnative_Launcher/issues/1). It introduces automatic **iCloud Drive permission refusal detection and local save fallbacks**, native **on-screen macOS save failure alerts**, an **`isBuildActive` toolchain mutual exclusion lock** that prevents background Git updates from corrupting shader hashes mid-build, robust **`--keep-extracted` / `--no-keep-extracted` CLI flag control**, and live **Auto-Split RomFS threshold evaluation** with real-time UI status indicators.

---

## 🚀 What's New & Fixed

### 1. 🛡️ iCloud Save Permission Diagnostics, Native macOS Alerts & Local Fallback
- **Automatic Fallback to Local Storage**: If the macOS iCloud Drive permission prompt is refused on first launch, or if `clonefile` / file operations encounter permission barriers (`errno=1 EPERM` / `EACCES`), the launcher and engine automatically revert `DM_SAVE` to local storage at `~/Library/Application Support/nxnative/<TitleID>/save`.
- **Pre-Flight Write Probing**: `SaveSyncService` tests directory writability before creating symlinks or committing `DM_SAVE` to `env.txt`, preventing games from starting with broken iCloud mounts.
- **Native macOS Save Failure Dialog**: Implemented `front_save_failed` in the macOS host front-end (`front_mac.m`). If save transaction mounting fails, the game immediately presents an on-screen dialog explaining the permission barrier and providing direct recovery commands (`tccutil reset All <BundleID>`).

### 2. ⚡️ Mid-Build Git Update Lock (Fixed Shader Hash Mismatches)
- **Toolchain Mutual Exclusion Lock**: Introduced a thread-safe `isBuildActive` lock across `BuildRunner` and `UpdateCheckerService`.
- **Paused Git Operations**: All background Git fetch/checkout/pull operations are blocked while an IPA or app compilation is running.
- **UI Safety Shield**: The Update sheet and navigation header display an active lock badge during compilation, deferring repository updates until builds complete cleanly.

### 3. 📦 Clean `--keep-extracted` / `--no-keep-extracted` CLI Generation
- **Explicit CLI Flag Enforcement**: Unchecking intermediate file preservation now explicitly passes `--no-keep-extracted` to `build_ipa_from_nsp.py`, counteracting Python's default-on behavior.
- **Mandatory Target Locking**: For platforms where extracted files are strictly required (Mac App bundles and iOS RomFS separate mode), the GUI disables the toggle and displays a lock icon with a descriptive tooltip.

### 4. 🎚️ Auto-Split RomFS Threshold & Live UI Status
- **Dynamic Threshold Calculation**: Evaluates total game byte size against the configured limit (`autoRomfsSplitLimitGB`) and automatically passes `--romfs separate` during build.
- **Live Status Indicator**: Displays a real-time `⚡️ Auto-Split Active` badge on the build options panel.
- **Instant Slider Updates**: Adjusting the threshold slider immediately re-evaluates the active selection.

---

## 📥 Installation

1. Download **`NxNative_Launcher.dmg`** below.
2. Open the DMG and drag **NxNative_Launcher.app** into `/Applications`.
3. Launch the app. All dependencies and Python runtime are pre-configured out of the box!
