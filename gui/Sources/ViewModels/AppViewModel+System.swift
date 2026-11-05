import Foundation
import AppKit

extension AppViewModel {
    // MARK: - Dynamic Dock & Minimized Taskbar Icon
    public func updateDockIcon(userInitiated: Bool = false) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if !MenuBarManager.shared.isMinimizedToMenuBar {
                NSApplication.shared.setActivationPolicy(.regular)
            }
            
            let resName = self.iconAppearanceMode.resourceName
            let mode = self.iconAppearanceMode
            
            let url = Bundle.main.url(forResource: resName, withExtension: "png")
                ?? Bundle.main.url(forResource: resName, withExtension: "icns")
                ?? Bundle.main.url(forResource: "AppIcon-Default", withExtension: "png")
                ?? Bundle.main.url(forResource: "AppIcon", withExtension: "png")
                ?? Bundle.main.url(forResource: "AppIcon", withExtension: "icns")
            
            var image = url.flatMap { NSImage(contentsOf: $0) }
            if image == nil {
                image = AppIconCache.image(named: resName)
            }
            
            if let img = image {
                NSApplication.shared.applicationIconImage = img
                NSApplication.shared.dockTile.display()
                
                for window in NSApplication.shared.windows {
                    window.miniwindowImage = img
                    window.miniwindowTitle = "NxNative Launcher"
                }

                // Persist custom icon permanently on disk ONLY when explicitly initiated by the user
                if userInitiated {
                    let bundleURL = Bundle.main.bundleURL
                    let appBundlePath: String? = {
                        if bundleURL.pathExtension == "app" {
                            return bundleURL.path
                        }
                        let candidates = [
                            "/Volumes/SSD FN501 PRO/Emulations/NativePort/NxNative_Launcher.app",
                            "/Applications/NxNative_Launcher.app"
                        ]
                        return candidates.first { FileManager.default.fileExists(atPath: $0) }
                    }()

                    if let targetPath = appBundlePath {
                        let targetResName = resName
                        let isDefault = (mode == .default)
                        DispatchQueue.global(qos: .utility).async {
                            Self.persistAppIconToDisk(
                                appBundlePath: targetPath,
                                resourceName: targetResName,
                                iconImage: isDefault ? nil : img,
                                restartDock: true
                            )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Permanent App Icon Persistence on macOS
    private static func persistAppIconToDisk(
        appBundlePath: String,
        resourceName: String,
        iconImage: NSImage?,
        restartDock: Bool
    ) {
        let fm = FileManager.default
        let bundleURL = URL(fileURLWithPath: appBundlePath)
        let resourcesURL = bundleURL.appendingPathComponent("Contents/Resources")
        guard fm.fileExists(atPath: resourcesURL.path) else { return }

        let targetIcnsURL = resourcesURL.appendingPathComponent("AppIcon.icns")
        let sourceIcnsURL = resourcesURL.appendingPathComponent("\(resourceName).icns")

        // 1. Set the Finder custom icon via Apple's official API
        DispatchQueue.main.async {
            NSWorkspace.shared.setIcon(iconImage, forFile: appBundlePath, options: [])
        }

        // 2. Atomically update AppIcon.icns inside Contents/Resources
        if fm.fileExists(atPath: sourceIcnsURL.path) {
            do {
                if fm.fileExists(atPath: targetIcnsURL.path) {
                    try fm.removeItem(at: targetIcnsURL)
                }
                try fm.copyItem(at: sourceIcnsURL, to: targetIcnsURL)
            } catch {}
        }

        // 3. Update timestamps on Info.plist and app bundle
        let infoPlist = bundleURL.appendingPathComponent("Contents/Info.plist").path
        runProcessWithTimeout(executable: "/usr/bin/touch", arguments: [infoPlist, appBundlePath], timeoutSeconds: 1.0)

        // 4. Force LaunchServices to refresh registration for this bundle
        let lsregisterPath = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
        if fm.fileExists(atPath: lsregisterPath) {
            runProcessWithTimeout(executable: lsregisterPath, arguments: ["-f", appBundlePath], timeoutSeconds: 2.0)
        }

        // 5. Invalidate Finder file system cache
        DispatchQueue.main.async {
            NSWorkspace.shared.noteFileSystemChanged(appBundlePath)
        }

        // 6. Refresh macOS Dock icon cache if user actively changed the icon
        if restartDock {
            runProcessWithTimeout(executable: "/usr/bin/killall", arguments: ["Dock"], timeoutSeconds: 2.0)
        }
    }

    @discardableResult
    private static func runProcessWithTimeout(executable: String, arguments: [String], timeoutSeconds: Double = 2.0) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            let deadline = DispatchTime.now() + timeoutSeconds
            while process.isRunning && DispatchTime.now() < deadline {
                usleep(25_000) // 25ms polling
            }
            if process.isRunning {
                process.terminate()
                return false
            }
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    public func setupWindowMinimizeIconObserver() {
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, !MenuBarManager.isMinimized else { return }
            self.updateDockIcon()
        }
    }
    
    // MARK: - Compatibility
    public func loadCompatibleGames(forceRefresh: Bool = false) {
        isLoadingCompatibility = true
        CompatibilityService.shared.fetchCompatibleGames(localNxnativePath: nxnativePath) { [weak self] games, isOnline in
            guard let self = self else { return }
            self.compatibleGames = games
            self.isCompatibilityFromOnline = isOnline
            self.compatibilityLastUpdated = Date()
            self.isLoadingCompatibility = false
        }
    }
    
    public func cycleCompatibilityFilter(forward: Bool) {
        let ramFilters: [Int?] = [nil, 4, 6, 8, 16]
        SoundEffectService.shared.play(.focus)
        
        let currentIdx = ramFilters.firstIndex(where: { $0 == compatibilityRamFilter }) ?? 0
        if forward {
            let nextIdx = (currentIdx + 1) % ramFilters.count
            compatibilityRamFilter = ramFilters[nextIdx]
        } else {
            let prevIdx = (currentIdx - 1 + ramFilters.count) % ramFilters.count
            compatibilityRamFilter = ramFilters[prevIdx]
        }
    }
    
    // MARK: - Environment Detection
    public func detectEnvironment(customRyujinxDir: String? = nil) {
        if let savedKeys = UserDefaults.standard.string(forKey: StorageKeys.savedProdKeysPath),
           FileManager.default.fileExists(atPath: savedKeys),
           savedKeys.hasSuffix("prod.keys") {
            self.prodKeysPath = savedKeys
            self.prodKeysSource = "Saved Preference"
            self.isProdKeysValid = true
        } else if let keysResult = SystemDetector.shared.detectProdKeys(additionalSearchDir: customRyujinxDir) {
            self.prodKeysPath = keysResult.path
            self.prodKeysSource = keysResult.sourceName
            self.isProdKeysValid = keysResult.isValid
        } else {
            self.isProdKeysValid = false
            self.prodKeysSource = "Not Found"
        }
        
        let nxResult = SystemDetector.shared.detectNxnativeDirectory()
        self.nxnativePath = nxResult.path
        self.isNxnativeValid = nxResult.isValid
        
        refreshEnginePatches()
        refreshPrerequisites()
        detectMetalToolchain()
    }
    
    public func detectMetalToolchain() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let info = SystemDetector.shared.detectMetalToolchain(nxnativePath: self.nxnativePath)
            DispatchQueue.main.async {
                self.metalToolchainInfo = info
            }
        }
    }
    
    public func refreshEnginePatches() {
        guard !nxnativePath.isEmpty else { return }
        self.enginePatches = PatchService.shared.checkPatchStatuses(nxnativePath: nxnativePath)
    }
    
    public func applyEnginePatches() {
        guard !nxnativePath.isEmpty else { return }
        let (applied, skipped, errors) = PatchService.shared.applyPatchesIfNeeded(nxnativePath: nxnativePath) { [weak self] msg, ok in
            self?.logs.append(LogEntry(level: ok ? .success : .info, message: msg))
        }
        refreshEnginePatches()
        if !errors.isEmpty {
            self.logs.append(LogEntry(level: .warning, message: "Engine patches completed with notices: \(errors.joined(separator: ", "))"))
        } else {
            self.logs.append(LogEntry(level: .success, message: "Engine patches verified: \(applied) applied, \(skipped) already present."))
        }
    }
    
    public func installAppleCommandLineTools() {
        showCltInstallAlert = true
        installer.install(dependency: prerequisites.xcode) { [weak self] _ in
            self?.refreshPrerequisites()
        }
    }
    
    public func refreshPrerequisites() {
        isCheckingPrerequisites = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let res = SystemDetector.shared.checkPrerequisites()
            DispatchQueue.main.async {
                self?.prerequisites = res
                self?.isCheckingPrerequisites = false
            }
        }
    }
    
