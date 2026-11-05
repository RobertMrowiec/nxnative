import Foundation
import AppKit

extension AppViewModel {
    public func launchGame(_ game: PortedGame) {
        guard game.isPlayableLocally else {
            logs.append(LogEntry(level: .warning, message: "Cannot launch iOS IPA locally on Mac. Please deploy to an iPhone or iPad."))
            return
        }
        guard launchingGameId == nil else { return }
        launchingGameId = game.id
        SoundEffectService.shared.play(.launch)
        
        let targetGameId = game.id
        // Fail-safe Watchdog: guarantees launchingGameId is reset if launch stalls
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) { [weak self] in
            if self?.launchingGameId == targetGameId {
                self?.launchingGameId = nil
                SoundEffectService.shared.play(.error)
                self?.logs.append(LogEntry(level: .warning, message: "Launch watchdog cleared stuck launching state for \(game.name)."))
            }
        }
        
        recordLastPlayed(for: game)
        
        if game.platform == .nonSwitch {
            let openConfig = NSWorkspace.OpenConfiguration()
            openConfig.environment = ProcessInfo.processInfo.environment
            NSWorkspace.shared.openApplication(at: game.url, configuration: openConfig) { [weak self] runningApp, error in
                DispatchQueue.main.async {
                    self?.launchingGameId = nil
                    if let error = error {
                        SoundEffectService.shared.play(.error)
                        self?.logs.append(LogEntry(level: .error, message: "Failed to launch \(game.name): \(error.localizedDescription)"))
                    } else {
                        self?.runningGameTitle = game.name
                        self?.logs.append(LogEntry(level: .success, message: "Launched Mac native game: \(game.name)"))
                        if let app = runningApp {
                            let sessionStart = Date()
                            NotificationCenter.default.addObserver(
                                forName: NSWorkspace.didTerminateApplicationNotification,
                                object: nil,
                                queue: .main
                            ) { notif in
                                if let termApp = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                                   termApp.processIdentifier == app.processIdentifier {
                                    let elapsed = Date().timeIntervalSince(sessionStart)
                                    PlayTimeService.shared.recordSession(for: game, duration: elapsed)
                                }
                            }
                        }
                    }
                }
            }
            return
        }
        
        let config = GameRuntimeConfig.load(for: game)
        config.applyToDisk(for: game)
        InputProfileManager.shared.exportMapping(for: game, config: config)
        
        // Ensure iCloud Cross-Save is configured with cover art if iCloud Sync is enabled by user
        var savePath: String? = nil
        var cloudSyncPath: String? = nil
        if SaveSyncService.shared.isICloudSyncEnabled(for: game) && SaveSyncService.shared.isICloudDriveAvailable {
            let cover = GameCoverService.shared.coverImage(for: game)
            switch SaveSyncService.shared.ensureCloudSaveConfigured(for: game, cover: cover) {
            case .success(let cloudSaveDir):
                savePath = cloudSaveDir.path
                cloudSyncPath = SaveSyncService.shared.iCloudRootURL.path
            case .failure(let error):
                logs.append(LogEntry(level: .warning, message: "[iCloud] \(error.localizedDescription)"))
            }
        }
        
        // Auto-sync saves with connected device before launch if available
        SaveSyncService.shared.autoSyncOnLaunch(for: game) { [weak self] status, msg in
            if let status = status, status != .noSaves && status != .alreadyInSync {
                self?.logs.append(LogEntry(level: .info, message: "Auto-sync on launch: \(msg)"))
            }
            var env = config.toEnvironmentDict(savePath: savePath)
            if let csp = cloudSyncPath {
                env["DM_SAVE_SYNC"] = csp
            }
            let prof = InputProfileManager.shared.resolveProfile(for: game, config: config)
            let bundleMapping = game.url.appendingPathComponent("Contents/Resources/dm/input_mapping.json")
            if FileManager.default.fileExists(atPath: bundleMapping.path) {
                env["DM_INPUT_MAPPING"] = bundleMapping.path
            }
            env["DM_MOUSE_RIGHT_STICK"] = prof.mouseAsRightStick ? "1" : "0"
            env["DM_MOUSE_SENSITIVITY"] = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), prof.mouseSensitivity)
            env["DM_MOUSE_INVERT_X"] = prof.mouseInvertX ? "1" : "0"
            env["DM_MOUSE_INVERT_Y"] = prof.mouseInvertY ? "1" : "0"
            env["DM_RUMBLE"] = prof.enableRumble ? "1" : "0"
            env["DM_RUMBLE_GAIN"] = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), prof.rumbleStrength)
            env["DM_RUMBLE_FLOOR"] = prof.rumbleFloorBoost ? "0.22" : "0.0"
            LibraryScanner.shared.launchGame(at: game.url, env: env) { [weak self] success, error in
                DispatchQueue.main.async {
                    if success {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            if self?.launchingGameId == targetGameId {
                                self?.launchingGameId = nil
                            }
                        }
                        self?.runningGameTitle = game.name
                        self?.logs.append(LogEntry(level: .success, message: "Launched game: \(game.name)"))
                        MemoryOptimizer.shared.optimizeForBackground(viewModel: self)
                        
                        // Observe game termination to clear runningGameTitle, track playtime, and pack save.dmsync for iOS iCloud sync
                        if let runningApp = GameControllerService.shared.activeRunningGameApp {
                            let sessionStart = Date()
                            NotificationCenter.default.addObserver(
                                forName: NSWorkspace.didTerminateApplicationNotification,
                                object: nil,
                                queue: .main
                            ) { [weak self] notif in
                                if let termApp = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                                   termApp.processIdentifier == runningApp.processIdentifier {
                                    self?.runningGameTitle = nil
                                    let elapsed = Date().timeIntervalSince(sessionStart)
                                    PlayTimeService.shared.recordSession(for: game, duration: elapsed)
                                    if SaveSyncService.shared.isICloudSyncEnabled(for: game) {
                                        DispatchQueue.global(qos: .utility).async {
                                            _ = SaveSyncService.shared.writeDMSync(for: game)
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        // Immediately clear launching state on error so user is never locked out
                        if self?.launchingGameId == targetGameId {
                            self?.launchingGameId = nil
                        }
                        self?.runningGameTitle = nil
                        SoundEffectService.shared.play(.error)
                        let errMsg = error ?? "Unknown error"
                        self?.logs.append(LogEntry(level: .error, message: "Failed to launch game: \(errMsg)"))
                    }
                }
            }
        }
    }
    
    public func loadRuntimeConfig(for game: PortedGame) -> GameRuntimeConfig {
        let key = game.uniqueKey
        if let cached = runtimeConfigCache[key] {
            return cached
        }
        let loaded = GameRuntimeConfig.load(for: game)
        runtimeConfigCache[key] = loaded
        return loaded
    }
    
    public func saveRuntimeConfig(_ config: GameRuntimeConfig, for game: PortedGame) {
        runtimeConfigCache[game.uniqueKey] = config
        config.save(for: game)
        logs.append(LogEntry(level: .success, message: "Saved settings for \(game.name)"))
    }
}
