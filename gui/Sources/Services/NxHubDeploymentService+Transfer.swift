import Foundation
import AppKit

// MARK: - NxN Launcher Route C Asset Transfer Extension

extension NxHubDeploymentService {
    internal func executeHotDropTransfer(
        game: PortedGame,
        device: ConnectedAppleDevice,
        completion: @escaping (Bool, String) -> Void
    ) {
        let fm = FileManager.default
        let titleId = game.titleId?.uppercased() ?? "0100000000000000"
        let parentDir = game.url.deletingLastPathComponent()

        var romfsURL: URL? = nil
        let candidates = [
            parentDir.appendingPathComponent("\(game.name).romfs.img"),
            parentDir.appendingPathComponent("RomFS.img"),
            parentDir.appendingPathComponent("romfs.img"),
            game.url.appendingPathComponent("romfs.img"),
            game.url.appendingPathComponent("Contents/Resources/romfs.img"),
            URL(fileURLWithPath: "/Volumes/SSD FN501 PRO/Emulations/Nx Ports/\(game.name).romfs.img"),
            URL(fileURLWithPath: "/Volumes/SSD FN501 PRO/Emulations/Nx Ports/romfs.img")
        ]
        for c in candidates where fm.fileExists(atPath: c.path) {
            romfsURL = c
            break
        }

        if romfsURL == nil {
            // Check Switch NSP build/extract directories on Nintendo storage
            let nintendoBase = URL(fileURLWithPath: "/Volumes/Nintendo/Games")
            if let entries = try? fm.contentsOfDirectory(at: nintendoBase, includingPropertiesForKeys: nil) {
                for folder in entries {
                    let buildDir = folder.appendingPathComponent("\(titleId)_build/extract")
                    if let vers = try? fm.contentsOfDirectory(at: buildDir, includingPropertiesForKeys: nil) {
                        for ver in vers {
                            let img1 = ver.appendingPathComponent("RomFS.img")
                            let img2 = ver.appendingPathComponent("romfs.img")
                            if fm.fileExists(atPath: img1.path) { romfsURL = img1; break }
                            if fm.fileExists(atPath: img2.path) { romfsURL = img2; break }
                        }
                    }
                    if romfsURL != nil { break }
                }
            }
        }

        if romfsURL == nil, game.url.pathExtension.lowercased() == "ipa" {
            // Unpack romfs.img directly from IPA if not on disk
            let extractedDest = parentDir.appendingPathComponent("\(game.name).romfs.img")
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            proc.arguments = ["-j", "-o", game.url.path, "Payload/*.app/romfs.img", "-d", parentDir.path]
            try? proc.run()
            proc.waitUntilExit()
            let unpacked = parentDir.appendingPathComponent("romfs.img")
            if fm.fileExists(atPath: unpacked.path) {
                try? fm.moveItem(at: unpacked, to: extractedDest)
                romfsURL = extractedDest
            }
        }

        let isExternal = self.useExternalStorage
        let hasSave = SaveSyncService.shared.locateExistingSave(titleId: titleId, gameName: game.name) != nil

        DispatchQueue.main.async {
            self.hotDropProgress = 0.35
            self.currentActionMessage = "Staging game folder for NxN Launcher..."
            DeviceDeploymentService.shared.activeDeployment.phase = .transferring
            DeviceDeploymentService.shared.activeDeployment.progressFraction = 0.35
            DeviceDeploymentService.shared.activeDeployment.statusMessage = "Preparando pasta no NxN Launcher..."
            DeviceDeploymentService.shared.activeDeployment.logLines.append("==> Preparando estrutura de pasta para \(game.name)...")
        }

        let stageDir = fm.temporaryDirectory.appendingPathComponent("hub_stage_\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: stageDir) }
        let gamesFolder = stageDir.appendingPathComponent("games", isDirectory: true)
        let thisGameFolder = gamesFolder.appendingPathComponent(titleId, isDirectory: true)
        try? fm.createDirectory(at: thisGameFolder, withIntermediateDirectories: true)

        let manifest = NxHubGameItem(
            titleId: titleId,
            name: game.name,
            displayVersion: game.versionString ?? "1.0.0",
            romfsSize: romfsURL != nil ? (try? fm.attributesOfItem(atPath: romfsURL!.path)[.size] as? Int64) ?? 0 : 0,
            hasPatch: false,
            hasDLC: false,
            isSwitch2: game.name.contains("Switch 2") || game.name.contains("NUP"),
            storageLocation: isExternal ? .externalDrive(bookmarkData: Data(), pathDisplay: "SSD USB-C") : .internalContainer,
            launchSettings: NxHubGameSettings(),
            hasSave: hasSave
        )

        let manifestFile = thisGameFolder.appendingPathComponent("manifest.json")
        if let data = try? JSONEncoder().encode(manifest) {
            try? data.write(to: manifestFile)
        }

        // Copy existing save into staged folder if found
        if let saveSource = SaveSyncService.shared.locateExistingSave(titleId: titleId, gameName: game.name) {
            let stagedGameSave = thisGameFolder.appendingPathComponent("save", isDirectory: true)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: saveSource.path, isDirectory: &isDir), isDir.boolValue {
                try? fm.copyItem(at: saveSource, to: stagedGameSave)
            } else if saveSource.lastPathComponent.hasSuffix(".dmsync") {
                SaveSyncService.shared.unpackDMSync(at: saveSource, into: stagedGameSave)
                try? fm.copyItem(at: saveSource, to: thisGameFolder.appendingPathComponent("save.dmsync"))
            }
        }

        // 1. Copy staged games folder to Documents (creates Documents/games/<TitleId> reliably)
        self.copyFileToHub(
            sourceURL: gamesFolder,
            destinationSubpath: "Documents",
            device: device,
            game: game
        ) { [weak self] folderSuccess in
            guard let self = self, folderSuccess else {
                DispatchQueue.main.async {
                    self?.isHotDropping = false
                    DeviceDeploymentService.shared.failDeployment(
                        category: .generic("Folder Creation Failed"),
                        title: "Falha na Criação da Pasta",
                        detail: "Não foi possível criar a pasta do jogo no container do NxN Launcher."
                    )
                    completion(false, "Failed to create game directory in Hub.")
                }
                return
            }

            DispatchQueue.main.async {
                DeviceDeploymentService.shared.activeDeployment.logLines.append("[OK] Estrutura Documents/games/\(titleId) criada com sucesso.")
            }

            if isExternal {
                DispatchQueue.main.async {
                    self.isHotDropping = false
                    self.hotDropProgress = 1.0
                    DeviceDeploymentService.shared.stopElapsedTimer()
                    DeviceDeploymentService.shared.activeDeployment.isRunning = false
                    DeviceDeploymentService.shared.activeDeployment.phase = .completed
                    DeviceDeploymentService.shared.activeDeployment.progressFraction = 1.0
                    DeviceDeploymentService.shared.activeDeployment.statusMessage = "Pronto no NxN Launcher via SSD!"
                    DeviceDeploymentService.shared.activeDeployment.detailMessage = "\(game.name) configurado para rodar direto do SSD USB-C no \(device.name)."
                    DeviceDeploymentService.shared.activeDeployment.logLines.append("[SUCCESS] \(game.name) pronto para inicialização via SSD externo!")
                    SoundEffectService.shared.play(.click)
                    completion(true, "Configured \(game.name) for external SSD play on \(device.name).")
                }
                return
            }

            if let romfs = romfsURL {
                DispatchQueue.main.async {
                    self.hotDropProgress = 0.55
                    self.currentActionMessage = "Transferring game data (romfs.img) to NxN Launcher..."
                    DeviceDeploymentService.shared.activeDeployment.phase = .copyingRomFS
                    DeviceDeploymentService.shared.activeDeployment.progressFraction = 0.55
                    DeviceDeploymentService.shared.activeDeployment.statusMessage = "Transferindo RomFS para o NxN Launcher..."
                    DeviceDeploymentService.shared.activeDeployment.logLines.append("==> Transferindo RomFS (\(romfs.lastPathComponent))...")
                }

                self.copyFileToHub(
                    sourceURL: romfs,
                    destinationSubpath: "Documents/games/\(titleId)/romfs.img",
                    device: device,
                    game: game
                ) { [weak self] romfsSuccess in
                    guard let self = self else { return }
                    if !romfsSuccess {
                        DispatchQueue.main.async {
                            self.isHotDropping = false
                            DeviceDeploymentService.shared.failDeployment(
                                category: .generic("RomFS Transfer Failed"),
                                title: "Falha ao Copiar RomFS",
                                detail: "Houve um erro ao transferir romfs.img para a pasta do jogo no Hub."
                            )
                            completion(false, "Failed to copy romfs.img to Hub container.")
                        }
                        return
                    }

                    // Auto-restore iCloud save into device container Documents/save
                    let hubBid = self.resolveHubBundleId(for: game, on: device)
                    SaveSyncService.shared.restoreICloudSaveToDevice(
                        titleId: titleId,
                        gameName: game.name,
                        bundleId: hubBid,
                        device: device
                    ) { saveOk, _ in
                        DispatchQueue.main.async {
                            self.isHotDropping = false
                            self.hotDropProgress = 1.0
                            DeviceDeploymentService.shared.stopElapsedTimer()
                            self.currentActionMessage = "Game ready in NxN Launcher!"
                            DeviceDeploymentService.shared.activeDeployment.isRunning = false
                            DeviceDeploymentService.shared.activeDeployment.phase = .completed
                            DeviceDeploymentService.shared.activeDeployment.progressFraction = 1.0
                            DeviceDeploymentService.shared.activeDeployment.statusMessage = "Jogo pronto no NxN Launcher!"
                            DeviceDeploymentService.shared.activeDeployment.detailMessage = "\(game.name) foi adicionado com sucesso ao NxN Launcher no \(device.name)."
                            DeviceDeploymentService.shared.activeDeployment.logLines.append("[SUCCESS] \(game.name) pronto no NxN Launcher!")
                            if saveOk {
                                DeviceDeploymentService.shared.activeDeployment.logLines.append("[OK] Save do iCloud restaurado automaticamente.")
                            }
                            SoundEffectService.shared.play(.click)
                            completion(true, "Successfully added \(game.name) to NxN Launcher on \(device.name)!")
                        }
                    }
                }
            } else {
                // No RomFS to transfer
                let hubBid = self.resolveHubBundleId(for: game, on: device)
                SaveSyncService.shared.restoreICloudSaveToDevice(
                    titleId: titleId,
                    gameName: game.name,
                    bundleId: hubBid,
                    device: device
                ) { _, _ in
                    DispatchQueue.main.async {
                        self.isHotDropping = false
                        self.hotDropProgress = 1.0
                        DeviceDeploymentService.shared.stopElapsedTimer()
                        DeviceDeploymentService.shared.activeDeployment.isRunning = false
                        DeviceDeploymentService.shared.activeDeployment.phase = .completed
                        DeviceDeploymentService.shared.activeDeployment.progressFraction = 1.0
                        DeviceDeploymentService.shared.activeDeployment.statusMessage = "Jogo registrado no NxN Launcher!"
                        DeviceDeploymentService.shared.activeDeployment.detailMessage = "\(game.name) foi registrado no container do NxN Launcher."
                        SoundEffectService.shared.play(.click)
                        completion(true, "Registered \(game.name) in Hub.")
                    }
                }
            }
        }
    }

