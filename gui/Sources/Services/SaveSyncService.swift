import Foundation
import AppKit

public struct SaveComparisonInfo: Equatable {
    public let macSaveURL: URL
    public let macModificationDate: Date?
    public let macFileCount: Int
    public let hasDeviceSave: Bool
}

public final class SaveSyncService: ObservableObject {
    public static let shared = SaveSyncService()
    internal let fileManager = FileManager.default
    private var cloudSyncActiveCache: [String: Bool] = [:]

    private static let iCloudSyncEnabledKey = "nxnative_icloud_sync_enabled"

    @Published public private(set) var isICloudDriveAvailable: Bool = false

    /// User setting controlling whether iCloud Sync and Cross-Save is enabled.
    /// Defaults to false to prevent unprompted consumption of users' iCloud quotas.
    @Published public var isICloudSyncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isICloudSyncEnabled, forKey: Self.iCloudSyncEnabledKey)
            cloudSyncActiveCache.removeAll()
            if !isICloudSyncEnabled {
                _ = disableCloudSyncAndRevertLocal()
            }
            DispatchQueue.main.async { self.objectWillChange.send() }
        }
    }

    private init() {
        self.isICloudSyncEnabled = UserDefaults.standard.object(forKey: Self.iCloudSyncEnabledKey) as? Bool ?? false
        checkICloudAvailability()
    }

    public func invalidateCloudSyncCache() {
        cloudSyncActiveCache.removeAll()
    }

    public func checkICloudAvailability() {
        let docs = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        self.isICloudDriveAvailable = fileManager.fileExists(atPath: docs.path)
    }

    // MARK: - iCloud Root Directory
    public var iCloudRootURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/nxnative_launcher", isDirectory: true)
    }

    public func ensureRootFolderConfigured() {
        guard isICloudSyncEnabled && isICloudDriveAvailable else { return }
        let root = iCloudRootURL
        if !fileManager.fileExists(atPath: root.path) {
            try? fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        }
        // Set official NxNative Launcher application icon on the root folder
        if let appIcon = NSApp.applicationIconImage {
            applyFolderIcon(image: appIcon, folderURL: root)
        }
    }

    // MARK: - Game iCloud Directories
    public func sanitizedGameName(_ game: PortedGame) -> String {
        let safe = game.name.replacingOccurrences(of: "[:/\\\\?*\"<>|]", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return safe.isEmpty ? (game.titleId ?? "UnknownGame") : safe
    }

    public func iCloudFolder(for game: PortedGame) -> URL {
        iCloudRootURL.appendingPathComponent(sanitizedGameName(game), isDirectory: true)
    }

    public func iCloudSaveDirectory(for game: PortedGame) -> URL {
        iCloudFolder(for: game).appendingPathComponent("save", isDirectory: true)
    }

    public func isCloudSyncActive(for game: PortedGame) -> Bool {
        guard isICloudSyncEnabled && isICloudDriveAvailable else {
            return false
        }
        let key = game.uniqueKey
        if let cached = cloudSyncActiveCache[key] {
            return cached
        }
        guard let titleId = game.titleId, !titleId.isEmpty else {
            cloudSyncActiveCache[key] = false
            return false
        }
        let localDir = macSaveDirectory(for: titleId)
        
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: localDir.path, isDirectory: &isDir) {
            if let dest = try? fileManager.destinationOfSymbolicLink(atPath: localDir.path) {
                if dest.contains("nxnative_launcher") || dest.contains("CloudDocs") {
                    cloudSyncActiveCache[key] = true
                    return true
                }
            }
        }
        
        let cloudDir = iCloudSaveDirectory(for: game)
        let active = fileManager.fileExists(atPath: cloudDir.path)
        cloudSyncActiveCache[key] = active
        return active
    }

    // MARK: - Safe Setup & Migration
    @discardableResult
    public func ensureCloudSaveConfigured(for game: PortedGame, cover: NSImage?) -> Result<URL, Error> {
        guard isICloudSyncEnabled && isICloudDriveAvailable else {
            return .failure(NSError(domain: "SaveSyncService", code: 403, userInfo: [NSLocalizedDescriptionKey: "iCloud Sync is disabled"]))
        }
        ensureRootFolderConfigured()
        let gameFolder = iCloudFolder(for: game)
        let cloudSaveDir = iCloudSaveDirectory(for: game)

        do {
            try fileManager.createDirectory(at: cloudSaveDir, withIntermediateDirectories: true)

            // Pre-flight writability check verifying macOS TCC permits write access to this iCloud path
            let probeFile = cloudSaveDir.appendingPathComponent(".probe_\(UUID().uuidString)")
            do {
                try "probe".write(to: probeFile, atomically: true, encoding: .utf8)
                try fileManager.removeItem(at: probeFile)
            } catch {
                if let titleId = game.titleId {
                    revertToLocalSave(for: titleId)
                }
                return .failure(NSError(
                    domain: "SaveSyncService",
                    code: Int(EPERM),
                    userInfo: [NSLocalizedDescriptionKey: "iCloud Drive write permission denied or inaccessible (errno=1 EPERM). Safely reverting to local save storage."]
                ))
            }

            // Apply game's box art cover as custom folder icon in Finder and iCloud Drive
            if let coverImage = cover ?? GameCoverService.shared.coverImage(for: game) {
                applyFolderIcon(image: coverImage, folderURL: gameFolder)
            }

            guard let titleId = game.titleId, !titleId.isEmpty else {
                return .success(cloudSaveDir)
            }

            let localSave = macSaveDirectory(for: titleId)
            let isSymlink: Bool = (try? fileManager.destinationOfSymbolicLink(atPath: localSave.path)) != nil

            // If local directory exists and is NOT already a symlink, migrate existing saves
            if fileManager.fileExists(atPath: localSave.path) && !isSymlink {
                _ = backupMacSave(titleId: titleId)
                if let contents = try? fileManager.contentsOfDirectory(atPath: localSave.path) {
                    for item in contents {
                        let src = localSave.appendingPathComponent(item)
                        let dst = cloudSaveDir.appendingPathComponent(item)
                        if !fileManager.fileExists(atPath: dst.path) {
                            try? fileManager.copyItem(at: src, to: dst)
                        }
                    }
                }
                // Safely remove local folder to replace with symlink
                try? fileManager.removeItem(at: localSave)
            }

            // Create transparent POSIX symlink pointing local AppSupport to iCloud Drive
            if !fileManager.fileExists(atPath: localSave.path) {
                let localParent = localSave.deletingLastPathComponent()
                try? fileManager.createDirectory(at: localParent, withIntermediateDirectories: true)
                try? fileManager.createSymbolicLink(at: localSave, withDestinationURL: cloudSaveDir)
            }

            // Write DM_SAVE into env.txt
            updateEnvFileWithCloudSave(titleId: titleId, cloudSavePath: cloudSaveDir.path)

            cloudSyncActiveCache[game.uniqueKey] = true
            DispatchQueue.main.async { self.objectWillChange.send() }
            return .success(cloudSaveDir)
        } catch {
            if let titleId = game.titleId {
                revertToLocalSave(for: titleId)
            }
            return .failure(error)
        }
    }

    /// Reverts an individual game from an iCloud symlink back to a genuine local directory in Application Support.
    public func revertToLocalSave(for titleId: String) {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let titleFolder = appSupport.appendingPathComponent("nxnative/\(titleId.uppercased())", isDirectory: true)
        let saveFolder = titleFolder.appendingPathComponent("save", isDirectory: true)
        
        if let dest = try? fileManager.destinationOfSymbolicLink(atPath: saveFolder.path) {
            let cloudDestURL = URL(fileURLWithPath: dest)
            try? fileManager.removeItem(at: saveFolder)
            try? fileManager.createDirectory(at: saveFolder, withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: cloudDestURL.path),
               let contents = try? fileManager.contentsOfDirectory(atPath: cloudDestURL.path) {
                for file in contents {
                    let src = cloudDestURL.appendingPathComponent(file)
                    let dst = saveFolder.appendingPathComponent(file)
                    try? fileManager.copyItem(at: src, to: dst)
                }
            }
        } else if !fileManager.fileExists(atPath: saveFolder.path) {
            try? fileManager.createDirectory(at: saveFolder, withIntermediateDirectories: true)
        }
        
        let envFile = titleFolder.appendingPathComponent("env.txt")
        if let existing = try? String(contentsOf: envFile, encoding: .utf8) {
            let cleaned = existing.components(separatedBy: .newlines)
                .filter { !$0.hasPrefix("DM_SAVE=") }
                .joined(separator: "\n")
            try? cleaned.write(to: envFile, atomically: true, encoding: .utf8)
        }
    }

    private func updateEnvFileWithCloudSave(titleId: String, cloudSavePath: String) {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let envFile = appSupport.appendingPathComponent("nxnative/\(titleId.uppercased())/env.txt")
        var lines: [String] = []
        if let existing = try? String(contentsOf: envFile, encoding: .utf8) {
            lines = existing.components(separatedBy: .newlines).filter { !$0.hasPrefix("DM_SAVE=") }
        }
        lines.append("DM_SAVE=\(cloudSavePath)")
        try? lines.joined(separator: "\n").write(to: envFile, atomically: true, encoding: .utf8)
    }

    // MARK: - Folder Icon Customization
    public func createFolderIconWithCover(coverImage: NSImage) -> NSImage {
        let size = NSSize(width: 512, height: 512)
        let composite = NSImage(size: size)
        composite.lockFocus()

        // 1. Base macOS folder icon
        let folderIcon = NSWorkspace.shared.icon(for: .folder)
        folderIcon.size = size
        folderIcon.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .sourceOver, fraction: 1.0)

        // 2. Front pocket badge positioning for standard macOS folder
        let badgeSize: CGFloat = 185
        let badgeX: CGFloat = (size.width - badgeSize) / 2
        let badgeY: CGFloat = 118
        let badgeRect = NSRect(x: badgeX, y: badgeY, width: badgeSize, height: badgeSize)
        let cornerRadius: CGFloat = 36
        let clipPath = NSBezierPath(roundedRect: badgeRect, xRadius: cornerRadius, yRadius: cornerRadius)

        // Drop shadow for the badge
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.42)
        shadow.shadowOffset = NSSize(width: 0, height: -3)
        shadow.shadowBlurRadius = 7
        shadow.set()
        NSColor.black.withAlphaComponent(0.3).setFill()
        clipPath.fill()
        NSGraphicsContext.restoreGraphicsState()

        // Clip and draw cover image inside badge with aspect fill & centering (no squishing/stretching)
        NSGraphicsContext.saveGraphicsState()
        clipPath.addClip()
        let imgSize = coverImage.size
        if imgSize.width > 0 && imgSize.height > 0 {
            let scale = max(badgeRect.width / imgSize.width, badgeRect.height / imgSize.height)
            let scaledW = imgSize.width * scale
            let scaledH = imgSize.height * scale
            let drawX = badgeRect.origin.x + (badgeRect.width - scaledW) / 2
            let drawY = badgeRect.origin.y + (badgeRect.height - scaledH) / 2
            let drawRect = NSRect(x: drawX, y: drawY, width: scaledW, height: scaledH)
            coverImage.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        } else {
            coverImage.draw(in: badgeRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        }
        NSGraphicsContext.restoreGraphicsState()

        // Subtle specular border around badge
        NSGraphicsContext.saveGraphicsState()
        NSColor.white.withAlphaComponent(0.24).setStroke()
        clipPath.lineWidth = 1.2
        clipPath.stroke()
        NSGraphicsContext.restoreGraphicsState()

        composite.unlockFocus()
        return composite
    }

    @discardableResult
    public func applyFolderIcon(image: NSImage?, folderURL: URL) -> Bool {
        guard let img = image else { return false }
        let composite = createFolderIconWithCover(coverImage: img)
        return NSWorkspace.shared.setIcon(composite, forFile: folderURL.path, options: [])
    }

    public func revealCloudGameFolder(for game: PortedGame, cover: NSImage?) {
        if isICloudSyncEnabled && isICloudDriveAvailable {
            _ = ensureCloudSaveConfigured(for: game, cover: cover)
            let folder = iCloudFolder(for: game)
            NSWorkspace.shared.activateFileViewerSelecting([folder])
        } else if let titleId = game.titleId {
            let local = macSaveDirectory(for: titleId)
            try? fileManager.createDirectory(at: local, withIntermediateDirectories: true)
            NSWorkspace.shared.activateFileViewerSelecting([local])
        }
    }

    // MARK: - Safety Snapshots (Strictly Local Storage)
    @discardableResult
    public func createSafetySnapshot(for game: PortedGame, label: String = "auto") -> URL? {
        guard let titleId = game.titleId, !titleId.isEmpty else { return nil }
        let srcDir = resolvedSaveDirectory(forTitleId: titleId)
        guard fileManager.fileExists(atPath: srcDir.path) else { return nil }

        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let backupsDir = appSupport.appendingPathComponent("nxnative/\(titleId.uppercased())/backups", isDirectory: true)
        try? fileManager.createDirectory(at: backupsDir, withIntermediateDirectories: true)

        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let destination = backupsDir.appendingPathComponent("save_snapshot_\(timestamp)_\(label)")

        do {
            try fileManager.copyItem(at: srcDir, to: destination)
            pruneOldBackups(in: backupsDir, maxKeep: 5)
            return destination
        } catch {
            return nil
        }
    }

    // MARK: - Local Save Compatibility
    public func macSaveDirectory(for titleId: String) -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let base = appSupport.appendingPathComponent("nxnative/\(titleId.uppercased())", isDirectory: true)
        let saveDir = base.appendingPathComponent("save", isDirectory: true)
        let workDir = base.appendingPathComponent("save.work", isDirectory: true)

        if fileManager.fileExists(atPath: saveDir.path) {
            return saveDir
        }
        if fileManager.fileExists(atPath: workDir.path) {
            return workDir
        }
        return saveDir
    }

    public func resolvedSaveDirectory(forTitleId titleId: String) -> URL {
        let localDir = macSaveDirectory(for: titleId)
        if let dest = try? fileManager.destinationOfSymbolicLink(atPath: localDir.path) {
            return URL(fileURLWithPath: dest)
        }
        return localDir
    }

    public func inspectMacSave(for titleId: String) -> SaveComparisonInfo {
        let dir = resolvedSaveDirectory(forTitleId: titleId)
        guard fileManager.fileExists(atPath: dir.path) else {
            return SaveComparisonInfo(macSaveURL: dir, macModificationDate: nil, macFileCount: 0, hasDeviceSave: false)
        }

        let contents = (try? fileManager.contentsOfDirectory(atPath: dir.path)) ?? []
        let newest = contents.compactMap { name -> Date? in
            let path = dir.appendingPathComponent(name).path
            return (try? fileManager.attributesOfItem(atPath: path)[.modificationDate]) as? Date
        }.max()

        return SaveComparisonInfo(
            macSaveURL: dir,
            macModificationDate: newest,
            macFileCount: contents.count,
            hasDeviceSave: false
        )
    }

    public func backupMacSave(titleId: String) -> URL? {
        let saveDir = resolvedSaveDirectory(forTitleId: titleId)
        guard fileManager.fileExists(atPath: saveDir.path) else { return nil }

        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let backupRoot = appSupport.appendingPathComponent("nxnative/\(titleId.uppercased())/backups", isDirectory: true)
        try? fileManager.createDirectory(at: backupRoot, withIntermediateDirectories: true)

        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let destination = backupRoot.appendingPathComponent("save_backup_\(timestamp)")

        do {
            try fileManager.copyItem(at: saveDir, to: destination)
            pruneOldBackups(in: backupRoot, maxKeep: 5)
            return destination
        } catch {
            return nil
        }
    }

    // MARK: - Backup Retention & Pruning (Max 5 Snapshots)
    public func pruneOldBackups(in directory: URL, maxKeep: Int = 5) {
        guard let entries = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey], options: .skipsHiddenFiles) else { return }
        
        let sorted = entries.sorted { a, b in
            let dateA = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            let dateB = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            return dateA > dateB // newest first
        }
        
        if sorted.count > maxKeep {
            for stale in sorted.dropFirst(maxKeep) {
                try? fileManager.removeItem(at: stale)
            }
        }
    }

    // MARK: - Safe iCloud Disabling & Reversion to Local Storage
    @discardableResult
    public func disableCloudSyncAndRevertLocal() -> Int {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let nxRoot = appSupport.appendingPathComponent("nxnative", isDirectory: true)
        guard let titleDirs = try? fileManager.contentsOfDirectory(atPath: nxRoot.path) else { return 0 }
        
        var revertedCount = 0
        for title in titleDirs {
            let titleFolder = nxRoot.appendingPathComponent(title, isDirectory: true)
            let saveFolder = titleFolder.appendingPathComponent("save", isDirectory: true)
            
            if let dest = try? fileManager.destinationOfSymbolicLink(atPath: saveFolder.path) {
                let cloudDestURL = URL(fileURLWithPath: dest)
                // Remove the symlink safely
                try? fileManager.removeItem(at: saveFolder)
                // Re-create genuine local directory
                try? fileManager.createDirectory(at: saveFolder, withIntermediateDirectories: true)
                // Copy files back from iCloud if available
                if fileManager.fileExists(atPath: cloudDestURL.path),
                   let contents = try? fileManager.contentsOfDirectory(atPath: cloudDestURL.path) {
                    for file in contents {
                        let src = cloudDestURL.appendingPathComponent(file)
                        let dst = saveFolder.appendingPathComponent(file)
                        try? fileManager.copyItem(at: src, to: dst)
                    }
                }
                revertedCount += 1
            }
            
            // Clean DM_SAVE in env.txt if present
            let envFile = titleFolder.appendingPathComponent("env.txt")
            if let existing = try? String(contentsOf: envFile, encoding: .utf8) {
                let cleaned = existing.components(separatedBy: .newlines)
                    .filter { !$0.hasPrefix("DM_SAVE=") }
                    .joined(separator: "\n")
                try? cleaned.write(to: envFile, atomically: true, encoding: .utf8)
            }
        }
        
        cloudSyncActiveCache.removeAll()
        return revertedCount
    }

    // MARK: - iCloud Storage Measurement & Reclamation
    public func calculateICloudStorageBytes() -> Int64 {
        guard isICloudDriveAvailable else { return 0 }
        let root = iCloudRootURL
        guard fileManager.fileExists(atPath: root.path) else { return 0 }
        
        guard let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: [.fileSizeKey], options: []) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    @discardableResult
    public func purgeICloudFolder() throws -> Int64 {
        let bytes = calculateICloudStorageBytes()
        let root = iCloudRootURL
        if fileManager.fileExists(atPath: root.path) {
            try fileManager.removeItem(at: root)
        }
        cloudSyncActiveCache.removeAll()
        DispatchQueue.main.async { self.objectWillChange.send() }
        return bytes
    }
}