    public func cloneNxnativeRepository() {
        let dest = URL(fileURLWithPath: defaultInstallPath).appendingPathComponent("nxnative")
        isCloningRepository = true
        cloneErrorMessage = nil
        
        SystemDetector.shared.cloneNxnativeRepository(to: dest) { [weak self] success, output in
            guard let self = self else { return }
            self.isCloningRepository = false
            if success {
                PatchService.shared.applyPatchesIfNeeded(nxnativePath: dest.path)
                self.detectEnvironment()
                self.logs.append(LogEntry(level: .success, message: "nxnative repository cloned and compatibility patches applied."))
            } else {
                self.cloneErrorMessage = output
                self.logs.append(LogEntry(level: .error, message: "Failed to clone repository: \(output)"))
            }
        }
    }
    
    // MARK: - Tool Installer / Repair / Uninstall
    public func installAllMissingDependencies(openSheet: Bool? = nil) {
        let missing = prerequisites.missingList
        guard !missing.isEmpty else { return }
        let shouldOpenSheet = openSheet ?? (selectedTab != 4)
        if shouldOpenSheet {
            showInstallerSheet = true
        }
        isInstallingDependency = true
        installerLogs.removeAll()
        installerLogs.append("Installing \(missing.count) missing dependencies...")
        
        installer.installAll(dependencies: missing) { [weak self] success in
            self?.isInstallingDependency = false
            self?.refreshPrerequisites()
            if success {
                self?.logs.append(LogEntry(level: .success, message: "All missing dependencies installed successfully."))
            } else {
                self?.logs.append(LogEntry(level: .warning, message: "Some dependencies could not be installed."))
            }
        }
    }
    
