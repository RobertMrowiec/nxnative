<div align="center">
  <a href="README.md"><b>📖 Overview & Guide</b></a> &nbsp;&nbsp;|&nbsp;&nbsp;  <a href="SUPPORTED_GAMES.md"><b>🎮 Supported Games & Timeline</b></a> &nbsp;&nbsp;|&nbsp;&nbsp;  <a href="CONTRIBUTING.md"><b>🤝 Contributing</b></a>
</div>

---
# 🎮 Supported Games & Platform Features Timeline
> **Live Upstream Synchronization**: Verified compatibility matrix directly derived from [`seedds/nxnative`](https://github.com/seedds/nxnative) game profiles and host bring-up suites.

[![Total Games](https://img.shields.io/badge/Verified%20Titles-149%20Playable-success.svg)](#complete-verified-games-catalog) [![Core Engine](https://img.shields.io/badge/Core%20Engine-seedds%2Fnxnative-informational.svg)](https://github.com/seedds/nxnative) [![4GB Ready](https://img.shields.io/badge/4GB%20RAM-34%20Games-blue.svg)](#hardware-tier-guide) [![8GB Ready](https://img.shields.io/badge/8GB%20RAM-109%20Games-purple.svg)](#hardware-tier-guide) [![16GB Enthusiast](https://img.shields.io/badge/16GB%20RAM-149%20Games-orange.svg)](#hardware-tier-guide)

### 📑 Quick Navigation
- [💻 Hardware & RAM Tier Guide](#hardware-ram-tier-guide)
- [📚 Complete Verified Games Catalog (149 Titles)](#complete-verified-games-catalog)
- [🚀 Platform Features Timeline (Newest to Oldest)](#platform-features-timeline-newest-to-oldest)
- [🔄 How to Port an Unlisted Game](#how-to-port-an-unlisted-game)

---
## 💻 Hardware & RAM Tier Guide (Requires macOS 26.6+ Tahoe / iOS 26.0+ & Metal 4)

> [!IMPORTANT]
> **OS & Metal 4 Requirement**: Because `nxnative` performs ahead-of-time native recompilation into ARM64 Mach-O code and translates shaders to **Apple Metal 4** (`MTL4CommandQueue`, `MTL4Compiler`, `MTL4MeshRenderPipelineDescriptor`), you **must run macOS 26.6 or later (macOS Tahoe)** with **Xcode 27.2+** on Mac, and **iOS 26.0+ / iPadOS 26.0+** on iPhone/iPad. Earlier OS versions (macOS 13–15, iOS 18) do not include Metal 4.

Use this guide to assess your Apple Silicon device's expected performance:

| Memory Tier | Mac Hardware (Apple Silicon) | iPhone / iPad Hardware | Playable Titles | Target Performance |
| :--- | :--- | :--- | :---: | :--- |
| **4 GB RAM** | M1, M2, M3, M4 (Any Mac) | iPhone 15 Pro, 16 Pro, iPad Pro M1+ | **34 games** | Native 60 FPS • Lightweight 2D/3D |
| **6 GB RAM** | M1, M2, M3, M4 (Any Mac) | iPhone 15 Pro, 16 Pro, iPad Pro M1+ | **87 games** | Native 60 FPS • Standard 3D Titles |
| **8 GB RAM** | M1/M2/M3/M4 with 8GB+ RAM | iPhone 15 Pro / 16 / 16 Pro, iPad Air/Pro M1+ | **109 games** | 1080p/4K 60 FPS • Flagship 3D Open World |
| **16 GB+ RAM**| M1 Pro/Max, M2 Pro/Max, M3 Pro/Max, M4 Pro | iPhone 16 Pro / iPad Pro M2/M4 | **149 games (100%)** | 4K 60 FPS • Heavyweight Unreal / Monolith Games |

> [!TIP]
> **Unified Memory Advantage**: macOS and iOS share memory dynamically between the CPU and Metal GPU. A Mac with 8GB Unified Memory can run 83% of the catalog, while 16GB handles 100% of tested titles with high-resolution textures.

---
## 📚 Complete Verified Games Catalog

Currently tracking **149 tested game profiles** (143 NVN, 3 OpenGL, 4 Vulkan):

| Game Title | Title ID | Tested Build | Engine & Backend | Min RAM (Mac) | Min iOS Silicon | Highlights & Notes |
| :--- | :---: | :---: | :--- | :---: | :---: | :--- |
| [13 Sentinels: Aegis Rim](dm/games/01003FC01670C000/README.md) | `01003FC01670C000` | 1.10 | Vanillaware's engine • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [13 Sentinels: Aegis Rim, Asian release](dm/games/01008D7016438000/README.md) | `01008D7016438000` | 1.00 (base) | Vanillaware's engine • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [13 Sentinels: Aegis Rim, Japanese release](dm/games/010045C014650000/README.md) | `010045C014650000` | 1.00 (base) | Vanillaware's engine • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [Absolum](dm/games/0100A83022A22000/README.md) | `0100A83022A22000` | 1.1.2 | FNA / .NET NativeAOT (FNA3D's NVN driver) • **NVN** | **8 GB** | A17 Pro+ (8GB) | Playable |
| [Ace Attorney Investigations Collection](dm/games/010005501E68C000/README.md) | `010005501E68C000` | 1.0.0.2 | Unity 2022.3.17f1 IL2CPP • **NVN** | **4 GB** | A17 Pro+ (8GB) | Playable |
| [Advance Wars 1+2: Re-Boot Camp](dm/games/0100300012F2A000/README.md) | `0100300012F2A000` | 1.0.0 (base) | Unity 2020.2.1f3 IL2CPP • **NVN** | **8 GB** | A17 Pro+ (8GB) | Playable |
| [AI: THE SOMNIUM FILES](dm/games/010089B00D09C000/README.md) | `010089B00D09C000` | 1.0.1 | Unity 2017.4.17f1 IL2CPP • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [ASTRAL CHAIN](dm/games/01007300020FA000/README.md) | `01007300020FA000` | 1.0.1 | PlatinumGames' engine • **NVN** | **4 GB** | A17 Pro+ (8GB) | ⚡ **60 fps target with 1.0.1** |
| [AI: THE SOMNIUM FILES - nirvanA Initiative](dm/games/0100713016CCC000/README.md) | `0100713016CCC000` | 1.0.2 | Unity 2020.3.30f1 IL2CPP • **NVN** | **4 GB** | A17 Pro+ (8GB) | Playable |
| [ANIMAL WELL](dm/games/010020D01AD24000/README.md) | `010020D01AD24000` | 1.0.10 | its own (not named) • **NVN** | **4 GB** | A17 Pro+ (8GB) | Playable |
| [Animal Crossing: New Horizons](dm/games/01006F8002326000/README.md) | `01006F8002326000` | 3.0.3 | Nintendo EPD (sead / agl / gsys) • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [Atelier Ryza: Ever Darkness & the Secret Hideout DX](dm/games/0100199023B2E000/README.md) | `0100199023B2E000` | 1.2.0 | Gust's engine on Koei Tecmo's KTGL • **NVN** | **8 GB** | A18+ (8GB) | Playable |
| [Baba Is You](dm/games/01002CD00A51C000/README.md) | `01002CD00A51C000` | 1.0.12 | Multimedia Fusion 2 game on MP2 Games' runtime (Lua) • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [BALL x PIT](dm/games/010086A022444000/README.md) | `010086A022444000` | 1.293 | Unity 6000.0.62f1 IL2CPP • **NVN** | **8 GB** | A17 Pro+ (8GB) | Playable |
| [Balatro](dm/games/0100CD801CE5E000/README.md) | `0100CD801CE5E000` | 1.1.3 | LÖVE 11.4 (love-nx, LuaJIT, SDL) • **OpenGL** | **4 GB** | A17 Pro+ (8GB) | 👆 *played by touch* |
| [Bastion](dm/games/010038600B27E000/README.md) | `010038600B27E000` | 1.0.0 (base) | Supergiant Games' engine on MonoGame 3.0 • **NVN** | **4 GB** | A17 Pro+ (8GB) | Playable |
| [Batman: Arkham Knight](dm/games/0100ACD0163D0000/README.md) | `0100ACD0163D0000` | 1.0.5 | Unreal Engine 3 (Rocksteady), Wwise • **NVN** | **16 GB** | A18 Pro (8GB) | Playable |
| [Bayonetta](dm/games/010076F0049A2000/README.md) | `010076F0049A2000` | 1.1 | PlatinumGames' engine (Wii U form) • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [Bayonetta 2](dm/games/01007960049A0000/README.md) | `01007960049A0000` | 1.2 | PlatinumGames' engine (Wii U form) • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [Bayonetta 3](dm/games/01004A4010FEA000/README.md) | `01004A4010FEA000` | 1.2.0 | PlatinumGames' engine • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [Big Brain Academy: Brain vs. Brain](dm/games/0100620012D6E000/README.md) | `0100620012D6E000` | 1.2.0 | NintendoWare Bezel Engine 1.56 • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [Blasphemous](dm/games/0100698009C6E000/README.md) | `0100698009C6E000` | 1.0.8 | Unity 2017.4.28f1 IL2CPP, FMOD • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [Blasphemous 2](dm/games/010040801A4C8000/README.md) | `010040801A4C8000` | 1.0.8 | Unity 2021.3.20f1 IL2CPP, FMOD • **NVN** | **4 GB** | A17 Pro+ (8GB) | Playable |
| [Brain Memory Training Academy](dm/games/0100F5D01DA3A000/README.md) | `0100F5D01DA3A000` | 1.0.0 (base) | Unity 2022.3.5f1 IL2CPP • **NVN** | **4 GB** | A17 Pro+ (8GB) | Playable |
| [Captain Toad: Treasure Tracker](dm/games/01009BF0072D4000/README.md) | `01009BF0072D4000` | 1.4.2 | Nintendo EPD Tokyo (`al` over sead / agl) • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [Castlevania: Belmont's Curse](dm/games/0100BA4026E94000/README.md) | `0100BA4026E94000` | 1.1.0 | Unity 2022.3.62f2 IL2CPP, FMOD • **NVN** | **4 GB** | A17 Pro+ (8GB) | Playable |
| [Catherine: Full Body](dm/games/0100BF00112C0000/README.md) | `0100BF00112C0000` | 1.0.1a | Atlus GFD (CRI middleware) • **NVN** | **4 GB** | A17 Pro+ (8GB) | Playable |
| [Celeste](dm/games/01002B30028F6000/README.md) | `01002B30028F6000` | 1.4.1.1 | MonoGame (C# → C++ by BRUTE) • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [Cult of the Lamb](dm/games/01002E7016C46000/README.md) | `01002E7016C46000` | 1.5.28 | Unity 2022.3.62f3 IL2CPP, FMOD • **NVN** | **4 GB** | A17 Pro+ (8GB) | Playable |
| [Cuphead](dm/games/0100A5C00D162000/README.md) | `0100A5C00D162000` | 1.3.7 | Unity 2017.4.9f1 IL2CPP • **NVN** | **8 GB** | A18+ (8GB) | Playable |
| [DARK SOULS: REMASTERED](dm/games/01004AB00A260000/README.md) | `01004AB00A260000` | 1.0.3 | FromSoftware's engine • **NVN** | **6 GB** | A17 Pro+ (8GB) | ⚡ **60 fps with 1.0.3** |
| [DAVE THE DIVER](dm/games/010097F018538000/README.md) | `010097F018538000` | 1.0.6.1267 | Unity 6000.0.52f1 IL2CPP, FMOD • **NVN** | **4 GB** | A17 Pro+ (8GB) | Playable |
| [Dead Cells](dm/games/0100646009FBE000/README.md) | `0100646009FBE000` | 1.25.0 | Heaps / HashLink (HL/C) • **NVN** | **8 GB** | A17 Pro+ (8GB) | Playable |
| [Digimon Story Cyber Sleuth: Complete Edition](dm/games/010014E00DB56000/README.md) | `010014E00DB56000` | 1.0.3 | Media.Vision MVGL • **OpenGL** | **4 GB** | A17 Pro+ (8GB) | Playable |
| [Donkey Kong Bananza](dm/games/040074A01BF12000/README.md) | `040074A01BF12000` | v458752 (Switch 2) | Nintendo EPD (sead / agl / gsys) • **NVN2** | **16 GB** | Mac only (Switch 2) | Switch 2, Mac only, from a dump |
| [Splatoon Raiders](dm/games/0400380020056000/README.md) | `0400380020056000` | v65536 (Switch 2) | Nintendo EPD (sead / agl / gsys) • **NVN2** | **16 GB** | Mac only (Switch 2) | Switch 2, Mac only, from a dump |
| [Star Fox](dm/games/0400E88025B1A000/README.md) | `0400E88025B1A000` | v131072 (Switch 2) | Its own engine (`vrender`, `vfs`), Wwise • **NVN2** | **16 GB** | Mac only (Switch 2) | Switch 2, Mac only, from a NUP |
| [Donkey Kong Country Returns HD](dm/games/01009D901BC56000/README.md) | `01009D901BC56000` | 1.1.0 | Unity 6000.0.28f1 IL2CPP • **NVN** | **8 GB** | A17 Pro+ (8GB) | Playable |
| [Donkey Kong Country: Tropical Freeze](dm/games/0100C1F0051B6000/README.md) | `0100C1F0051B6000` | 1.0.2 | Retro Studios' engine • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [DRAGON BALL: Sparking! ZERO](dm/games/010035F022078000/README.md) | `010035F022078000` | 2.0.76 | Unreal Engine 5.1.1, CRIWARE • **NVN** | **16 GB** | A18 Pro (8GB) | ⚡ **60 fps, up to 120 on the Mac** |
| [DRAGON QUEST BUILDERS 2](dm/games/010042000A986000/README.md) | `010042000A986000` | 1.7.3d | Koei Tecmo's KTGL • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [DRAGON QUEST I & II HD-2D Remake](dm/games/0100D7C01F254000/README.md) | `0100D7C01F254000` | 1.0.2 | Unreal Engine 4.27.2 • **NVN** | **16 GB** | A18 Pro (8GB) | Playable |
| [DRAGON QUEST III HD-2D Remake](dm/games/01003E601E324000/README.md) | `01003E601E324000` | 1.1.2 | Unreal Engine 4.27 • **NVN** | **16 GB** | A18 Pro (8GB) | ⚡ **60 fps with 1.1.2** |
| [DRAGON QUEST VII Reimagined](dm/games/0100A9D01C446000/README.md) | `0100A9D01C446000` | 1.2.0 | Unreal Engine 4.27 • **NVN** | **16 GB** | A18 Pro (8GB) | ⚡ **60 fps with 1.2.0** |
| [DRAGON QUEST XI S: Echoes of an Elusive Age – Definitive Edition](dm/games/01006C300E9F0000/README.md) | `01006C300E9F0000` | 1.0.4 | Unreal Engine 4.18 • **NVN** | **16 GB** | A18 Pro (8GB) | ⚡ **60 fps with 1.0.4** |
| [EA SPORTS FC 27](dm/games/0100C49025D3E000/README.md) | `0100C49025D3E000` | 1.8d.310c | Frostbite 2025.1.2 (its NVN renderer in an NRO) • **NVN** | **16 GB** | A18 Pro (8GB) | ⚡ **60 fps with 1.8d.310c** |
| [FINAL FANTASY CRYSTAL CHRONICLES Remastered Edition](dm/games/0100CE4010AAC000/README.md) | `0100CE4010AAC000` | 1.0.3 | Unity 2018.4.2f1 IL2CPP, FMOD • **NVN** | **16 GB** | A18 Pro (8GB) | Playable |
| [FINAL FANTASY RESONANCE](dm/games/0100606026F12000/README.md) | `0100606026F12000` | 1.0.1 | Unreal Engine 5.6.1 • **NVN** | **16 GB** | A18 Pro (8GB) | ⚡ **60 fps with 1.0.1** |
| [FINAL FANTASY RESONANCE, Asian release](dm/games/0100B8A026F14000/README.md) | `0100B8A026F14000` | 1.0.1 | Unreal Engine 5.6.1 • **NVN** | **16 GB** | A18 Pro (8GB) | Playable |
| [FINAL FANTASY TACTICS - The Ivalice Chronicles](dm/games/010038B015560000/README.md) | `010038B015560000` | 1.4.0 | Square Enix's engine • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [FINAL FANTASY X/X-2 HD Remaster](dm/games/0100BC300CB48000/README.md) | `0100BC300CB48000` | 1.0.0 (base) | PhyreEngine (Virtuos) • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [Fire Emblem Engage](dm/games/0100A6301214E000/README.md) | `0100A6301214E000` | 2.0.0 | Unity 2020.3.18f1 IL2CPP, Wwise • **NVN** | **16 GB** | A18 Pro (8GB) | ⚡ **60 fps with 2.0.0** |
| [Fire Emblem Fortune's Weave](dm/games/04007EF01F8AE000/README.md) | `04007EF01F8AE000` | v131072 (Switch 2) | Intelligent Systems' engine, NintendoWare • **NVN2** | **16 GB** | Mac only (Switch 2) | Switch 2, Mac only, from a dump, up to 120 fps |
| [Fire Emblem: Three Houses](dm/games/010055D009F78000/README.md) | `010055D009F78000` | 1.2.0 | Koei Tecmo's KTGL • **NVN** | **8 GB** | A18+ (8GB) | ⚡ **60 fps with 1.2.0** |
| [Ghost Trick: Phantom Detective](dm/games/010029B018432000/README.md) | `010029B018432000` | 1.0.0 (base) | Capcom's RE Engine, Wwise • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [Hades](dm/games/0100535012974000/README.md) | `0100535012974000` | 1.0.38233 | Supergiant Games' engine (The Forge) • **Vulkan** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [Hades II](dm/games/0100A00019DE0000/README.md) | `0100A00019DE0000` | base game | Supergiant Games' engine • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [Hollow Knight](dm/games/0100633007D48000/README.md) | `0100633007D48000` | 1.5.12620 | Unity 6000.0.61f1 IL2CPP, FMOD • **NVN** | **4 GB** | A17 Pro+ (8GB) | Playable |
| [Hollow Knight: Silksong](dm/games/010013C00E930000/README.md) | `010013C00E930000` | 1.0.30000 | Unity 6000.0.50f1 IL2CPP • **NVN** | **4 GB** | A17 Pro+ (8GB) | Playable |
| [Hyrule Warriors: Age of Calamity](dm/games/01002B00111A2000/README.md) | `01002B00111A2000` | 1.3.0 | Koei Tecmo's KTGL • **NVN** | **6 GB** | A17 Pro+ (8GB) | ⚡ **60 fps with 1.3.0** |
| [Hyrule Warriors: Age of Imprisonment](dm/games/04003F40232DE000/README.md) | `04003F40232DE000` | v196608 (Switch 2) | Koei Tecmo's KTGL • **NVN2** | **16 GB** | Mac only (Switch 2) | Switch 2, Mac only, from a NUP |
| [Hyrule Warriors: Definitive Edition](dm/games/0100AE00096EA000/README.md) | `0100AE00096EA000` | 1.0.1 | Koei Tecmo's KTGL • **NVN** | **8 GB** | A18+ (8GB) | Playable |
| [Kirby Air Riders](dm/games/040077201BE50000/README.md) | `040077201BE50000` | v458752 (Switch 2) | Its own engine (`phx`, `Aurora`) • **NVN2** | **16 GB** | Mac only (Switch 2) | Switch 2, Mac only, from a NUP |
| [Kirby and the Forgotten Land](dm/games/01004D300C5AE000/README.md) | `01004D300C5AE000` | 1.1.0 | HAL Laboratory's engine (NintendoWare) • **NVN** | **8 GB** | A18+ (8GB) | Playable |
| [Kirby Star Allies](dm/games/01007E3006DDA000/README.md) | `01007E3006DDA000` | 4.0.0a | HAL Laboratory's engine (NintendoWare) • **NVN** | **8 GB** | A18+ (8GB) | Playable |
| [Luigi's Mansion 3](dm/games/0100DCA0064A6000/README.md) | `0100DCA0064A6000` | 1.4.0 | Next Level Games' engine • **NVN** | **6 GB** | A17 Pro+ (8GB) | ⚡ **60 fps with 1.4.0** |
| [Mario & Luigi: Brothership](dm/games/01006D0017F7A000/README.md) | `01006D0017F7A000` | 1.0.0 | Unreal Engine 4.27.2, Wwise • **NVN** | **16 GB** | A18 Pro (8GB) | up to 120 fps |
| [Mario Kart World](dm/games/0400C3F00006E000/README.md) | `0400C3F00006E000` | v0 (Switch 2) | Nintendo EPD (sead / agl / gsys, Pia) • **NVN2** | **16 GB** | Mac only (Switch 2) | Switch 2, Mac only, from a dump |
| [Mario Tennis Fever](dm/games/0400D4201C6EA000/README.md) | `0400D4201C6EA000` | v327680 (Switch 2) | Camelot's engine, NintendoWare • **NVN2** | **16 GB** | Mac only (Switch 2) | Switch 2, Mac only, from a dump |
| [Mario Kart 8 Deluxe](dm/games/0100152000022000/README.md) | `0100152000022000` | 4.0.0, 4.0.1 | Nintendo (sead / agl / gsys, NintendoWare, Pia) • **NVN** | **6 GB** | A17 Pro+ (8GB) | no Mii heads |
| [Mario + Rabbids Kingdom Battle](dm/games/010067300059A000/README.md) | `010067300059A000` | 1.9.589692 | Ubisoft Snowdrop • **NVN** | **16 GB** | A18 Pro (8GB) | Playable |
| [Mario + Rabbids Sparks of Hope](dm/games/0100317013770000/README.md) | `0100317013770000` | 1.6.2225577 | Ubisoft Snowdrop • **NVN** | **16 GB** | A18 Pro (8GB) | Playable |
| [Mario Party Superstars](dm/games/01006FE013472000/README.md) | `01006FE013472000` | 1.1.1 | NintendoWare Bezel Engine 1.55 • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [Mario vs. Donkey Kong](dm/games/0100B99019412000/README.md) | `0100B99019412000` | 1.0.1 (cartridge base) | Nintendo (sead / agl / gsys) • **NVN** | **4 GB** | A17 Pro+ (8GB) | Playable |
| [Metroid Dread](dm/games/010093801237C000/README.md) | `010093801237C000` | 2.1.0 | MercurySteam's engine • **NVN** | **4 GB** | A17 Pro+ (8GB) | Playable |
| [Metroid Prime Remastered](dm/games/010012101468C000/README.md) | `010012101468C000` | 1.0.0 (base) | Retro Studios' engine • **NVN** | **8 GB** | A18+ (8GB) | Playable |
| [Minecraft Dungeons II](dm/games/0100A7C01B792000/README.md) | `0100A7C01B792000` | 1.1.3.0 | Unreal Engine 5, Wwise, Havok • **NVN** | **16 GB** | A18 Pro (8GB) | Playable |
| [Monster Hunter Rise](dm/games/0100B04011742000/README.md) | `0100B04011742000` | 16.0.2 | Capcom's RE Engine • **NVN** | **6 GB** | A17 Pro+ (8GB) | ⚡ **60 fps with 16.0.2** |
| [Monster Train 2](dm/games/010051701FB46000/README.md) | `010051701FB46000` | 1.1.1 | Unity 2022.3.54f1 IL2CPP • **NVN** | **4 GB** | A17 Pro+ (8GB) | ⚡ **60 fps with 1.1.1** |
| [Need for Speed: Hot Pursuit Remastered](dm/games/010029B0118E8000/README.md) | `010029B0118E8000` | 1.0.3 | Criterion's engine (Stellar Entertainment port) • **NVN** | **6 GB** | A17 Pro+ (8GB) | ⚡ **60 fps with 1.0.3** |
| [NieR:Automata The End of YoRHa Edition](dm/games/010056B015FE8000/README.md) | `010056B015FE8000` | 1.0.3 | PlatinumGames' engine • **NVN** | **16 GB** | A18 Pro (8GB) | ⚡ **60 fps with 1.0.3** |
| [NieR:Automata The End of YoRHa Edition, Asian release](dm/games/0100B8E016F76000/README.md) | `0100B8E016F76000` | 1.0.3 | PlatinumGames' engine • **NVN** | **16 GB** | A18 Pro (8GB) | Playable |
| [OCTOPATH TRAVELER](dm/games/010057D006492000/README.md) | `010057D006492000` | 1.0.5 | Unreal Engine 4.18 • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [Octopath Traveler 0](dm/games/01005270232F2000/README.md) | `01005270232F2000` | 1.0.5 | Unreal Engine 5 • **NVN** | **4 GB** | A17 Pro+ (8GB) | ⚡ **60 fps with 1.0.5** |
| [OCTOPATH TRAVELER II](dm/games/0100A3501946E000/README.md) | `0100A3501946E000` | 1.1.1 | Unreal Engine 4.27 • **NVN** | **16 GB** | A18 Pro (8GB) | ⚡ **60 fps with 1.1.1** |
| [ŌKAMI HD](dm/games/0100276009872000/README.md) | `0100276009872000` | 1.0.0 (base) | Clover Studio's PS2 engine, remastered; CRIWARE • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [Paper Mario: The Origami King](dm/games/0100A3900C3E2000/README.md) | `0100A3900C3E2000` | 1.0.1 | Intelligent Systems' engine on NintendoWare • **NVN** | **16 GB** | A18 Pro (8GB) | Playable |
| [Paper Mario: The Thousand-Year Door](dm/games/0100ECD018EBE000/README.md) | `0100ECD018EBE000` | 1.0.1 | Intelligent Systems' engine on NintendoWare • **NVN** | **8 GB** | A17 Pro+ (8GB) | ⚡ **60 fps with 1.0.1** |
| [Patrick's Parabox](dm/games/0100E44016C22000/README.md) | `0100E44016C22000` | 1.0.1 | Unity 2020.3.30f1 IL2CPP • **NVN** | **4 GB** | A17 Pro+ (8GB) | Playable |
| [Persona 4 Golden](dm/games/010062B01525C000/README.md) | `010062B01525C000` | 1.0.2 | Atlus in-house (CRI middleware) • **NVN** | **4 GB** | A17 Pro+ (8GB) | Playable |
| [Persona 5 Royal](dm/games/01005CA01580E000/README.md) | `01005CA01580E000` | 1.0.2 | Atlus GFD / Needle (CRI middleware) • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [Pikmin 4](dm/games/0100B7C00933A000/README.md) | `0100B7C00933A000` | 1.1.1 | Unreal Engine 4.26.2 • **NVN** | **16 GB** | A18 Pro (8GB) | ⚡ **60 fps, up to 120 on the Mac** |
| [Pokémon Brilliant Diamond](dm/games/0100000011D90000/README.md) | `0100000011D90000` | 1.3.0 | Unity 2019.4.27f1 IL2CPP • **NVN** | **8 GB** | A17 Pro+ (8GB) | ⚡ **60 fps with 1.3.0** |
| [Pokémon Legends: Arceus](dm/games/01001F5010DFA000/README.md) | `01001F5010DFA000` | 1.1.1 | Game Freak's engine (between Sword's and Trinity) • **NVN** | **16 GB** | A18 Pro (8GB) | Playable |
| [Pokémon Legends: Z-A](dm/games/0100F43008C44000/README.md) | `0100F43008C44000` | 2.0.2 | Game Freak's Trinity engine • **NVN** | **16 GB** | A18 Pro (8GB) | Playable |
| [Pokémon Pokopia](dm/games/0400A3A01EE4C000/README.md) | `0400A3A01EE4C000` | v655360 (Switch 2) | Koei Tecmo's KTGL • **NVN2** | **16 GB** | Mac only (Switch 2) | Switch 2, Mac only, from a dump |
| [Pokémon Scarlet](dm/games/0100A3D008C5C000/README.md) | `0100A3D008C5C000` | 1.0.0 | Game Freak's Trinity engine • **NVN** | **16 GB** | A18 Pro (8GB) | Playable |
| [Pokémon Shield](dm/games/01008DB008C2C000/README.md) | `01008DB008C2C000` | 1.3.2 | Game Freak's engine (before Trinity) • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [Pokémon Sword](dm/games/0100ABF008968000/README.md) | `0100ABF008968000` | 1.3.2 | Game Freak's engine (before Trinity) • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [Pokémon Violet](dm/games/01008F6008C5E000/README.md) | `01008F6008C5E000` | 1.0.0 | Game Freak's Trinity engine • **NVN** | **16 GB** | A18 Pro (8GB) | Playable |
| [Portal](dm/games/01007BB017812000/README.md) | `01007BB017812000` | 1.0.3 | Valve's Source engine (28 NROs) • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [Portal 2](dm/games/0100ABD01785C000/README.md) | `0100ABD01785C000` | 1.0.3 | Valve's Source engine (21 NROs) • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [Princess Peach: Showtime!](dm/games/01007A3009184000/README.md) | `01007A3009184000` | 1.0.0 | Unreal Engine 4.27 (Good-Feel), Wwise • **NVN** | **16 GB** | A18 Pro (8GB) | ⚡ **60 fps with 1.0.0** |
| [Raging Loop](dm/games/010020400E1C2000/README.md) | `010020400E1C2000` | 1.0.0 (base) | Unity 2018.3.10f1 IL2CPP • **NVN** | **4 GB** | A17 Pro+ (8GB) | Playable |
| [Return of the Obra Dinn](dm/games/010032E00E6E2000/README.md) | `010032E00E6E2000` | 1.0.1 | Unity 2017.4.28f1 IL2CPP • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [Rhythm Heaven Groove](dm/games/0100D9F01D474000/README.md) | `0100D9F01D474000` | 1.0.0 (base) | Nintendo's own 2D engine • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [ROMANCE OF THE THREE KINGDOMS 8 REMAKE](dm/games/0100C2A01A730000/README.md) | `0100C2A01A730000` | 1.1.3 | Koei Tecmo's KTGL • **NVN** | **6 GB** | A17 Pro+ (8GB) | controller only |
| [Sea of Stars](dm/games/01008C0016544000/README.md) | `01008C0016544000` | 2.0.59001 | Unity 2021.3.25f1 IL2CPP • **NVN** | **8 GB** | A17 Pro+ (8GB) | Playable |
| [SHIN MEGAMI TENSEI V: Vengeance](dm/games/010069C01AB82000/README.md) | `010069C01AB82000` | 1.0.3 | Unreal Engine 4.27 • **NVN** | **16 GB** | A18 Pro (8GB) | ⚡ **60 fps with 1.0.3** |
| [Silver Pines](dm/games/0100D5B026844000/README.md) | `0100D5B026844000` | 1.0.0 (base) | Unity 6000.3.15f1 IL2CPP • **NVN** | **8 GB** | A17 Pro+ (8GB) | Playable |
| [Sonic Superstars](dm/games/01008F701C074000/README.md) | `01008F701C074000` | 1.1.8 | Unity 2021.3.25f1 IL2CPP, CRIWARE, FMOD • **NVN** | **8 GB** | A17 Pro+ (8GB) | Playable |
| [STEINS;GATE RE:BOOT](dm/games/01008BC024FDE000/README.md) | `01008BC024FDE000` | 1.0.3 | M2's ADV engine • **NVN** | **4 GB** | A17 Pro+ (8GB) | Playable |
| [Stardew Valley](dm/games/0100E65002BB8000/README.md) | `0100E65002BB8000` | 1.6.15.13 | MonoGame (C# → C++ by BRUTE) • **NVN** | **4 GB** | A17 Pro+ (8GB) | Playable |
| [SteamWorld Dig](dm/games/01009320084A4000/README.md) | `01009320084A4000` | 1.12.0 | Image & Form's own engine (SteamWorld) • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [SteamWorld Dig 2](dm/games/0100CA9002322000/README.md) | `0100CA9002322000` | 4.1.1 | Image & Form's own engine (SteamWorld) • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [SteamWorld Heist II](dm/games/010089C01E9CA000/README.md) | `010089C01E9CA000` | 1.5.1 | Thunderful's own engine (SteamWorld) • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [SteamWorld Heist: Ultimate Edition](dm/games/010016100A186000/README.md) | `010016100A186000` | 2.2.1 | Image & Form's own engine (SteamWorld) • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [Streets of Rage 4](dm/games/0100EC9010258000/README.md) | `0100EC9010258000` | 1.0.9 | MonoGame (C# → C++ by BRUTE) • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [Subnautica](dm/games/0100429011144000/README.md) | `0100429011144000` | 1.23.83358 | Unity 2019.4.36f1 IL2CPP, FMOD • **NVN** | **4 GB** | A17 Pro+ (8GB) | Playable |
| [Subnautica: Below Zero](dm/games/010014C011146000/README.md) | `010014C011146000` | 1.23.55063 | Unity 2019.4.36f1 IL2CPP, FMOD • **NVN** | **4 GB** | A17 Pro+ (8GB) | Playable |
| [Super Mario 3D All-Stars](dm/games/010049900F546000/README.md) | `010049900F546000` | 1.1.4 | a launcher (sead / agl), [Super Mario 64](010049900F546001/README.md) (Nintendo's N64 layer), [Super Mario Sunshine](010049900F546002/README.md) (NERD's Hagi); Galaxy is 32-bit ARM • **NVN, Vulkan** | **6 GB** | A17 Pro+ (8GB) | Super Mario 64 and Sunshine; Galaxy is 32-bit ARM, which Apple silicon cannot run |
| [Super Mario 3D World + Bowser's Fury](dm/games/010028600EBDA000/README.md) | `010028600EBDA000` | 1.2.2 | Nintendo EPD (sead / agl, NintendoWare) • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [Super Mario Bros. Wonder](dm/games/010015100B514000/README.md) | `010015100B514000` | 1.2.1 (and 1.0.0) | Nintendo EPD (sead / agl) • **NVN** | **8 GB** | A17 Pro+ (8GB) | Playable |
| [Super Mario Galaxy](dm/games/010099C022B96000/README.md) | `010099C022B96000` | 1.3.1 | NERD's Hagi Wii layer (recompiled PowerPC) • **Vulkan** | **4 GB** | A17 Pro+ (8GB) | Playable |
| [Super Mario Galaxy 2](dm/games/0100FD8022DAA000/README.md) | `0100FD8022DAA000` | 1.4.0 | NERD's Hagi Wii layer (recompiled PowerPC) • **Vulkan** | **4 GB** | A17 Pro+ (8GB) | Playable |
| [Super Mario Odyssey](dm/games/0100000000010000/README.md) | `0100000000010000` | 1.4.1 | Nintendo EPD (sead / agl, NintendoWare) • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [Super Mario Party Jamboree](dm/games/0100965017338000/README.md) | `0100965017338000` | 2.3.0 | NintendoWare Bezel Engine 2.9 • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [Super Mario RPG](dm/games/0100BC0018138000/README.md) | `0100BC0018138000` | 1.0.1 | Unity 2021.3.15f1 IL2CPP, CRIWARE • **NVN** | **4 GB** | A17 Pro+ (8GB) | Playable |
| [Super Monkey Ball Banana Rumble](dm/games/010031F019294000/README.md) | `010031F019294000` | 2.20 | Unity 2022.3.30f1 IL2CPP, CRIWARE, FMOD • **NVN** | **4 GB** | A17 Pro+ (8GB) | Playable |
| [SUPER ROBOT WARS Y](dm/games/010063301BD50000/README.md) | `010063301BD50000` | 1.4.1 | Unity 2022.3.44f1 IL2CPP, CRIWARE • **NVN** | **4 GB** | A17 Pro+ (8GB) | Playable |
| [Super Smash Bros. Ultimate](dm/games/01006A800016E000/README.md) | `01006A800016E000` | 13.0.5 | Bandai Namco / Sora's engine • **NVN** | **8 GB** | A18+ (8GB) | offline |
| [Taiko Risshiden V DX](dm/games/0100346017304000/README.md) | `0100346017304000` | 1.1.1 | Koei Tecmo's KTGL • **NVN** | **4 GB** | A17 Pro+ (8GB) | 👆 *Japanese · played by touch* |
| [Team Sonic Racing](dm/games/010092B0091D0000/README.md) | `010092B0091D0000` | 1.0.3 | Sumo Digital's engine, Wwise • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [The Great Ace Attorney Chronicles](dm/games/010036E00FB20000/README.md) | `010036E00FB20000` | 1.0.0 (base) | Capcom's MT Framework • **NVN** | **4 GB** | A17 Pro+ (8GB) | Playable |
| [The Legend of Zelda: Breath of the Wild](dm/games/01007EF00011E000/README.md) | `01007EF00011E000` | 1.9.0 | Nintendo EPD (sead / agl / gsys / ksys, Havok) • **NVN** | **8 GB** | A18+ (8GB) | ⚡ **60 fps with 1.9.0** |
| [The Legend of Zelda: Echoes of Wisdom](dm/games/01008CF01BAAC000/README.md) | `01008CF01BAAC000` | 1.1.0 | NintendoWare (G3d / Ui2d / Vfx) • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [The Legend of Zelda: Link's Awakening](dm/games/01006BB00C6F0000/README.md) | `01006BB00C6F0000` | 1.1.0 | Grezzo's engine on NintendoWare • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [The Legend of Zelda: Ocarina of Time](dm/games/0400486024DEC000/README.md) | `0400486024DEC000` | v131072 (Switch 2) | Nintendo EPD's sead, agl, gsys, Havok, CRIWARE • **NVN2** | **16 GB** | Mac only (Switch 2) | Switch 2, Mac only, from a NUP |
| [The Legend of Zelda: Skyward Sword HD](dm/games/01002DA013484000/README.md) | `01002DA013484000` | 1.0.1 | Nintendo's Wii-era engine, ported by Tantalus • **NVN** | **4 GB** | A17 Pro+ (8GB) | Playable |
| [The Legend of Zelda: Tears of the Kingdom](dm/games/0100F2C0115B6000/README.md) | `0100F2C0115B6000` | 1.4.3 | Nintendo EPD (sead / agl / gsys) • **NVN** | **16 GB** | A18 Pro (8GB) | ⚡ **60 fps with 1.4.3** |
| [TRIANGLE STRATEGY](dm/games/0100CC80140F8000/README.md) | `0100CC80140F8000` | 1.1.1 | Unreal Engine 4.27 • **NVN** | **16 GB** | A18 Pro (8GB) | ⚡ **60 fps with 1.1.1** |
| [Unicorn Overlord](dm/games/010069401ADB8000/README.md) | `010069401ADB8000` | 1.05 | Vanillaware's engine • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [Unicorn Overlord, Asian release](dm/games/010054B01AD92000/README.md) | `010054B01AD92000` | 1.05 | Vanillaware's engine • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [Well Dweller](dm/games/0100217023F6C000/README.md) | `0100217023F6C000` | 1.0.0 | GameMaker Studio 2 (its runner) • **OpenGL** | **6 GB** | A17 Pro+ (8GB) | Playable |
| [Xenoblade Chronicles: Definitive Edition](dm/games/0100FF500E34A000/README.md) | `0100FF500E34A000` | 1.1.2 | Monolith's engine • **NVN** | **8 GB** | A18+ (8GB) | Playable |
| [Xenoblade Chronicles 2](dm/games/0100E95004038000/README.md) | `0100E95004038000` | 2.1.0 | Monolith's engine • **NVN** | **8 GB** | A18+ (8GB) | Playable |
| [Xenoblade Chronicles 3](dm/games/010074F013262000/README.md) | `010074F013262000` | 2.2.1 | Monolith's engine • **NVN** | **16 GB** | A18 Pro (8GB) | Playable |
| [Yoshi and the Mysterious Book](dm/games/0400245021D2C000/README.md) | `0400245021D2C000` | 1.0.2 (Switch 2) | Unreal Engine 5.4.4 • **NVN2** | **16 GB** | Mac only (Switch 2) | Switch 2, Mac only |
| [Yoshi's Crafted World](dm/games/01006000040C2000/README.md) | `01006000040C2000` | 1.0.1 | Unreal Engine 4.18 era (Good-Feel) • **NVN** | **6 GB** | A17 Pro+ (8GB) | Playable |

---
## 🚀 Platform Features Timeline (Newest to Oldest)

A complete, deduplicated chronology of every milestone and capability introduced to the NxNative platform:

### 🌟 Current Build (v1.9.7 / Latest) — *November 2026*
> **The Legend of Zelda: Ocarina of Time (Switch 2), Bundled ZBIC NSO Decompression & 144+ Native macOS Games**

- **The Legend of Zelda: Ocarina of Time (`0400486024DEC000` - Switch 2) Support**: Full Switch 2 profile (`v0` & `v131072`), NVN2 task/mesh shader translation to Metal, Ampere `F2IP`/`LDSM` fixes, NDVE compute movie scaling, `pool_skip_retired` scene transition memory optimization, Kokiri Forest GPU heightmap preservation, and SDK 22 Ocarina note-playing service stubs.
- **Bundled `zbic` Module for SDK 22+ Switch 2 Games**: Pre-bundled `zbic` in the isolated standalone Python runtime and added prerequisite verification so ZBIC-compressed NSOs (`ExeFS/main`) unpack out of the box.
- **144+ Verified Native macOS & iOS Games**: Expanded catalog covering 10 Nintendo Switch 2 titles (`0400...`) and 134+ Nintendo Switch 1 titles (`0100...`).

### 🌟 v1.8.3 — *October 2026*
> **macOS Game Mode, Game Launch Fix, Auto-Signing & Mouse Drag & Drop**

- **macOS Game Mode (Modo Jogo)**: Every ported game automatically triggers macOS Game Mode via native fullscreen and game category metadata, maximizing CPU/GPU performance and minimizing Bluetooth latency for controllers and AirPods.
- **Game Launch Fix & Code Signing Pipeline**: Eliminated the infinite launching state by fixing host compilation profiles, passing `DM_LAUNCHER=0`, and adding automatic ad-hoc re-signing (`codesign --force --deep --sign -`) to bypass macOS Gatekeeper seals.
- **Mouse Drag & Drop Library Organization**: Reorder game cards directly on the Switch Dark Mode console carousel with mouse drag & drop, automatically persisted to local storage.
- **Modal Input Focus Lock**: Automatically disables keyboard/gamepad navigation hotkeys when modals or text inputs are active, preventing accidental triggers.
- **14 Locales with Alphabetical Settings**: Added European Portuguese (`Português de Portugal - PT-PT`) alongside PT-BR, EN, JA, ES, FR, DE, IT, KO, PL, RU, SV, ZH-Hans, ZH-Hant, neatly sorted alphabetically in Settings.

### 🌟 v1.8.2 — *October 2026*
> **Embedded Standalone Runtime, Python 3.15 Fix & iCloud Sync Toggle**

- **Isolated Standalone Runtime**: Bundles relocatable Python 3.13 and pre-compiled native binaries (zstd, spirv-cross, glslangValidator, xcodegen). Zero Homebrew or terminal setup required for end-users.
- **Python 3.15 Incompatibility Resolution**: Fixed clang build failure (`lz4` C-extension) by resolving deterministic Python 3.13 runtimes and pre-bundling universal binary wheels.
- **iCloud Sync Toggle & Space Reclaim**: Complete user control over iCloud Drive synchronization. Backups are strictly kept on local storage with automated 5-snapshot pruning, plus a one-click button to reclaim iCloud cloud storage.
- **iOS Signing Identity & Profile Reset**: Added quick-clear actions for custom certificates (.p12) and provisioning profiles (.mobileprovision), alongside an explicit Unsigned / Sideloading mode.

### 🌟 v1.8.1 — *October 2026*
> **Official Joy-Con Taskbar Icon, Menu Bar Customization & iOS Sideloading Fixes**

- **Joy-Con Status Bar Icon**: Choose between the signature Switch Joy-Con silhouette and the classic launcher icon in the macOS menu bar.
- **iOS Deployment Enhancements**: Streamlined `xcrun devicectl` bundle installations and AirDrop packaging for iOS 26+.
- **Storage & Cache Diagnostics**: Real-time inspection of shader cache sizes, RomFS asset bundles, and Atmosphere LayeredFS mods.

### 🌟 v1.8.0 — *October 2026*
> **Apple Liquid Glass UI Overhaul & 13 Multi-Language Locales**

- **Apple Liquid Glass Aesthetic**: Modern translucent glassmorphism design optimized for macOS 26 Tahoe dark mode.
- **Runtime Localization Engine**: Zero-restart dynamic language switching across 13 international locales.
- **Automated Upstream Sync Workflows**: Continuous CI validation verifying compatibility with incoming `seedds/nxnative` upstream updates.

### 🌟 v1.7.0 — *October 2026*
> **Smart iCloud Cross-Save Synchronization & Single-Button Device Transfer**

- **Cross-Device iCloud Save Sync**: Automatic detection of `~/Library/Application Support/nxnative/<TID>/save` with cloud backup.
- **Single-Button Device Sync**: Instant transfer of game save states and Atmosphere mods between Mac and connected iPhone/iPad.
- **1-Click Finder Reveal**: Instant access to save folders and game directories from the Game Details deck.

### 🌟 v1.6.2 & v1.6.1 — *October 2026*
> **Automated Dependency Installer & Cross-Architecture Stability**

- **Automated In-App Environment Setup**: One-click installation of Homebrew, Python 3.12-3.14, and required toolchains (`libhac`, `zstandard`, `pycryptodome`, `lz4`).
- **Universal Toolchain Detection**: Automatic PATH resolution supporting both Apple Silicon `/opt/homebrew` and legacy paths.

### 🌟 v1.6.0 — *October 2026*
> **Direct iOS IPA Deployment & Audio Polish**

- **Dual Target Compilation**: Seamlessly output standalone macOS applications (`.app`) or iOS application archives (`.ipa`).
- **Console Audio Feedback**: Authentic UI sound effects and navigation feedback during controller and keyboard browsing.

### 🌟 v1.5.0 & v1.5.1 — *October 2026*
> **Switch Dark Mode 2-Tier Library & Full Gamepad Navigation**

- **Two-Tier Category Shelves**: Distinct visual shelves for macOS Native compiled games and iOS Sideloadable ports.
- **End-to-End Gamepad Navigation**: Browse the entire library, launch games, and adjust settings using a controller (D-Pad, Stick, Face Buttons).
- **Async High-Speed Library Scanner**: Indexes hundreds of gigabytes of game dumps in seconds with zero UI stutter.

### 🌟 v1.4.0 — *October 2026*
> **8 Neon Highlight Themes, Cumulative RAM Filters & Auto-Grouping**

- **8 Neon Personalization Themes**: Neon Blue, Neon Red, Cyberpunk Yellow, Emerald Green, Sakura Pink, Electric Purple, Sunset Orange, and Pure White.
- **Cumulative RAM Filtering**: Filter the compatibility catalog by memory requirements (4GB, 6GB, 8GB, 16GB+).
- **Automatic Base + Update + DLC Bundling**: Intelligent grouping of base game dumps with corresponding updates and expansion packs.

### 🌟 v1.3.0 — *October 2026*
> **Official High-Res Box Art Covers & Universal Gamepad Profiles**

- **Authentic Box Art Integration**: Automatic artwork matching via GameTDB and custom cover artwork picker (`.jpg`, `.png`, `.webp`).
- **Universal Controller Profiles**: Plug-and-play mapping presets for Switch Pro Controller, PlayStation DualSense / DualShock 4, and Xbox Wireless Controller.

### 🌟 v1.2.0 — *October 2026*
> **Encrypted Package Parsing & Safe Upstream Sync Utility**

- **Encrypted Container Inspection**: Direct extraction and Title ID identification for `.xci`, `.nsp`, and `.nsz` archives.
- **Safe Upstream Sync Script (`sync_upstream.sh`)**: Conflict-free merging mechanism for keeping the core engine synchronized with upstream.

### 🌟 v1.0.0 — *October 2026*
> **Initial Launch of the NxNative Graphical Interface**

- **3-Step Guided Porting Wizard**: Visual drag & drop porting eliminating terminal commands.
- **Metal 4 Shader Pipeline**: Ahead-of-time SPIR-V to Metal Shading Language compilation.
- **Native ARM64 Mach-O Host**: Direct execution of Switch game binaries on Apple Silicon.

---

## 🔄 How to Port an Unlisted Game

Want to run a game not currently listed in the catalog? Follow these steps:

1. **Open NxNative Launcher**: Navigate to the **Port** tab.
2. **Drag & Drop your Dump**: Drop your legally dumped `.nsp` or `.xci` folder. The launcher will automatically inspect its ExeFS and determine whether an upstream profile exists or can be provisioned.
3. **Contribute Upstream**: If the game runs cleanly, follow [CONTRIBUTING.md](CONTRIBUTING.md) to submit your `game.tsv` profile and screenshot to `seedds/nxnative`.

<div align="center">
  <a href="README.md"><b>⬅️ Back to Overview & Guide</b></a> &nbsp;&nbsp;|&nbsp;&nbsp;  <a href="CONTRIBUTING.md"><b>🤝 Read Contributing Guidelines</b></a>
</div>
