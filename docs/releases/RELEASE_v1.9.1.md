# NxNative Launcher v1.9.1 Release Notes

**Release Date:** October 31, 2026  
**Build:** v1.9.1 (26)  
**Binary:** `NxNative_Launcher.dmg` / `NxNative_Launcher-v1.9.1.dmg` (Universal Apple Silicon M1–M4)

---

## Overview

NxNative Launcher **v1.9.1** is a major stability and usability release addressing controller recognition, Mac keyboard input, standalone iOS IPA deployment, and bundle packaging across **all ported Nintendo Switch games**.

---

## What's New & Improved

### 1. Universal Input & Controller Recognition (All Games)
- **Title Screen "Press L + R" Clarification & Guide**:
  - Nearly all Nintendo Switch titles (such as *The Legend of Zelda: Link's Awakening*, *Super Mario Odyssey*, *Mario Kart 8 Deluxe*) require pressing **L + R simultaneously** on the title screen to detect and assign Player 1.
  - Added an intuitive **Controls Quick Reference** sheet directly accessible from the Game Deck and Console Hero action bars.
  - Clarified key combos: Press **`Q + E`** together on Mac keyboard, or **`LB + RB`** (bumpers) together on Xbox / DualSense / Switch Pro controllers.
- **Engine Focus & Input Initialization Race Fix**:
  - Fixed an engine race condition in `front_mac.m` where window focus observers were registered after window display, causing `g_input_on` to start as 0 on launch. The engine now guarantees keyboard and controller input processing from frame 0.
- **Modern GameController Value Change Handler (macOS 11+)**:
  - Integrated `physicalInputProfile.valueDidChangeHandler` with safe memory captures to accurately track triggers, bumpers, and buttons for Xbox and Bluetooth controllers without event loss.
  - Added delayed controller discovery polling (500ms and 1500ms) to smoothly register wireless gamepads connected right after launch.
  - Removed aggressive focus lockouts so controllers remain active unless the game window is explicitly minimized.
- **Button Mapping Collision Resolved**:
  - Re-mapped `SwitchButton.capture` to `"buttonShare"`, restoring proper functionality to `SwitchButton.minus` (`-` / Select / Map / `buttonOptions`).

### 2. Standalone iOS IPA Deployment & Provisioning Fixes
- **Dynamic Provisioning Project Discovery**:
  - Previously, `DeviceDeploymentService` referenced a developer-specific path for `DmIOS.xcodeproj`. On clean installations or other Macs, Xcode provisioning failed silently and fell back to ad-hoc signing (`--sign -`), which stock iOS and `devicectl` reject with connection/tunnel/signature errors.
  - `build_gui.sh` now bundles `DmIOS.xcodeproj` directly into `Contents/Resources/dm/ios/`, and the deployment service dynamically discovers it across bundle, tools, and repo directories.
- **AirDrop & Sideloading Guidance**:
  - Stock iOS prohibits installing raw `.ipa` packages directly when received via AirDrop or Files without a sideloading manager.
  - The UI and tooltips now explicitly explain that AirDrop `.ipa` files should be opened using **AltStore**, **SideStore**, or **TrollStore**, while direct cable installation can be performed with one click using the built-in Xcode signing pipeline (with iOS Developer Mode enabled).
- **Fast Bounded Signing**:
  - Removed `--deep` codesigning from game bundles to prevent long asset-hashing freezes on large games.

### 3. Streamlined Build Pipeline & Single App Bundle
- Updated `build_gui.sh` to generate a single unified `NxNative_Launcher.app` bundle in the workspace directory, eliminating redundant duplicate bundles on disk.
- Integrated automatic 7-day sideload license countdown tracker and visual badges.

---

## Installation

1. Download **`NxNative_Launcher.dmg`** (or **`NxNative_Launcher-v1.9.1.dmg`**) below.
2. Open the DMG and drag **NxNative_Launcher.app** into `/Applications`.
3. Or update directly from within the app via **Settings → Check for Updates**.
