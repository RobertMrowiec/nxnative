## 📋 Merge Request Description

### Summary of Changes
<!-- Describe what this change does, why it is needed, and what issue or game it addresses. -->

### Type of Change
- [ ] 🐛 Bug fix (non-breaking fix resolving an issue)
- [ ] 🎮 Game compatibility / Profile addition
- [ ] ⚡ Engine performance & Metal optimization
- [ ] 💎 GUI / UX enhancement (Apple Liquid Glass)
- [ ] 📖 Documentation & Localization

### Related Issues
<!-- Closes #123, Fixes #456 -->

---

### 🛡️ Verification Checklist (MANDATORY)

- [ ] **1. No Copyrighted Material**: Confirmed that NO proprietary ROMs, `.nsp`, `.xci`, `prod.keys`, `title.keys`, firmware files, or copyrighted game assets are included.
- [ ] **2. No Secrets / Tokens**: Confirmed no GitLab/GitHub personal access tokens, API keys, or private credentials are committed.
- [ ] **3. Zero-Hang Launcher Invariant**:
  - No synchronous calls (`waitUntilExit`) without bounded deadlines (<= 2.0s).
  - Launch watchdog (`launchingGameId = nil`) remains protected.
  - Subprocess callbacks dispatch safely to `DispatchQueue.main`.
  - `ProcessInfo.processInfo.environment` is preserved.
  - Never use `--deep` in codesign of game bundles.
- [ ] **4. Production Build Verification**:
  - Successfully built with `cd gui && swift build -c release`.
  - Tested bundle generation with `./scripts/build_gui.sh`.
- [ ] **5. English-Only Standards**: All release notes, commit summaries, and PR descriptions are in English (`en-US`).
