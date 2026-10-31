# NxNative Launcher v1.8.3 Release Notes

**Release Date:** October 29, 2026  
**Build:** v1.8.3 (18)  
**Binary:** `NxNative_Launcher.dmg` (Universal Apple Silicon M1–M4)

---

## 🌟 Overview

NxNative Launcher **v1.8.3** is a critical performance and reliability release. It resolves the issue where games would hang in an indefinite launching state upon pressing Play, introduces automatic **macOS Game Mode (Modo Jogo)** execution with native full-screen immersion, implements automatic ad-hoc re-signing before launch to bypass Gatekeeper integrity errors, adds interactive **mouse drag-and-drop game library reordering**, and enforces **modal input focus locks** so controller and keyboard navigation never clash with active sheets or text fields.

---

## 🚀 What's New & Fixed

### 1. 🎮 Native macOS Game Mode (Modo Jogo) by Default
- **Automatic Game Mode**: When launching games, NxNative Launcher now defaults `DM_FULLSCREEN=1`, triggering macOS Sonoma/Sequoia's hardware **Game Mode**.
- **CPU & GPU Prioritization**: macOS automatically allocates top CPU and GPU priority to the game process, minimizing background process interference.
- **Ultra-Low Wireless Latency**: Drastically reduces input latency for connected Bluetooth game controllers (DualSense, Xbox, Switch Pro) and latency for AirPods/wireless audio.
- **Dedicated Game Mode Toggle**: Configurable per-game in the Liquid Glass Game Settings modal under the new **Game Mode** switch, with real-time status pill indicators on the Console Hero view.

### 2. ⚡️ Instant Game Launch Fix & Automated Code Signing Pipeline
- **Fixed Infinite "Launching" Hang**:
  - Eliminated binary corruption caused by syncing generic host profiles into game bundles with unique engine profile requirements (e.g. *The Legend of Zelda: Tears of the Kingdom*).
  - Explicitly passed `DM_LAUNCHER=0` into launch environment arguments, preventing the game host from hanging in an unpresented background settings state.
- **Automated Pre-Launch Code Signing**:
  - Before launching, the launcher now automatically strips quarantine attributes (`xattr -cr`) and re-signs game bundles ad-hoc (`codesign --force --deep --sign -`), guaranteeing Gatekeeper and AMFI acceptance even after mod or file changes.

### 3. 🖱️ Mouse Drag & Drop Library Organization
- **Direct Card Reordering**: Drag and drop game cards directly across the Dark Mode Switch console carousel to arrange your library in any desired order.
- **Instant Persistence**: Custom order is stored in `UserDefaults` and preserved across launcher launches.
- **Smooth Animations**: Interactive lift, scale, and slot snap feedback while dragging with mouse or trackpad.

### 4. 🔒 Modal Input Focus Lock & Hotkey Shield
- **Navigation Safety**: When any modal sheet (Settings, Mods, About, Update) or text input is active, keyboard and controller hotkeys for tab switching and carousel navigation are automatically shielded.
- **Input Conflict Prevention**: Typing in search or configuration inputs no longer inadvertently navigates the game library or switches tabs.

---

## 📥 Installation

1. Download **`NxNative_Launcher.dmg`** below.
2. Open the DMG and drag **NxNative_Launcher.app** into `/Applications`.
3. Launch the app. All dependencies and Python runtime are pre-configured out of the box!
