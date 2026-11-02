import Foundation

extension InputProfileManager {

    /// Synchronizes keyboard bindings, WASD/movement keys, and mouse-look settings from `source`
    /// across all controller profiles so keyboard changes apply globally to every game by default.
    public func syncKeyboardSettingsAcrossAllProfiles(from source: ControllerProfile) {
        var normalizedMovement = source.keyboardMovement
        if normalizedMovement["left"] == nil && source.keyboardBindings[0] == nil {
            normalizedMovement["left"] = 0
        }
        if normalizedMovement["up"] == nil && source.keyboardBindings[13] == nil {
            normalizedMovement["up"] = 13
        }
        if normalizedMovement["down"] == nil && source.keyboardBindings[1] == nil {
            normalizedMovement["down"] = 1
        }
        if normalizedMovement["right"] == nil && source.keyboardBindings[2] == nil {
            normalizedMovement["right"] = 2
        }

        for idx in profiles.indices {
            profiles[idx].keyboardBindings = source.keyboardBindings
            profiles[idx].keyboardMovement = normalizedMovement
            profiles[idx].mouseAsRightStick = source.mouseAsRightStick
            profiles[idx].mouseSensitivity = source.mouseSensitivity
            profiles[idx].mouseInvertX = source.mouseInvertX
            profiles[idx].mouseInvertY = source.mouseInvertY
            profiles[idx].mouseRightStickMode = source.mouseRightStickMode
            saveProfileToDisk(profiles[idx])
        }
        exportActiveMappingToDisk()
    }

    /// Generates the complete mapping dictionary including player slots 0..7
    public func exportCompositeDictionary(baseProfile: ControllerProfile? = nil, config: GameRuntimeConfig? = nil) -> [String: Any] {
        let base = baseProfile ?? activeProfile
        var dict = base.exportDictionary()

        var playersDict: [String: Any] = [:]
        for pIdx in 0..<8 {
            let pProfile: ControllerProfile
            if let cfg = config, let customId = cfg.playerProfileIds?[String(pIdx)],
               let uuid = UUID(uuidString: customId),
               let found = profiles.first(where: { $0.id == uuid }) {
                pProfile = found
            } else if pIdx == 0 && config?.controllerProfileId != nil,
                      let p0Id = config?.controllerProfileId,
                      let uuid = UUID(uuidString: p0Id),
                      let found = profiles.first(where: { $0.id == uuid }) {
                pProfile = found
            } else {
                pProfile = profile(forPlayer: pIdx)
            }
            playersDict[String(pIdx)] = pProfile.exportDictionary()
        }
        dict["players"] = playersDict
        return dict
    }

    /// Resolves the controller profile to use for a specific game (pinned per-game profile if configured, otherwise global active profile).
    public func resolveProfile(for game: PortedGame, config: GameRuntimeConfig? = nil) -> ControllerProfile {
        let resolvedConfig = config ?? GameRuntimeConfig.load(for: game)
        if let pid = resolvedConfig.controllerProfileId,
           let uuid = UUID(uuidString: pid),
           let matched = profiles.first(where: { $0.id == uuid }) {
            return matched
        }
        return activeProfile
    }

    /// Writes the resolved controller & keyboard mapping JSON directly into a specific game's `.app` bundle.
    public func exportMapping(for game: PortedGame, config: GameRuntimeConfig? = nil) {
        let profile = resolveProfile(for: game, config: config)
        let dict = exportCompositeDictionary(baseProfile: profile, config: config)
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]) else { return }

        let dmDir = game.url.appendingPathComponent("Contents/Resources/dm")
        if FileManager.default.fileExists(atPath: dmDir.path) {
            let target = dmDir.appendingPathComponent("input_mapping.json")
            try? data.write(to: target, options: [.atomic])
        }
    }

    /// Exports the global active mapping to Application Support and updates all installed game bundles,
    /// respecting any per-game pinned `controllerProfileId`.
    public func exportActiveMappingToDisk(libraryFolder: URL? = nil) {
        let fm = FileManager.default
        let globalDict = exportCompositeDictionary()
        guard let globalData = try? JSONSerialization.data(withJSONObject: globalDict, options: [.prettyPrinted]) else { return }

        // 1. Global mapping in Application Support
        try? globalData.write(to: globalMappingFile, options: [.atomic])

        // 2. Write to installed game bundles across all candidate library directories
        var candidateDirs: [URL] = []
        if let lib = libraryFolder {
            candidateDirs.append(lib)
        }
        if let savedLib = UserDefaults.standard.string(forKey: "NXNative_SavedLibraryFolder"),
           let savedURL = URL(string: savedLib) ?? URL(fileURLWithPath: savedLib) as URL? {
            candidateDirs.append(savedURL)
        }
        let nxPortsDir = fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications/NxPorts")
        candidateDirs.append(nxPortsDir)
        let rootGames = SystemDetector.shared.resolveRootDirectory().appendingPathComponent("Games")
        candidateDirs.append(rootGames)
        let defaultExternal = URL(fileURLWithPath: "/Volumes/SSD FN501 PRO/Emulations/Nx Ports")
        if fm.fileExists(atPath: defaultExternal.path) {
            candidateDirs.append(defaultExternal)
        }

        var visitedGames = Set<String>()
        for dir in candidateDirs {
            guard fm.fileExists(atPath: dir.path),
                  let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
                continue
            }
            for item in items where item.pathExtension == "app" {
                let canonicalPath = item.standardized.path
                guard !visitedGames.contains(canonicalPath) else { continue }
                visitedGames.insert(canonicalPath)

                let dmDir = item.appendingPathComponent("Contents/Resources/dm")
                guard fm.fileExists(atPath: dmDir.path) else { continue }

                let target = dmDir.appendingPathComponent("input_mapping.json")
                let dummyGame = PortedGame(
                    name: item.deletingPathExtension().lastPathComponent,
                    url: item,
                    platform: .macApp,
                    sizeBytes: 0,
                    modificationDate: Date()
                )
                let bundleCfg = GameRuntimeConfig.load(for: dummyGame)
                let gameDict = exportCompositeDictionary(baseProfile: resolvePinnedProfileForBundle(at: item), config: bundleCfg)
                if let gameData = try? JSONSerialization.data(withJSONObject: gameDict, options: [.prettyPrinted]) {
                    try? gameData.write(to: target, options: Data.WritingOptions.atomic)
                } else {
                    try? globalData.write(to: target, options: Data.WritingOptions.atomic)
                }
            }
        }
    }

    private func resolvePinnedProfileForBundle(at appURL: URL) -> ControllerProfile? {
        let envURL = appURL.appendingPathComponent("Contents/Resources/dm/env.txt")
        if let content = try? String(contentsOf: envURL, encoding: .utf8) {
            for line in content.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("DM_CONTROLLER_PROFILE_ID=") {
                    let pid = String(trimmed.dropFirst("DM_CONTROLLER_PROFILE_ID=".count)).trimmingCharacters(in: .whitespaces)
                    if let uuid = UUID(uuidString: pid),
                       let matched = profiles.first(where: { $0.id == uuid }) {
                        return matched
                    }
                }
            }
        }
        return nil
    }
}
