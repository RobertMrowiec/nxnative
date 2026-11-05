import Foundation
import AppKit

private var isSwitchingToManualOrder = false

extension AppViewModel {
    /// Switches from alphabetical sorting to manual/persisted order without re-sorting over a live drag-and-drop move.
    public func activateManualOrderMode() {
        guard activeSortOption != .lastPlayed else { return }
        isSwitchingToManualOrder = true
        activeSortOption = .lastPlayed
        isSwitchingToManualOrder = false
    }

    // MARK: - Library Operations (Privacy-guarded)
    public func refreshLibrary(focusOnOutputURL: URL? = nil) {
        isScanningLibrary = true
        var searchDirs: [URL] = []
        
        let root = URL(fileURLWithPath: defaultInstallPath)
        let gamesDir = root.appendingPathComponent("Games")
        searchDirs.append(gamesDir)

        let nxPortsDir = URL(fileURLWithPath: "/Volumes/SSD FN501 PRO/Emulations/Nx Ports")
        if FileManager.default.fileExists(atPath: nxPortsDir.path) {
            searchDirs.append(nxPortsDir)
        }
        
        if let custom = libraryFolder, custom.path != "/" && custom.path != gamesDir.path {
            searchDirs.append(custom)
        }
        
        for folder in nonSwitchGameFolders {
            let std = folder.standardizedFileURL
            if !searchDirs.contains(where: { $0.standardizedFileURL.path == std.path }) {
                searchDirs.append(std)
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let extraURLs = self.savedNonSwitchAppPaths.map { URL(fileURLWithPath: $0) }
            let games = LibraryScanner.shared.scan(directories: searchDirs, extraAppURLs: extraURLs)
            DispatchQueue.main.async {
                let visible = LibraryOrder.apply(to: games.filter { !self.hiddenGamePaths.contains($0.url.standardized.path) })
                self.libraryGames = visible
                self.reconcileLibraryFocusState(preferredPortedURL: focusOnOutputURL)
                self.isScanningLibrary = false
                
                // Automatically ensure every game in the library has its correct official cover and input mapping
                DispatchQueue.global(qos: .utility).async {
                    InputProfileManager.shared.exportActiveMappingToDisk(libraryFolder: self.libraryFolder)
                    for game in visible {
                        GameCoverService.shared.ensureCover(for: game)
                    }
                    DeviceDeploymentService.shared.syncInstalledApps(with: visible)
                }
            }
        }
    }

    public func selectLibraryFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Library Folder"
        panel.message = "Choose a folder containing your built Mac Apps or IPAs."
        
        if panel.runModal() == .OK, let url = panel.url {
            self.libraryFolder = url
            refreshLibrary()
        }
    }
    
