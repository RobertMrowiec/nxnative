<div align="center">
  <a href="README.md"><b>📖 Overview & Guide</b></a> &nbsp;&nbsp;|&nbsp;&nbsp;
  <a href="SUPPORTED_GAMES.md"><b>🎮 Supported Games & Timeline</b></a> &nbsp;&nbsp;|&nbsp;&nbsp;
  <a href="CONTRIBUTING.md"><b>🤝 Contributing</b></a> &nbsp;&nbsp;|&nbsp;&nbsp;
  <a href="https://gitlab.com/rennan-group2/nxnative_Launcher/-/releases/permalink/latest"><b>📦 Latest Release (.dmg)</b></a>
</div>

---

# Contributing to NxNative Launcher

Thank you for your interest in contributing to **NxNative Launcher** and the **nxnative** ecosystem! Issues, discussions, and merge requests are welcome on GitLab. This document outlines our development guidelines, clean-room legal policies, preservation mission, and contribution workflow.

---

## 🏛️ Preservation Mission: *"For Those Who Come After"*

**NxNative Launcher** is an open-source technical initiative dedicated to digital video game preservation, computer science research, and hardware interoperability. As physical consoles age and proprietary hardware enters obsolescence, our objective is to ensure that games lawfully acquired by players can endure, run natively, and be preserved on modern Apple Silicon personal computers—safeguarding interactive culture and heritage for future generations (*"for those who come after"*).

---

## ⚖️ Clean-Room & Anti-Piracy Policy

> [!CAUTION]
> **Strict Zero Copyrighted Material Policy**:
> - **Never** commit, attach, or distribute game ROMs, binaries, keys (`prod.keys`, `title.keys`), RomFS dumps, ExeFS modules, extracted assets, or decrypted shaders.
> - **We DO NOT distribute game copies, nor do we condone or facilitate digital copyright infringement or software piracy.**
> - Game dumps must stay strictly on your local private storage. Only code, sanitized logs, benchmark stats, screenshots, Title IDs, Build IDs, and engine patches are permitted.
> - Operates strictly under Section 1201(f) of the Digital Millennium Copyright Act (17 U.S.C. § 1201(f) - Reverse Engineering for Interoperability) and international fair use standards.

- **One change per PR, off `main`.** Rebase on `main` rather than merging it in.
- **Commits.** Each commit message says what changed and why, in plain English sentences, as the history does: the symptom, the cause, the fix, and what was measured or checked.
- **Front ends.** A change a front end has to act on takes a `Front-ends:` line in the commit message and the PR text, unless git already shows it ([Following main](docs/frontends.md#following-main)). A change that makes the host read saves or other kept data differently also carries the old form forward.
- **Where findings go.** A fact about one game goes in its note (`dm/games/<id>/README.md`). A general mechanism gets an entry in `docs/reference/<subsystem>.md` (Symptom, Cause, Fix, Found on), followed by `python3 dm/tools/docs_symptoms.py`. A new game takes its profile, its note and its row in the games table ([dm/games/README.md](dm/games/README.md)).
- **The README gallery.** After Mac gameplay testing, add its screenshot to `docs/images/` and its row to [gallery.tsv](docs/images/gallery.tsv), then run `python3 dm/tools/docs_gallery.py`. The table preserves your chosen order; notes hold the IPA size and noteworthy features or limitations. Leave the note empty until the IPA size is measured. Concurrent additions merge in the TSV; regenerate README to resolve a conflict inside its gallery. Conflicting rows for one game need a manual resolution before regeneration.
- **The shader chain.** After changing one of its tools, run `python3 dm/gfx/tools/dmsh_chain.py --header` and commit `dm/gfx/nvn/dmsh_chain.h` with the change. Every game's shaders are then rebuilt, so say which games you checked.
- **Tests.** CI runs the host tests, the CPU-only graphics tests, the tool tests and the builds ([Continuous integration](docs/development.md#continuous-integration)). GitHub's runners have no Metal 4, so run the GPU tests on an Apple-silicon Mac: `make -C dm/gfx/tests GAME=<id> run`.
- **The PR text.** Fill in the template: what and why, what was checked (tests, games, devices), and which docs changed.

## 🛠️ Where to Start

- **Launcher UI & Frontend**: Built with Swift 5.9+ / SwiftUI for macOS. Core code lives under `gui/Sources/`.
- **Core Recompiler & Runtime**: Upstream repository is [`seedds/nxnative`](https://github.com/seedds/nxnative). Engine docs are in [docs/](docs/).
- **A new game profile**: Check [SUPPORTED_GAMES.md](SUPPORTED_GAMES.md) first. If your game is not listed, port it via the visual wizard or upstream scripts, test on Mac Apple Silicon, and contribute the profile `game.tsv` upstream.

---

## 🐞 Reporting Problems

When reporting an issue on [GitLab Issues](https://gitlab.com/rennan-group2/nxnative_Launcher/-/issues), please provide:
1. **Device & OS**: Chip model (e.g., M1, M2 Pro, M3 Max, M4, iPhone 15 Pro) and macOS/iOS version.
2. **Game Information**: Title ID and Game Build Version.
3. **Logs**: Attach sanitized logs located at `~/Library/Logs/nxnative/<TitleID>.log`.
   - You can also run `python3 scripts/bug_report.py <TitleID>` to produce a sanitized diagnostic report zip.
4. **Description**: Clear description of the unexpected behavior (crash, visual glitch, frame pacing).

---

## 🔀 Submitting a Merge Request (MR)

1. **One change per MR** off `main`.
2. **Keep commits descriptive**: Explain the symptom, root cause, and how you verified the fix.
3. **Tests & Verification Checklist**:
   - For GUI changes: verify clean build with `./scripts/build_gui.sh`.
   - For supported games list: run `python3 scripts/generate_supported_games.py`.
   - For engine modifications: ensure host regression checks pass.
   - For release packages: run `./scripts/gitlab_release.sh`.

<div align="center">
  <a href="README.md"><b>⬅️ Back to Overview & Guide</b></a> &nbsp;&nbsp;|&nbsp;&nbsp;
  <a href="SUPPORTED_GAMES.md"><b>🎮 View Supported Games</b></a> &nbsp;&nbsp;|&nbsp;&nbsp;
  <a href="https://gitlab.com/rennan-group2/nxnative_Launcher/-/releases/permalink/latest"><b>📦 Latest Release (.dmg)</b></a>
</div>
