import Foundation
import AppKit

public final class GameFilePickerDelegate: NSObject, NSOpenSavePanelDelegate {
    public static let sharedWithApps = GameFilePickerDelegate(allowApps: true)
    public static let sharedRomsOnly = GameFilePickerDelegate(allowApps: false)

    private let allowedExtensions: Set<String>
    private let allowApps: Bool

    public init(allowApps: Bool) {
        self.allowApps = allowApps
        var exts: Set<String> = ["nsp", "nsz", "xci", "xcz", "nup", "zip"]
        if allowApps {
            exts.insert("app")
        }
        self.allowedExtensions = exts
        super.init()
    }

    public func panel(_ sender: Any, shouldEnable url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if allowedExtensions.contains(ext) {
            return true
        }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return false
        }
        if isDir.boolValue {
            if ext == "app" {
                return allowApps
            }
            let excludedBundleExts: Set<String> = ["framework", "xcarchive", "bundle", "plugin", "kext", "dSYM"]
            if excludedBundleExts.contains(ext) {
                return false
            }
            return true
        }
        return false
    }
}

extension AppViewModel {
    // MARK: - Unified Game / ROM / NUP / Folder Picker
    public func openUnifiedGamePicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.treatsFilePackagesAsDirectories = false
        panel.allowedContentTypes = []
        panel.delegate = GameFilePickerDelegate.sharedWithApps
        panel.prompt = tr("common.choose")
        panel.message = tr("library.empty_drop_subtitle")

        if panel.runModal() == .OK {
            handleDroppedURLs(panel.urls, openPortModalForSingleGame: true)
        }
    }

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
    public func handleDroppedURLs(_ urls: [URL], openPortModalForSingleGame: Bool = false) {
        dropErrorMessage = nil
        let isSingleItem = (urls.count == 1)
        let romExts: Set<String> = ["nsp", "nsz", "xci", "xcz", "nup"]

        for url in urls {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { continue }
            
            let ext = url.pathExtension.lowercased()
            if ext == "app" {
                addNonSwitchGame(url: url)
            } else if ext == "zip" {
                extractDroppedZip(zipURL: url)
            } else if isDir.boolValue {
                let isDumpDir = FileManager.default.fileExists(
                    atPath: url.appendingPathComponent("base/exefs/main.npdm").path
                )
                if isDumpDir {
                    addGameFolder(
                        url.deletingLastPathComponent(),
                        preferredFileURL: url,
                        openPortModalIfFound: isSingleItem && (openPortModalForSingleGame || selectedTab == 0)
                    )
                } else {
                    let hasApps = containsMacApps(in: url)
                    let hasRoms = containsSwitchRoms(in: url)
                    if hasApps {
                        addNonSwitchGameFolder(url)
                    }
                    if hasRoms || !hasApps {
                        addGameFolder(
                            url,
                            preferredFolderURL: isSingleItem ? url : nil,
                            openPortModalIfFound: isSingleItem && openPortModalForSingleGame
                        )
                    }
                }
            } else if romExts.contains(ext) {
                let parent = url.deletingLastPathComponent()
                addGameFolder(
                    parent,
                    preferredFileURL: url,
                    openPortModalIfFound: isSingleItem && (openPortModalForSingleGame || selectedTab == 0)
                )
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
        if FileManager.default.fileExists(atPath: directory.appendingPathComponent("base/exefs/main.npdm").path) {
            return true
        }
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
            if FileManager.default.fileExists(atPath: fileURL.appendingPathComponent("base/exefs/main.npdm").path) {
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
