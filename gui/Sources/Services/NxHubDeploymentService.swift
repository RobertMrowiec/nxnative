import Foundation
import AppKit

// MARK: - NxN Launcher Deployment Service

/// Manages high-speed deployment to the unified NxN Launcher container on iOS/iPadOS.
public final class NxHubDeploymentService: ObservableObject {
    public static let shared = NxHubDeploymentService()

    @Published public var deploymentMode: NxDeploymentTargetMode = .consoleHub
    @Published public var isHotDropping: Bool = false
    @Published public var hotDropProgress: Double = 0.0
    @Published public var currentActionMessage: String = ""
    @Published public var useExternalStorage: Bool = false
    @Published public var detectedHubBundleId: String? = nil

    public static var hubBundleId: String {
        let userName = NSUserName().lowercased().filter { $0.isLetter || $0.isNumber }
        let userPrefix = userName.isEmpty ? "developer" : userName
        return "com.\(userPrefix).nxnative.hub"
    }

    private init() {
        self.deploymentMode = .consoleHub
    }

    public func setDeploymentMode(_ mode: NxDeploymentTargetMode) {
        self.deploymentMode = .consoleHub
        UserDefaults.standard.set(NxDeploymentTargetMode.consoleHub.rawValue, forKey: "NXNative_SavedDeploymentMode")
    }

    /// Resolves the concrete bundle identifier deployed on the device for this Hub container.
    public func resolveHubBundleId(for game: PortedGame, on device: ConnectedAppleDevice) -> String {
        if let detected = self.detectedHubBundleId, !detected.isEmpty {
            return detected
        }
        let savedState = loadShellLibrary()
        if !savedState.bundleID.isEmpty {
            return savedState.bundleID
        }
        return Self.hubBundleId
    }

    /// Verifies if NxN Launcher is installed on the target iOS device with bounded timeout.
    public func isHubAppInstalled(on device: ConnectedAppleDevice, completion: @escaping (Bool) -> Void) {
        guard device.isAvailable else {
            DispatchQueue.main.async { completion(false) }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let proc = Process()
            let pipe = Pipe()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            proc.arguments = ["devicectl", "device", "info", "apps", "--device", device.id, "--json-output", "-"]
            proc.standardOutput = pipe
            proc.standardError = Pipe()

            let watchdog = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
            watchdog.schedule(deadline: .now() + 3.5)
            watchdog.setEventHandler { [weak proc] in
                if let p = proc, p.isRunning {
                    p.terminate()
                }
            }
            watchdog.resume()

            do {
                try proc.run()
                proc.waitUntilExit()
                watchdog.cancel()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let result = json["result"] as? [String: Any],
                      let apps = result["apps"] as? [[String: Any]] else {
                    DispatchQueue.main.async { completion(false) }
                    return
                }

                var matchedId: String? = nil
                let targetBid = Self.hubBundleId
                for app in apps {
                    let bid = (app["bundleIdentifier"] as? String) ?? ""
                    if bid == targetBid || (bid.hasPrefix("com.") && bid.hasSuffix(".nxnative.hub")) || bid == "org.nxnative.shell" {
                        matchedId = bid
                        break
                    }
                }

                DispatchQueue.main.async {
                    if let found = matchedId {
                        self?.detectedHubBundleId = found
                        completion(true)
                    } else {
                        completion(false)
                    }
                }
            } catch {
                watchdog.cancel()
                DispatchQueue.main.async { completion(false) }
            }
        }
    }

    /// Injects Hub metadata and dark icon when needed.
    public func injectHubMetadataAndDarkIcon(targetAppURL: URL) {
        let infoPlistURL = targetAppURL.appendingPathComponent("Info.plist")
        if var infoDict = try? PropertyListSerialization.propertyList(from: Data(contentsOf: infoPlistURL), options: .mutableContainers, format: nil) as? [String: Any] {
            infoDict["CFBundleDisplayName"] = "NxN Launcher"
            infoDict["CFBundleName"] = "NxN Launcher"
            if let updatedData = try? PropertyListSerialization.data(fromPropertyList: infoDict, format: .xml, options: 0) {
                try? updatedData.write(to: infoPlistURL)
            }
        }
    }