    internal func copyFileToHub(
        sourceURL: URL,
        destinationSubpath: String,
        device: ConnectedAppleDevice,
        game: PortedGame? = nil,
        completion: @escaping (Bool) -> Void
    ) {
        let domainId: String
        if let detected = self.detectedHubBundleId, !detected.isEmpty {
            domainId = detected
        } else if let g = game {
            domainId = self.resolveHubBundleId(for: g, on: device)
        } else {
            domainId = Self.hubBundleId
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        proc.arguments = [
            "devicectl", "device", "copy", "to",
            "--device", device.id,
            "--domain-type", "appDataContainer",
            "--domain-identifier", domainId,
            "--source", sourceURL.path,
            "--destination", destinationSubpath,
            "-q"
        ]

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: sourceURL.path)[.size] as? Int64) ?? 0
        let timeoutSeconds = max(180.0, (Double(fileSize) / (15.0 * 1024.0 * 1024.0)) + 120.0)

        let watchdog = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        watchdog.schedule(deadline: .now() + timeoutSeconds)
        watchdog.setEventHandler { [weak proc] in
            if let p = proc, p.isRunning {
                p.terminate()
            }
        }
        watchdog.resume()

        proc.terminationHandler = { process in
            watchdog.cancel()
            completion(process.terminationStatus == 0)
        }

        do {
            try proc.run()
        } catch {
            watchdog.cancel()
            completion(false)
        }
    }
}
