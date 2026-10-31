# NxNative Launcher v1.8.5 Release Notes

**Release Date:** October 30, 2026  
**Build:** v1.8.5 (20)  
**Binary:** `NxNative_Launcher.dmg` (Universal Apple Silicon M1–M4)

---

## 🌟 Overview

NxNative Launcher **v1.8.5** is a mission-critical stability release that completely eliminates the infinite game loading hang ("Carregando..." forever), safeguards the local game launch pipeline with a fail-safe watchdog, restores system environment inheritance to prevent `dmhost` startup crashes, updates navigation icons, and introduces convenient RomFS export actions for iOS devices.

---

## 🚀 What's New & Fixed

### 1. 🛡️ Invariant Zero-Hang Launch Pipeline
- **Environment Inheritance Restored**: Fixed an issue where `NSWorkspace.OpenConfiguration.environment` stripped `ProcessInfo.processInfo.environment`, which caused `dmhost` to encounter a segmentation fault (`SIGSEGV`) when reading `HOME` or `USER`. All games now launch smoothly.
- **Fail-Safe Watchdog (6.0s)**: Added an automatic watchdog that resets `launchingGameId`, logs a clear warning in the console, and triggers an error sound effect if an unexpected OS-level stall occurs. The UI button will never remain trapped in a loading state.
- **Fast Ad-Hoc Binary Signing**: Enforced fast Mach-O codesigning (~0.02s) on `Contents/MacOS/dmhost` and wrapper without `--deep` recursion over multi-gigabyte asset folders.
- **Bounded Auxiliary Timeouts**: All preparation commands (`xattr`, `codesign`) and connected device auto-sync (`SaveSyncService`) are strictly bounded to 2.0s deadlines. Device latency can never stall a Mac game launch.

### 2. 🎮 Navigation & UI Refinements
- **Icon Alignment**:
  - Library tab now features a dedicated gamepad icon (`gamecontroller.fill`).
  - Compatibility list now features the library books icon (`books.vertical.fill`).
  - Controls tab now features an arcade stick console icon (`arcade.stick.console.fill`).
- **Send to iOS / App Switcher**: Added quick send action when selecting iOS builds directly from the detail deck.

### 3. 📦 iOS Separate RomFS & AirDrop Workflow
- **AirDrop RomFS Button**: When building IPAs in lightweight separate RomFS mode (<100MB), the build complete section and banner now provide direct 1-click **AirDrop RomFS.img** and **Open in Finder** buttons.
- **Dynamic Identity Matching on iOS**: iOS loader now identifies and accepts any `<title_id>.romfs.img` or `romfs.img` dropped into the app's `Documents/` folder via the Files app or Finder.

### 4. 📜 Canonical Anti-Regression Project Rules
- Embedded permanent, self-enforcing rules in `GEMINI.md` and `.agents/rules/` to guarantee that the launch pipeline is strictly audited on every future commit and can never be broken again.

---

## 📥 Installation

1. Download **`NxNative_Launcher.dmg`** below.
2. Open the DMG and drag **NxNative_Launcher.app** into `/Applications`.
3. Launch the app. All dependencies and Python runtime are pre-configured out of the box!
