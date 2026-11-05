import Foundation
import AppKit

extension AppViewModel {
    // MARK: - Native Mac Game Folders (Non-Switch Games)
    public func addNonSwitchGameFolder(_ url: URL) {
        let standardized = url.standardizedFileURL
        if !nonSwitchGameFolders.contains(where: { $0.standardizedFileURL.path == standardized.path }) {
            nonSwitchGameFolders.append(standardized)
        }
    }

    public func removeNonSwitchGameFolder(_ url: URL) {
        let path = url.standardizedFileURL.path
        nonSwitchGameFolders.removeAll { $0.standardizedFileURL.path == path }
    }

    public func clearAllNonSwitchGameFolders() {
        nonSwitchGameFolders.removeAll()
    }

    public func selectAdditionalNonSwitchGameFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = tr("system.add_folder")
        panel.message = tr("system.select_nonswitch_folder_message")

        if panel.runModal() == .OK {
            for url in panel.urls {
                addNonSwitchGameFolder(url)
            }
        }
    }

    public func selectSingleNonSwitchGameFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.application]
        panel.prompt = tr("system.add_nonswitch_single_app")
        panel.message = tr("system.select_nonswitch_app_message")

        if panel.runModal() == .OK {
            for url in panel.urls {
                addNonSwitchGame(url: url)
            }
        }
    }

    // MARK: - Drag and Drop & ZIP
    public func handleDroppedURLs(_ urls: [URL]) {
        dropErrorMessage = nil
        for url in urls {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { continue }
            
            let ext = url.pathExtension.lowercased()
            if ext == "app" {
                addNonSwitchGame(url: url)
            } else if ext == "zip" {
                extractDroppedZip(zipURL: url)
            } else if isDir.boolValue {
                let hasApps = containsMacApps(in: url)
                let hasRoms = containsSwitchRoms(in: url)
                if hasApps {
                    addNonSwitchGameFolder(url)
                }
                if hasRoms || !hasApps {
                    addGameFolder(url)
                }
            } else {
                let parent = url.deletingLastPathComponent()
                addGameFolder(parent)
            }
        }
    }
    
    private func containsMacApps(in directory: URL) -> Bool {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return false }
        
        var count = 0
        for case let fileURL as URL in enumerator {
            count += 1
            if count > 50 { break }
            if fileURL.pathExtension.lowercased() == "app" {
                return true
            }
        }
        return false
    }

    private func containsSwitchRoms(in directory: URL) -> Bool {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return false }
        
        let romExts: Set<String> = ["nsp", "nsz", "xci", "xcz", "nup"]
        var count = 0
        for case let fileURL as URL in enumerator {
            count += 1
            if count > 50 { break }
            if romExts.contains(fileURL.pathExtension.lowercased()) {
                return true
            }
        }
        return false
    }
    
    private func extractDroppedZip(zipURL: URL) {
        let gamesDir = URL(fileURLWithPath: defaultInstallPath).appendingPathComponent("Games")
        isExtractingZip = true
        zipExtractionMessage = "Analyzing ZIP archive..."
        
        ZipExtractor.shared.extract(
            zipURL: zipURL,
            destinationFolder: gamesDir,
            progressCallback: { [weak self] msg in
                self?.zipExtractionMessage = msg
            },
            completion: { [weak self] result in
                guard let self = self else { return }
                self.isExtractingZip = false
                
                switch result {
                case .success(let extractedDir):
                    self.selectedGameFolder = extractedDir
                    self.logs.append(LogEntry(level: .success, message: "Archive extracted to: \(extractedDir.path)"))
                case .failure(let error):
                    self.dropErrorMessage = error.localizedDescription
                    self.logs.append(LogEntry(level: .error, message: "Failed to extract archive: \(error.localizedDescription)"))
                }
            }
        )
    }
}