    public func revealInFinder(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    public func revealSaveFolder(_ url: URL) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    public func removeGameFromLibrary(_ game: PortedGame) {
        hiddenGamePaths.insert(game.url.standardized.path)
        SoundEffectService.shared.play(.click)
        logs.append(LogEntry(level: .warning, message: "Removed from library: \(game.name) (files preserved on disk)"))
        refreshLibrary()
    }

    public func restoreHiddenGame(path: String) {
        hiddenGamePaths.remove(path)
        SoundEffectService.shared.play(.click)
        logs.append(LogEntry(level: .success, message: "Restored game to library"))
        refreshLibrary()
    }

    public func restoreAllHiddenGames() {
        let count = hiddenGamePaths.count
        hiddenGamePaths.removeAll()
        SoundEffectService.shared.play(.click)
        logs.append(LogEntry(level: .success, message: "Restored \(count) hidden games to library"))
        refreshLibrary()
    }

    public func deleteGameToTrash(_ game: PortedGame) {
        do {
            var resultingURL: NSURL?
            try FileManager.default.trashItem(at: game.url, resultingItemURL: &resultingURL)
            hiddenGamePaths.remove(game.url.standardized.path)
            ArtworkStore.shared.clearCache(for: game)
            SoundEffectService.shared.play(.click)
            logs.append(LogEntry(level: .warning, message: "Moved game to Trash: \(game.name)"))
            refreshLibrary()
        } catch {
            SoundEffectService.shared.play(.error)
            logs.append(LogEntry(level: .error, message: "Failed to move game to Trash: \(error.localizedDescription)"))
        }
    }

    public func deletePortedGame(_ game: PortedGame) { deleteGameToTrash(game) }
    
    // MARK: - Multiple Game Folders & Subfolder Scanning
    public func addGameFolder(_ url: URL) {
        let standardized = url.standardizedFileURL
        if !gameFolders.contains(where: { $0.standardizedFileURL.path == standardized.path }) {
            gameFolders.append(standardized)
        }
        if selectedGameFolder == nil {
            selectedGameFolder = standardized
        }
        scanAllGameFolders()
    }
    
    public func removeGameFolder(_ url: URL) {
        let path = url.standardizedFileURL.path
        gameFolders.removeAll { $0.standardizedFileURL.path == path }
        if selectedGameFolder?.standardizedFileURL.path == path {
            selectedGameFolder = gameFolders.first
        }
        scanAllGameFolders()
    }
    
    public func scanAllGameFolders() {
        guard !gameFolders.isEmpty else {
            detectedFiles = []
            detectedGames = []
            if !isBuilding {
                selectedGame = nil
            }
            reconcileLibraryFocusState()
            return
        }
        let folders = gameFolders
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let files = GameScanner.shared.scan(directories: folders)
            let games = GameScanner.shared.groupFilesIntoGames(files: files)
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.detectedFiles = files
                self.detectedGames = games
                if !self.isBuilding {
                    if self.selectedGame == nil || !games.contains(where: { $0.id == self.selectedGame?.id }) {
                        self.selectedGame = self.unportedGames.first ?? games.first
                    }
                    if let firstGame = (self.unportedGames.first ?? games.first), self.appName.isEmpty {
                        self.appName = firstGame.name
                    }
                }
                self.reconcileLibraryFocusState()
            }
        }
    }
    
    public func scanGameFolder(_ folder: URL) {
        addGameFolder(folder)
    }
    
    public func selectAdditionalGameFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Choose Game Folders"
        panel.message = "Select folders holding your game NSP, NSZ, XCI, or NUP files."
        
        if panel.runModal() == .OK {
            for url in panel.urls {
                addGameFolder(url)
            }
        }
    }
    
    // MARK: - Sorting Helpers & Unified Items
    public func resetLibraryOrganization() {
        activeGroupFilter = .categories
        activeSortOption = .lastPlayed
        applyActiveSorting()
    }

    public func applyActiveSorting() {
        guard !isSwitchingToManualOrder else { return }
        switch activeSortOption {
        case .lastPlayed:
            libraryGames.sort { a, b in
                let dateA = lastPlayedDate(for: a) ?? Date.distantPast
                let dateB = lastPlayedDate(for: b) ?? Date.distantPast
                if dateA != dateB {
                    return dateA > dateB
                }
                return a.modificationDate > b.modificationDate
            }
            detectedGames.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .name:
            libraryGames.sort { a, b in
                a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
            detectedGames.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
        LibraryOrder.save(libraryGames)
        reconcileLibraryFocusState()
    }

    public func sortGames(_ games: [PortedGame]) -> [PortedGame] {
        switch activeSortOption {
        case .lastPlayed:
            return games.sorted { a, b in
                let dateA = lastPlayedDate(for: a) ?? Date.distantPast
                let dateB = lastPlayedDate(for: b) ?? Date.distantPast
                if dateA != dateB {
                    return dateA > dateB
                }
                return a.modificationDate > b.modificationDate
            }
        case .name:
            return games.sorted { a, b in
                a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
        }
    }
    
    public func sortUnportedGames(_ games: [SelectableGame]) -> [SelectableGame] {
        return games.sorted { a, b in
            a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }

    public func unifiedItems(for games: [PortedGame]) -> [UnifiedLibraryItem] {
        let portedItems = games.map { UnifiedLibraryItem.ported($0) }
        let unportedItems = unportedGames.map { UnifiedLibraryItem.unported($0) }
        var combined = portedItems + unportedItems

        switch activeSortOption {
        case .name:
            combined.sort { a, b in
                a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
        case .lastPlayed:
            combined = LibraryOrder.applyUnified(to: combined)
        }
        return combined
    }
}
