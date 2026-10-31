import Foundation
import AppKit

extension AppViewModel {
    // MARK: - Build Actions
    public var canStartBuild: Bool {
        !isBuilding &&
        selectedGameFolder != nil &&
        selectedGame != nil &&
        isProdKeysValid &&
        isNxnativeValid &&
        !isDiskSpaceLow
    }
    
    public func goToWizardStep(_ step: Int) {
        guard step >= 1 && step <= 3 else { return }
        if step == 2 && selectedGame == nil { return }
        buildWizardStep = step
    }
    
    public func resetWizard() {
        buildWizardStep = 1
        buildError = nil
        buildSuccessPath = nil
    }
    
    public func startBuild() {
        guard canStartBuild, let gameDir = selectedGameFolder, let sel = selectedGame else { return }
        
        buildWizardStep = 3
        isBuilding = true
        buildingGameId = sel.id
        buildError = nil
        buildSuccessPath = nil
        progressFraction = 0.0
        currentStageName = "Preparing Build..."
        currentStepName = ""
        stageIndex = 0
        totalStages = 0
        etaSeconds = nil
        buildStages.removeAll()
        logs.removeAll()
        
        var targetGameDirectory = gameDir
        let hasSubfolderFiles = sel.files.contains {
            $0.url.deletingLastPathComponent().standardizedFileURL != gameDir.standardizedFileURL
        }
        
        if sel.updateCount > 0 || sel.dlcCount > 0 {
            logs.append(LogEntry(
                level: .info,
                message: "Auto-Bundling: Base Game + \(sel.updateCount) Update(s) + \(sel.dlcCount) DLC(s) detected in folder and queued for automatic installation."
            ))
        }
        
        if detectedGames.count > 1 || sel.files.count < detectedFiles.count || hasSubfolderFiles {
            let safeName = sel.name.replacingOccurrences(of: "[^a-zA-Z0-9._-]", with: "_", options: .regularExpression)
            let stagingDir = URL(fileURLWithPath: defaultInstallPath)
                .appendingPathComponent("Staging")
                .appendingPathComponent(safeName)
            
            let fm = FileManager.default
            do {
                if !fm.fileExists(atPath: stagingDir.path) {
                    try fm.createDirectory(at: stagingDir, withIntermediateDirectories: true)
                } else {
                    // Clean up stale file symlinks only to update file references;
                    // PRESERVE intermediate <id>_build folders and cached shaders so rebuilds are instant.
                    if let existingItems = try? fm.contentsOfDirectory(at: stagingDir, includingPropertiesForKeys: [.isSymbolicLinkKey, .isDirectoryKey]) {
                        for itemURL in existingItems {
                            let name = itemURL.lastPathComponent
                            if name.hasSuffix("_build") {
                                continue // Preserve build folder, extraction caches, and compiled shaders!
                            }
                            try? fm.removeItem(at: itemURL)
                        }
                    }
                }
                for item in sel.files {
                    let linkURL = stagingDir.appendingPathComponent(item.url.lastPathComponent)
                    if fm.fileExists(atPath: linkURL.path) {
                        try? fm.removeItem(at: linkURL)
                    }
                    try fm.createSymbolicLink(at: linkURL, withDestinationURL: item.url)
                }
                targetGameDirectory = stagingDir
                logs.append(LogEntry(level: .info, message: "Prepared unified build workspace for '\(sel.name)' (\(sel.files.count) files: Base + Updates + DLCs)."))
            } catch {
                logs.append(LogEntry(level: .warning, message: "Could not create staging symlinks (\(error.localizedDescription)). Using original directory."))
            }
        }
        
        let targetOutDir = useCustomOutputFolder ? customOutputFolder : URL(fileURLWithPath: defaultInstallPath).appendingPathComponent("Games")
        
        let isAboveThreshold = (platform == .ios && shouldSuggestRomfsSplit)
        let effectiveRomfsSeparate: Bool
        if platform == .ios {
            if userDidManuallyOverrideRomfsSeparate {
                effectiveRomfsSeparate = romfsSeparate
            } else {
                effectiveRomfsSeparate = romfsSeparate || isAboveThreshold
            }
        } else {
            effectiveRomfsSeparate = false
        }
        
        if platform == .ios && isAboveThreshold && !romfsSeparate && !userDidManuallyOverrideRomfsSeparate {
            logs.append(LogEntry(
                level: .info,
                message: "[Auto-Split] Game size (\(selectedGameSizeString)) exceeds configured threshold (\(Int(autoRomfsSplitLimitGB)) GB). Automatically applying --romfs separate."
            ))
        }
        
        runner.startBuild(
            nxnativePath: nxnativePath,
            gameDirectory: targetGameDirectory,
            prodKeysPath: prodKeysPath,
            platform: platform,
            customOutputFolder: targetOutDir,
            appName: appName.isEmpty ? sel.name : appName,
            bundleId: bundleId.isEmpty ? nil : bundleId,
            language: selectedLanguage,
            showFps: showFps,
            keepExtracted: keepExtracted,
            surveyOnly: surveyOnly,
            romfsSeparate: effectiveRomfsSeparate,
            allowOtherMetal: allowOtherMetal
        )
    }
    
