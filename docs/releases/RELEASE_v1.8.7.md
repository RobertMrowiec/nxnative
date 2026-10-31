# NxNative Launcher v1.8.7 Release Notes

**Release Date:** October 30, 2026  
**Build:** v1.8.7 (22)  
**Binary:** `NxNative_Launcher.dmg` / `NxNative_Launcher-v1.8.7.dmg` (Universal Apple Silicon M1–M4)

---

## Overview

NxNative Launcher **v1.8.7** introduces native GUI support for newer Xcode Metal compiler toolchains (such as **Xcode 27.2 / Metal Compiler `32023.922`**) via `--allow-other-metal` (Community Support Hub [#1](https://github.com/rennan101/nxnative_Launcher/issues/1#issuecomment-6528488332)), enabled by default so both **macOS (`.app`)** and **iOS (`.ipa`)** builds succeed on the first attempt without terminal workarounds, alongside improved build error reporting and a 1-click recovery callout.

---

## What's New & Improved

### 1. Xcode 27.2+ Metal Compiler Support (`--allow-other-metal`)
- **Default-Enabled Safe Override**: `BuildRunner` now passes `--allow-other-metal` by default (`allowOtherMetal = true`).
  - On **Xcode 27.1** (`32023.921`), `own_compilers.py` detects an exact match with `dmsh_chain.lock` and runs as a transparent no-op.
  - On **Xcode 27.2+** (`32023.922+`), shader translation proceeds on the first attempt while keeping `dmsh_xlate` and `spirv-cross` fingerprint validation strictly enforced and isolating shader cache entries by the active Metal compiler + SDK.
- **Persistent Advanced Build Toggle**: Added **Allow newer/untested Xcode Metal compiler versions (`--allow-other-metal`)** in **Step 2: Build Options → Advanced Options & Build Flags** (`BuildOptionsSection.swift`), persisted across launches via `UserDefaults`.
- **1-Click Recovery Banner**: If a user manually disables the toggle and encounters a `dmsh_chain.lock` compiler mismatch, `BuildExecutionSection` displays a dedicated callout with a 1-click **"Enable & Retry Build"** button.

### 2. Detailed Build Failure Reporting
- **Direct `[RED]` Error Surfacing**: `BuildRunner` now captures `[RED]` `BuildError` messages emitted in JSON progress mode and displays the exact diagnostic message directly in the Build Failed view instead of a generic exit code notice.

### 3. Localization Across All 14 Languages
- Added full translations for the new build option and recovery UI across English, Portuguese (BR & PT), Spanish, French, German, Italian, Japanese, Korean, Polish, Russian, Swedish, Simplified Chinese, and Traditional Chinese.

---

## Installation

1. Download **`NxNative_Launcher.dmg`** (or **`NxNative_Launcher-v1.8.7.dmg`**) below.
2. Open the DMG and drag **NxNative_Launcher.app** into `/Applications`.
3. Or update directly from within the app via **Settings → Check for Updates**.
