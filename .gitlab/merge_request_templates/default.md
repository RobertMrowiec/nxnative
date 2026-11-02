## 📋 Merge Request Description

### Summary of Changes
<!-- Describe what this change does, why it is needed, and what issue it resolves -->

### Verification Checklist
- [ ] **No Copyrighted Files**: Confirmed that NO game ROMs, `.nsp`, `.xci`, `.keys`, firmware files, or proprietary assets are included in this MR.
- [ ] **No Secret Leaks**: Verified no personal tokens, API keys, passwords, or credentials are committed.
- [ ] **Zero-Hang Invariant**: Verified that no blocking calls (`waitUntilExit`) without deadlines were introduced in the launcher.
- [ ] **Code Quality**: Built and tested locally with `./scripts/build_gui.sh`.
- [ ] **Security**: Verified all subprocess calls use bounded timeouts and no untrusted string interpolations are passed to shell commands.
