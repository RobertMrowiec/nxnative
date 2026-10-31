# NxNative Launcher v1.9.0 Release Notes

**Release Date:** October 31, 2026  
**Build:** v1.9.0 (25)  
**Binary:** `NxNative_Launcher.dmg` / `NxNative_Launcher-v1.9.0.dmg` (Universal Apple Silicon M1–M4)

---

## Overview

NxNative Launcher **v1.9.0** delivers critical engine and pipeline enhancements for multi-game iOS side-by-side installations, automatic subsdk module derivation (fixing video playback and loading screen crashes on updated game versions such as *Absolum*), dynamic iOS device selection directly in the Port modal, and resilient game update parsing.

---

## What's New & Improved

### 1. Dynamic SubSDK Module Detection & Loading Screen Crash Fix
- **Root Cause**: When game updates restructure or renumber internal submodules (such as *Absolum* v1.2.1 dropping `subsdk2` and shifting `NintendoSDK_movie` to `subsdk0`), previous versions used a static list from base game profiles, leaving video demuxers unbound and crashing during video playback (`movie::Extractor` / `movie::SetAllocator`).
- **Dynamic Derivation Engine**: `derive_profile` now inspects the extracted `ExeFS` on disk and uses facts-of-engine analysis (`profile_guess`) to automatically discover and link all required functional subsdks (such as `subsdk0` for video decoding) while safely excluding unneeded low-level GPU drivers (`OpenGL`/`Vulkan`).
- **Verified Stability**: Both Mac app and iOS IPA builds now complete cleanly with solid 60 FPS video playback and gameplay without loading screen crashes.

### 2. Multi-Game Side-by-Side iOS Deployment & Bundle ID Isolation
- **Fix for Overwriting Existing Games**: Previously, automatic profile matching could fall back to an existing provisioning profile from a previously deployed title, causing the newly ported game to inherit the previous game's `CFBundleIdentifier` and overwrite it on the target iOS device.
- **Strict Bundle ID Isolation**: `findMatchingProfile` now enforces strict title ID matching and wildcard validation, preventing unrelated game profiles from being reused. If an exact profile is not yet registered for the device, headless Xcode automatically requests a tailored provisioning profile (`com.<user>.nxnative.<titleId>`) from Apple Developer servers, allowing all ported games to coexist side-by-side on iPhone and iPad.

### 3. Integrated iOS Device Selection in "Port Game" Modal
- **One-Click Deployment**: The "Port Game" modal now integrates real-time connected iOS device discovery (`devicectl`), device connection status indicators, signing team selection, and list refresh controls.
- **Dynamic Action Button**: When iOS deployment is enabled, the action button dynamically changes to **"Port & Send to [Device Name]"**, streamlining the porting and device installation workflow into a single step.

### 4. Tolerant Version Regex Matching
- **Flexible Filename Parsing**: Game updates naming formats from varied release groups (`Absolum Switch NSP Update v589824.nsp`, `_v589824`, `(v589824)`, etc.) are now recognized automatically alongside standard bracketed notation (`[v589824]`), guaranteeing reliable automated bundling and staging.

---

## Installation

1. Download **`NxNative_Launcher.dmg`** (or **`NxNative_Launcher-v1.9.0.dmg`**) below.
2. Open the DMG and drag **NxNative_Launcher.app** into `/Applications`.
3. Or update directly from within the app via **Settings → Check for Updates**.
