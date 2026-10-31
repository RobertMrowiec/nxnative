# NxNative Launcher v1.8.9 Release Notes

**Release Date:** October 31, 2026  
**Build:** v1.8.9 (24)  
**Binary:** `NxNative_Launcher.dmg` / `NxNative_Launcher-v1.8.9.dmg` (Universal Apple Silicon M1–M4)

---

## Overview

NxNative Launcher **v1.8.9** brings essential bug fixes for re-compilation shader caching and keyboard shortcut handling (resolving both issues reported in Community Support Hub [#1](https://github.com/rennan101/nxnative_Launcher/issues/1#issuecomment-6538201430) by @talk2g), alongside a major modular UI architecture refactoring for enhanced performance, instant search-to-grid navigation, and refined multi-language support.

---

## What's New & Improved

### 1. Staging Workspace Shader Cache Preservation ([#1](https://github.com/rennan101/nxnative_Launcher/issues/1))
- **Fix for Redundant Re-Compilations**: Previously, initiating a build for a game in Staging mode would clean the staging workspace by wiping the directory, inadvertently deleting the `<id>_build/` directory holding intermediate extracted game assets, compiled Metal shader packages, and translation fingerprints.
- **Smart Staging Workspace Refresh**: The staging cleaner now cleans up only stale file symlinks to update file references while explicitly preserving `<id>_build/`, extraction caches, and compiled shader databases.
- **Instant Rebuilds**: Games such as *Dark Souls: Remastered* and other heavy titles now correctly reuse their shader cache from staging on repeat compilations, drastically reducing build times from minutes to seconds.

### 2. Standard macOS Command+Q Application Termination ([#1](https://github.com/rennan101/nxnative_Launcher/issues/1))
- **Fix for Tab-Cycling on `Cmd+Q`**: Previously, `KeyboardNavBridge` swallowed all keystrokes whose character representation was `"q"` (used for tab cycling `[`), capturing `Cmd+Q` before the macOS event responder chain could process application termination.
- **System Modifier Guard**: Added explicit checks (`event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control)`) in `KeyboardNavBridge` ensuring system shortcuts pass directly through to macOS menus without interference.
- **Explicit Menu Command**: Registered an explicit `CommandGroup(replacing: .appTermination)` in `NXNativeGUIApp` with `.keyboardShortcut("q", modifiers: [.command])` calling `NSApplication.shared.terminate(nil)`.

### 3. Smart Search & Smooth Grid Navigation
- **Quick Focus Release**: Pressing Down Arrow or Return in the Library Search input field now immediately unfocuses the search bar and transfers selection directly to the game cards.
- **Empty Search Arrow Navigation**: When the search field is empty, pressing Left/Right/Up automatically unfocuses and resumes standard shelf and card navigation.

### 4. Modular Codebase & Architectural Refactoring
- **Decoupled Architecture**: Refactored `AppViewModel` into clean, testable domain extensions (`AppViewModel+BuildRunner.swift`, `AppViewModel+FocusedGame.swift`, `AppViewModel+GameLaunch.swift`, `AppViewModel+PortModalNav.swift`, `AppViewModel+UnifiedNavigation.swift`, `AppViewModel+LibraryReorder.swift`).
- **Unified Library & Shelf Views**: Modularized library views with `PortedCategoryShelfView`, `UnifiedConsoleGridView`, and `LibraryFilterSortBarView`.
- **Modular Translations**: Separated language additions into dedicated files (`Translations+Additions+*.swift`) across all 14 supported languages.

---

## Installation

1. Download **`NxNative_Launcher.dmg`** (or **`NxNative_Launcher-v1.8.9.dmg`**) below.
2. Open the DMG and drag **NxNative_Launcher.app** into `/Applications`.
3. Or update directly from within the app via **Settings → Check for Updates**.