    /// Deploys a game to NxN Launcher. If NxN Launcher is not installed, installs it automatically first.
    public func deployToHub(
        game: PortedGame,
        device: ConnectedAppleDevice,
        team: DeveloperSigningTeam?,
        completion: @escaping (Bool, String) -> Void
    ) {
        guard !isHotDropping else {
            completion(false, "A deployment is already running.")
            return
        }

        // Fast zero-delay preflight: abort immediately if device is locked/unavailable
        guard device.isAvailable else {
            DeviceDeploymentService.shared.failDeployment(
                category: .deviceLocked,
                title: "\(device.name) está Indisponível ou Bloqueado",
                detail: "O iPhone precisa estar com a tela acesa e desbloqueada.\n1. Digite a senha na tela do iPhone.\n2. Se solicitado, confirme 'Confiar neste Computador'.\n3. Verifique o cabo USB e tente novamente."
            )
            SoundEffectService.shared.play(.error)
            completion(false, "Device is locked or unavailable.")
            return
        }

        self.isHotDropping = true
        self.hotDropProgress = 0.08
        self.currentActionMessage = "Verifying NxN Launcher on \(device.name)..."

        DispatchQueue.main.async {
            DeviceDeploymentService.shared.activeDeployment = DeploymentProgressInfo(
                phase: .connecting,
                progressFraction: 0.10,
                statusMessage: "Checking NxN Launcher on \(device.name)...",
                detailMessage: "Verifying container app installation...",
                logLines: [
                    "==> Connecting to \(device.name)...",
                    "==> Checking for NxN Launcher container..."
                ],
                isRunning: true,
                targetDeviceName: device.name,
                elapsedSeconds: 0
            )
            DeviceDeploymentService.shared.startElapsedTimer()
        }

        isHubAppInstalled(on: device) { [weak self] installed in
            guard let self = self else { return }

            let titleId = game.titleId?.uppercased() ?? "0100000000000000"

            self.ensureFramework(for: game, device: device, team: team) { [weak self] fwOk, fwURL, fwErr in
                guard let self = self else { return }
                guard fwOk, let fw = fwURL else {
                    self.isHotDropping = false
                    DispatchQueue.main.async {
                        DeviceDeploymentService.shared.stopElapsedTimer()
                        DeviceDeploymentService.shared.activeDeployment.isRunning = false
                        DeviceDeploymentService.shared.failDeployment(
                            category: .generic(fwErr ?? "Missing Framework"),
                            title: "Framework do Jogo Não Encontrado",
                            detail: fwErr ?? "Não foi possível gerar DmGame\(titleId).framework para o NxN Launcher."
                        )
                    }
                    completion(false, fwErr ?? "Framework not found")
                    return
                }

                do {
                    try self.registerGameInHub(titleId: titleId, name: game.name, frameworkPath: fw.path)
                } catch {
                    self.isHotDropping = false
                    DispatchQueue.main.async {
                        DeviceDeploymentService.shared.stopElapsedTimer()
                        DeviceDeploymentService.shared.activeDeployment.isRunning = false
                    }
                    completion(false, "Failed to register game in shell.json: \(error.localizedDescription)")
                    return
                }

                let state = self.loadShellLibrary()

                if !installed {
                    DispatchQueue.main.async {
                        DeviceDeploymentService.shared.activeDeployment.phase = .installing
                        DeviceDeploymentService.shared.activeDeployment.progressFraction = 0.20
                        DeviceDeploymentService.shared.activeDeployment.statusMessage = "Installing NxN Launcher on \(device.name)..."
                        DeviceDeploymentService.shared.activeDeployment.detailMessage = "First-time setup: Building & deploying NxN Launcher with dark icon..."
                        DeviceDeploymentService.shared.activeDeployment.logLines.append("==> NxN Launcher not detected. Preparing & installing container app...")
                    }

                    self.prepareShellProject(library: state, teamId: team?.id ?? "0000000000") { [weak self] prepOk, prepMsg in
                        guard let self = self else { return }
                        guard prepOk else {
                            self.isHotDropping = false
                            DispatchQueue.main.async {
                                DeviceDeploymentService.shared.stopElapsedTimer()
                                DeviceDeploymentService.shared.activeDeployment.isRunning = false
                                DeviceDeploymentService.shared.failDeployment(category: .generic(prepMsg), title: "Project Preparation Failed", detail: prepMsg)
                            }
                            completion(false, prepMsg)
                            return
                        }

                        self.compileAndInstallShell(device: device, team: team) { [weak self] instOk, instMsg in
                            guard let self = self else { return }
                            if instOk {
                                DispatchQueue.main.async {
                                    DeviceDeploymentService.shared.activeDeployment.logLines.append("[OK] NxN Launcher installed successfully! Sending game data...")
                                }
                                self.executeHotDropTransfer(game: game, device: device, completion: completion)
                            } else {
                                self.isHotDropping = false
                                DispatchQueue.main.async {
                                    DeviceDeploymentService.shared.stopElapsedTimer()
                                    DeviceDeploymentService.shared.activeDeployment.isRunning = false
                                    DeviceDeploymentService.shared.failDeployment(category: .generic(instMsg), title: "NxN Launcher Installation Failed", detail: instMsg)
                                }
                                completion(false, instMsg)
                            }
                        }
                    }
                } else {
                    // Hub is installed! Update project to embed new framework and reinstall (fast update)
                    DispatchQueue.main.async {
                        DeviceDeploymentService.shared.activeDeployment.phase = .signing
                        DeviceDeploymentService.shared.activeDeployment.progressFraction = 0.30
                        DeviceDeploymentService.shared.activeDeployment.statusMessage = "Updating NxN Launcher on \(device.name)..."
                        DeviceDeploymentService.shared.activeDeployment.detailMessage = "Embedding \(game.name) into NxN Launcher..."
                        DeviceDeploymentService.shared.activeDeployment.logLines.append("==> Embedding new game framework into NxN Launcher...")
                    }

                    self.prepareShellProject(library: state, teamId: team?.id ?? "0000000000") { [weak self] prepOk, prepMsg in
                        guard let self = self else { return }
                        guard prepOk else {
                            self.isHotDropping = false
                            DispatchQueue.main.async {
                                DeviceDeploymentService.shared.stopElapsedTimer()
                                DeviceDeploymentService.shared.activeDeployment.isRunning = false
                                DeviceDeploymentService.shared.failDeployment(category: .generic(prepMsg), title: "Project Preparation Failed", detail: prepMsg)
                            }
                            completion(false, prepMsg)
                            return
                        }

                        self.compileAndInstallShell(device: device, team: team) { [weak self] instOk, instMsg in
                            guard let self = self else { return }
                            if instOk {
                                DispatchQueue.main.async {
                                    DeviceDeploymentService.shared.activeDeployment.logLines.append("[OK] NxN Launcher updated! Sending RomFS...")
                                }
                                self.executeHotDropTransfer(game: game, device: device, completion: completion)
                            } else {
                                self.isHotDropping = false
                                DispatchQueue.main.async {
                                    DeviceDeploymentService.shared.stopElapsedTimer()
                                    DeviceDeploymentService.shared.activeDeployment.isRunning = false
                                    DeviceDeploymentService.shared.failDeployment(category: .generic(instMsg), title: "NxN Launcher Update Failed", detail: instMsg)
                                }
                                completion(false, instMsg)
                            }
                        }
                    }
                }
            }
        }
    }
}
