import Foundation
import AppKit

extension AppViewModel {
    static let provisioningVersion = "1.9.7"
    private static let provisioningVersionKey = "NXNative_ProvisioningVersion"

    /// True when no game launch or port is in progress, so background work may run.
    private var isSafeForBackgroundProvisioning: Bool {
        !isBuilding && launchingGameId == nil
    }

    /// Entry point (called once from init): first-run provisioning, v1.9.7 migration and the 60 s auto-update loop.
    public func startAutoProvisioning() {
        let saved = UserDefaults.standard.string(forKey: Self.provisioningVersionKey)
        if saved != Self.provisioningVersion {
            logs.append(LogEntry(level: .info, message: "[Provisioning] First run on v\(Self.provisioningVersion) (previous: \(saved ?? "none")). Installing everything that is missing…"))
            UserDefaults.standard.set(Self.provisioningVersion, forKey: Self.provisioningVersionKey)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in self?.provisioningTick() }
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in self?.provisioningTick() }
        RunLoop.main.add(timer, forMode: .common)
        provisioningTimer = timer
    }

    /// Runs every 60 s. Always non-blocking and skipped during builds / launches.
    public func provisioningTick() {
        guard isSafeForBackgroundProvisioning, !isProvisioningBusy else { return }

        // 1. Core Repository missing → download it.
        if !isNxnativeValid {
            guard !isCloningRepository, Date() >= nextCloneAttempt else { return }
            nextCloneAttempt = Date().addingTimeInterval(300)
            provisioningStatus = "Downloading Core Repository…"
            cloneNxnativeRepository()
            return
        }

        // 2. Missing tools (Xcode itself needs the user; everything else is automatic).
        let missing = prerequisites.missingList.filter { $0.id != "xcode" }
        if !missing.isEmpty, !isInstallingDependency, !isCheckingPrerequisites, Date() >= nextDependencyAttempt {
            nextDependencyAttempt = Date().addingTimeInterval(1800)
            provisioningStatus = "Installing \(missing.count) missing tool(s)…"
            isInstallingDependency = true
            installer.installAll(dependencies: missing) { [weak self] ok in
                self?.isInstallingDependency = false
                self?.provisioningStatus = ""
                self?.refreshPrerequisites()
                self?.logs.append(LogEntry(level: ok ? .success : .warning, message: "[Provisioning] Tool installation \(ok ? "completed" : "had failures; will retry later")."))
            }
            return
        }

        // 3. Metal Toolchain (Xcode 26+ ships it as a separate download).
        if let metal = metalToolchainInfo, !metal.isAvailable, Date() >= nextMetalAttempt,
           FileManager.default.fileExists(atPath: "/usr/bin/xcodebuild") {
            nextMetalAttempt = Date().addingTimeInterval(6 * 3600)
            provisioningStatus = "Downloading Metal Toolchain…"
            isProvisioningBusy = true
            DispatchQueue.global(qos: .utility).async { [weak self] in
                let res = BoundedProcess.run("/usr/bin/xcodebuild", ["-downloadComponent", "MetalToolchain"], timeout: 3600)
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.isProvisioningBusy = false
                    self.provisioningStatus = ""
                    self.logs.append(LogEntry(level: res.success ? .success : .warning,
                        message: "[Provisioning] Metal Toolchain \(res.success ? "installed" : "download failed/skipped")."))
                    self.detectMetalToolchain()
                }
            }
            return
        }

        // 4. Core Repository auto-update (fetch + fast-forward).
        let repo = nxnativePath
        isProvisioningBusy = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let result = CoreRepoAutoUpdater.shared.updateIfNeeded(repoPath: repo)
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isProvisioningBusy = false
                self.coreRepoLastCheck = Date()
                switch result {
                case .updated(let head):
                    // Never touch the tree under a running build/launch: re-check before patching.
                    PatchService.shared.applyPatchesIfNeeded(nxnativePath: repo)
                    self.refreshEnginePatches()
                    self.checkForUpdates()
                    self.logs.append(LogEntry(level: .success, message: "[Core Repo] Auto-updated to \(head)."))
                case .failed(let msg):
                    self.logs.append(LogEntry(level: .warning, message: "[Core Repo] Auto-update failed (will retry with backoff): \(msg.prefix(160))"))
                case .skipped(let reason) where reason != "backoff":
                    self.logs.append(LogEntry(level: .info, message: "[Core Repo] Auto-update skipped: \(reason)"))
                default:
                    break
                }
            }
        }
    }
}