    public var isMetalCompilerMismatchError: Bool {
        if let err = buildError,
           (err.contains("allow-other-metal") || err.contains("ALLOW_OTHER_METAL") || err.contains("Metal compiler is not the one")) {
            return true
        }
        return logs.suffix(25).contains { entry in
            entry.message.contains("allow-other-metal") ||
            entry.message.contains("ALLOW_OTHER_METAL") ||
            entry.message.contains("Metal compiler is not the one")
        }
    }
    
    public func enableAllowOtherMetalAndRetry() {
        allowOtherMetal = true
        startBuild()
    }
    
    public func cancelBuild() {
        runner.cancel()
    }
    
    public func openOutputInFinder() {
        guard let path = buildSuccessPath else { return }
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    // MARK: - File Pickers
    public func selectNxnativeFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select nxnative Folder"
        panel.message = "Choose the directory containing the nxnative scripts and tools."
        
        if panel.runModal() == .OK, let url = panel.url {
            let res = SystemDetector.shared.detectNxnativeDirectory(customDir: url.path)
            self.nxnativePath = res.path
            self.isNxnativeValid = res.isValid
            if res.isValid {
                refreshPrerequisites()
                checkForUpdates()
            }
        }
    }
    
    public func selectGameFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Game Folder"
        panel.message = "Select a folder holding your game NSP, NSZ, or XCI files."
        
        if panel.runModal() == .OK, let url = panel.url {
            self.selectedGameFolder = url
        }
    }
    
    public func selectOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Output Folder"
        panel.message = "Select the folder where the IPA or Mac App will be saved."
        
        if panel.runModal() == .OK, let url = panel.url {
            self.customOutputFolder = url
        }
    }
    
    public func selectProdKeysFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = []
        panel.prompt = "Select prod.keys"
        panel.message = "Choose your Nintendo Switch prod.keys file."
        
        if panel.runModal() == .OK, let url = panel.url {
            self.prodKeysPath = url.path
            self.prodKeysSource = "User Selected"
            self.isProdKeysValid = true
        }
    }
    
    public func selectRyujinxFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Ryujinx Folder"
        panel.message = "Select your Ryujinx folder to automatically locate prod.keys."
        
        if panel.runModal() == .OK, let url = panel.url {
            detectEnvironment(customRyujinxDir: url.path)
        }
    }

    public func findInRyujinx() {
        if let detected = SystemDetector.shared.detectProdKeys() {
            self.prodKeysPath = detected.path
            self.prodKeysSource = detected.sourceName
            self.isProdKeysValid = true
            SoundEffectService.shared.play(.click)
        } else {
            SoundEffectService.shared.play(.error)
            self.showRyujinxNotFoundSheet = true
        }
    }
}
