# NxNative Launcher v1.8.2 Release Notes

**Release Date:** October 29, 2026  
**Build:** v1.8.2 (17)  
**Binary:** `NxNative_Launcher.dmg` (Universal Apple Silicon M1–M4)

---

## 🌟 Overview

NxNative Launcher **v1.8.2** is a major quality-of-life and architectural stability release. It introduces an **isolated standalone runtime** that eliminates the need for end-users to install Homebrew or configure system Python, completely resolves **Python 3.15 module compilation failures**, provides a dedicated **iCloud Sync Toggle with one-click cloud storage reclamation**, and adds **easy reset controls for iOS certificates and provisioning profiles**.

---

## 🚀 What's New & Fixed

### 1. 📦 Isolated Standalone Runtime (Zero Homebrew / Terminal Setup)
- **Embedded Python 3.13 & Native Wheels**: Bundled directly inside `NxNative_Launcher.app/Contents/Resources/python`. Includes all required porting libraries pre-installed as universal binaries (`lz4`, `capstone`, `fonttools`, `nsz`, `zstandard`, `pycryptodome`, etc.).
- **Bundled Static Tooling**: Core utilities (`zstd`, `spirv-cross`, `glslangValidator`, and `xcodegen`) are now embedded inside `Contents/Resources/tools/bin`.
- **Sandbox Isolation**: Executed with `PYTHONNOUSERSITE=1` and `PYTHONDONTWRITEBYTECODE=1` to ensure total isolation from system-wide or user-level pip packages.
- **Homebrew Optional**: Homebrew is now completely optional for players running the standalone launcher.

### 2. 🐍 Python 3.15 Modules Incompatibility Fix (Closes #10)
- **The Issue**: macOS users with Python 3.15 (recently distributed through Homebrew) experienced compilation crashes when installing Python modules (specifically `clang -bundle -undefined dynamic_lookup` failures while building `lz4` and native C-extensions from source).
- **The Resolution**:
  - The launcher prioritizes the bundled isolated Python 3.13 runtime first.
  - When inspecting system Python, the detector strictly prioritizes `/opt/homebrew/bin/python3.13` and `/usr/local/bin/python3.13` ahead of experimental versions.
  - Python versions >= 3.15 are explicitly flagged as incompatible with C-extensions, with one-click repair routing to `brew install python@3.13`.

### 3. ☁️ iCloud Sync Toggle & Storage Reclaim (Closes #16)
- **iCloud Sync Toggle**: Users can now completely disable iCloud Drive synchronization from both **System Settings > Storage & Diagnostics** and **Game Settings > Saves**.
- **Local-Only Backups**: Safety snapshots and game backups are now strictly written to local disk (`~/Library/Application Support/nxnative/<TITLEID>/backups/`), never filling your personal iCloud Drive quota.
- **Automated Retention**: Keeps only the 5 most recent snapshots per game, automatically pruning older historical saves.
- **Safe Reversion to Local**: Turning off iCloud Sync seamlessly restores files from iCloud into local folders, deletes symlinks, and cleans `DM_SAVE`.
- **Reclaim iCloud Space Button**: Added a 1-click button in **Storage & Diagnostics** to measure and permanently purge existing launcher save files from iCloud Drive.

### 4. 🔏 iOS Signing Identity & Profile Reset (Closes #9)
- **Quick-Clear Actions**: Added `xmark` buttons next to custom `.p12` certificates and `.mobileprovision` profiles to immediately clear selections and remove stored profile paths from `UserDefaults`.
- **Unsigned / Sideloading Mode**: Added `None (Unsigned / Sideloading)` to the Signing Team dropdown, ideal for users deploying games via AltStore, SideStore, or TrollStore without overriding signatures.

---

## 📥 Installation

1. Download **`NxNative_Launcher.dmg`** below.
2. Open the DMG and drag **NxNative Launcher.app** into `/Applications`.
3. Launch the app. All dependencies and Python runtime are pre-configured out of the box!
