import Foundation

// MARK: - iCloud Save Restoration & Injection for Connected Devices
extension SaveSyncService {

    /// Locates the existing save for a game across iCloud Drive and Mac local storage.
    public func locateExistingSave(titleId: String, gameName: String?) -> URL? {
        let fm = fileManager
        let root = iCloudRootURL

        // 1. Check titleId folder in iCloud (e.g. nxnative_launcher/0100A83022A22000/)
        let tidFolder = root.appendingPathComponent(titleId.uppercased(), isDirectory: true)
        let tidDmsync = tidFolder.appendingPathComponent("save.dmsync")
        if fm.fileExists(atPath: tidDmsync.path) {
            return tidDmsync
        }
        let tidSaveDir = tidFolder.appendingPathComponent("save", isDirectory: true)
        if fm.fileExists(atPath: tidSaveDir.path), hasEntries(tidSaveDir.path) {
            return tidSaveDir
        }

        // 2. Check sanitized game name in iCloud (e.g. nxnative_launcher/Absolum/save/)
        if let name = gameName, !name.isEmpty {
            let safe = name.replacingOccurrences(of: "[:/\\\\?*\"<>|]", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let nameFolder = root.appendingPathComponent(safe, isDirectory: true)
            let nameSaveDir = nameFolder.appendingPathComponent("save", isDirectory: true)
            if fm.fileExists(atPath: nameSaveDir.path), hasEntries(nameSaveDir.path) {
                return nameSaveDir
            }
            let nameDmsync = nameFolder.appendingPathComponent("save.dmsync")
            if fm.fileExists(atPath: nameDmsync.path) {
                return nameDmsync
            }
        }

        // 3. Check Mac local save directory (e.g. ~/Library/Application Support/nxnative/<TID>/save)
        let localDir = resolvedSaveDirectory(forTitleId: titleId)
        if fm.fileExists(atPath: localDir.path), hasEntries(localDir.path) {
            return localDir
        }

        return nil
    }

    /// Restores and pushes an existing save (from iCloud or Mac) directly to the connected iOS device.
    public func restoreICloudSaveToDevice(
        titleId: String,
        gameName: String?,
        bundleId: String,
        device: ConnectedAppleDevice,
        completion: @escaping (Bool, String) -> Void
    ) {
        guard let saveSource = locateExistingSave(titleId: titleId, gameName: gameName) else {
            completion(false, "Nenhum save existente encontrado no iCloud ou localmente para \(gameName ?? titleId).")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(false, "SaveSyncService indisponivel") }
                return
            }

            let isHubTarget = bundleId == "org.nxnative.shell" || bundleId.hasPrefix("org.nxnative.shell")
            let realBundleId = isHubTarget ? bundleId : (DeviceDeploymentService.shared.findBundleId(for: titleId, gameName: gameName, on: device) ?? bundleId)
            let tempDir = self.fileManager.temporaryDirectory.appendingPathComponent("nxnative_restore_\(UUID().uuidString)", isDirectory: true)
            defer { try? self.fileManager.removeItem(at: tempDir) }
            try? self.fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

            // Stage directory for Documents/save
            let stagedSave = tempDir.appendingPathComponent("save", isDirectory: true)
            try? self.fileManager.createDirectory(at: stagedSave, withIntermediateDirectories: true)

            var isDir: ObjCBool = false
            if self.fileManager.fileExists(atPath: saveSource.path, isDirectory: &isDir), isDir.boolValue {
                // Copy all save files into staged directory
                if let items = try? self.fileManager.contentsOfDirectory(atPath: saveSource.path) {
                    for item in items {
                        let src = saveSource.appendingPathComponent(item)
                        let dst = stagedSave.appendingPathComponent(item)
                        try? self.fileManager.copyItem(at: src, to: dst)
                    }
                }
            } else if saveSource.lastPathComponent.hasSuffix(".dmsync") {
                // Unpack binary dmsync into staged directory
                self.unpackDMSync(at: saveSource, into: stagedSave)
                let stagedDmsync = tempDir.appendingPathComponent("save.dmsync")
                try? self.fileManager.copyItem(at: saveSource, to: stagedDmsync)
            }

            // Also check if there is a save.dmsync in the parent/title folder to stage or unpack
            let parentDmsync = saveSource.deletingLastPathComponent().appendingPathComponent("save.dmsync")
            if self.fileManager.fileExists(atPath: parentDmsync.path) {
                if !self.hasEntries(stagedSave.path) {
                    self.unpackDMSync(at: parentDmsync, into: stagedSave)
                }
                let stagedDmsync = tempDir.appendingPathComponent("save.dmsync")
                if !self.fileManager.fileExists(atPath: stagedDmsync.path) {
                    try? self.fileManager.copyItem(at: parentDmsync, to: stagedDmsync)
                }
            }

            // Transfer staged files to device container using devicectl
            var transferSuccess = false

            // 1. Copy save directory to Documents/save
            let copySaveProc = Process()
            copySaveProc.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            copySaveProc.arguments = [
                "devicectl", "device", "copy", "to",
                "--device", device.id,
                "--domain-type", "appDataContainer",
                "--domain-identifier", realBundleId,
                "--source", stagedSave.path,
                "--destination", "Documents",
                "-q"
            ]
            let wd = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
            wd.schedule(deadline: .now() + 30.0)
            wd.setEventHandler { [weak copySaveProc] in if let p = copySaveProc, p.isRunning { p.terminate() } }
            if (try? copySaveProc.run()) != nil {
                wd.resume()
                copySaveProc.waitUntilExit()
                wd.cancel()
                transferSuccess = (copySaveProc.terminationStatus == 0)
            }

            // 2. Also copy save.dmsync if present to Documents/save.dmsync
            let stagedDmsync = tempDir.appendingPathComponent("save.dmsync")
            if self.fileManager.fileExists(atPath: stagedDmsync.path) {
                let copyDmProc = Process()
                copyDmProc.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
                copyDmProc.arguments = [
                    "devicectl", "device", "copy", "to",
                    "--device", device.id,
                    "--domain-type", "appDataContainer",
                    "--domain-identifier", realBundleId,
                    "--source", stagedDmsync.path,
                    "--destination", "Documents/save.dmsync",
                    "-q"
                ]
                let wdDm = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
                wdDm.schedule(deadline: .now() + 20.0)
                wdDm.setEventHandler { [weak copyDmProc] in if let p = copyDmProc, p.isRunning { p.terminate() } }
                if (try? copyDmProc.run()) != nil {
                    wdDm.resume()
                    copyDmProc.waitUntilExit()
                    wdDm.cancel()
                }
            }

            // 3. If Hub structure or target, copy into Documents/games/<TitleId>/save
            let hubGameFolder = tempDir.appendingPathComponent("games/\(titleId.uppercased())", isDirectory: true)
            try? self.fileManager.createDirectory(at: hubGameFolder, withIntermediateDirectories: true)
            let hubSaveInner = hubGameFolder.appendingPathComponent("save", isDirectory: true)
            try? self.fileManager.copyItem(at: stagedSave, to: hubSaveInner)
            if self.fileManager.fileExists(atPath: stagedDmsync.path) {
                try? self.fileManager.copyItem(at: stagedDmsync, to: hubGameFolder.appendingPathComponent("save.dmsync"))
            }

            let gamesContainer = tempDir.appendingPathComponent("games", isDirectory: true)
            let copyHubProc = Process()
            copyHubProc.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            copyHubProc.arguments = [
                "devicectl", "device", "copy", "to",
                "--device", device.id,
                "--domain-type", "appDataContainer",
                "--domain-identifier", realBundleId,
                "--source", gamesContainer.path,
                "--destination", "Documents",
                "-q"
            ]
            let wdHub = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
            wdHub.schedule(deadline: .now() + 30.0)
            wdHub.setEventHandler { [weak copyHubProc] in if let p = copyHubProc, p.isRunning { p.terminate() } }
            if (try? copyHubProc.run()) != nil {
                wdHub.resume()
                copyHubProc.waitUntilExit()
                wdHub.cancel()
                if copyHubProc.terminationStatus == 0 {
                    transferSuccess = true
                }
            }

            DispatchQueue.main.async {
                if transferSuccess {
                    completion(true, "Save do iCloud restaurado com sucesso para \(device.name)!")
                } else {
                    completion(false, "Falha ao enviar save para o container do app no dispositivo.")
                }
            }
        }
    }
}