    public func installDependency(_ dep: DependencyStatus) {
        showInstallerSheet = true
        isInstallingDependency = true
        installerLogs.removeAll()
        installerLogs.append("Installing \(dep.name)...")
        
        installer.install(dependency: dep) { [weak self] success in
            self?.isInstallingDependency = false
            self?.refreshPrerequisites()
            if success {
                self?.logs.append(LogEntry(level: .success, message: "\(dep.name) installed successfully."))
            } else {
                self?.logs.append(LogEntry(level: .error, message: "Failed to install \(dep.name)."))
            }
        }
    }
    
    public func repairDependency(_ dep: DependencyStatus) {
        showInstallerSheet = true
        isInstallingDependency = true
        installerLogs.removeAll()
        installerLogs.append("Repairing \(dep.name)...")
        
        installer.repair(dependency: dep) { [weak self] success in
            self?.isInstallingDependency = false
            self?.refreshPrerequisites()
            if success {
                self?.logs.append(LogEntry(level: .success, message: "\(dep.name) repaired successfully."))
            } else {
                self?.logs.append(LogEntry(level: .error, message: "Failed to repair \(dep.name)."))
            }
        }
    }
    
    public func confirmUninstall(_ dep: DependencyStatus) {
        self.dependencyToUninstall = dep
        self.showUninstallConfirm = true
    }
    
    public func executeUninstall() {
        guard let dep = dependencyToUninstall else { return }
        showUninstallConfirm = false
        showInstallerSheet = true
        isInstallingDependency = true
        installerLogs.removeAll()
        installerLogs.append("Uninstalling \(dep.name)...")
        
        installer.uninstall(dependency: dep) { [weak self] success in
            self?.isInstallingDependency = false
            self?.refreshPrerequisites()
            if success {
                self?.logs.append(LogEntry(level: .warning, message: "\(dep.name) was uninstalled."))
            } else {
                self?.logs.append(LogEntry(level: .error, message: "Failed to uninstall \(dep.name)."))
            }
        }
    }
    
    public func repairAllDependencies() {
        showInstallerSheet = true
        isInstallingDependency = true
        installerLogs.removeAll()
        installerLogs.append("Repairing all environment tools...")
        
        installer.repairAll(dependencies: prerequisites.list) { [weak self] success in
            self?.isInstallingDependency = false
            self?.refreshPrerequisites()
            if success {
                self?.logs.append(LogEntry(level: .success, message: "All environment tools repaired."))
            }
        }
    }
}
