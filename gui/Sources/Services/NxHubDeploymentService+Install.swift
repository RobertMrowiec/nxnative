import Foundation
import AppKit

// MARK: - Route C Shell Compilation and Device Installation

extension NxHubDeploymentService {
    /// Compiles DmShell with the user's signing identity and installs it onto the target device.
    public func compileAndInstallShell(
        device: ConnectedAppleDevice,
        team: DeveloperSigningTeam?,
        completion: @escaping (Bool, String) -> Void
    ) {
        let teamId = team?.id ?? "0000000000"
        let projectPath = hubProjectURL.appendingPathComponent("DmShell.xcodeproj").path

        guard FileManager.default.fileExists(atPath: projectPath) else {
            completion(false, "Shell project does not exist at \(projectPath)")
            return
        }

        DispatchQueue.main.async {
            DeviceDeploymentService.shared.activeDeployment.phase = .signing
            DeviceDeploymentService.shared.activeDeployment.statusMessage = "Compiling NxN Launcher..."
            DeviceDeploymentService.shared.activeDeployment.detailMessage = "Building DmShell for \(device.name)..."
            DeviceDeploymentService.shared.activeDeployment.logLines.append("==> Building DmShell.app with Xcode for NxN Launcher...")
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let buildProc = Process()
            let buildPipe = Pipe()
            buildProc.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            buildProc.arguments = [
                "xcodebuild",
                "-project", projectPath,
                "-scheme", "DmShell",
                "-configuration", "Release",
                "-destination", "id=\(device.id)",
                "-derivedDataPath", self.hubDerivedDataURL.path,
                "-allowProvisioningUpdates",
                "DEVELOPMENT_TEAM=\(teamId)",
                "build"
            ]

            var buildEnv = ProcessInfo.processInfo.environment
            let path = buildEnv["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
            buildEnv["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + path
            buildProc.environment = buildEnv
            buildProc.standardOutput = buildPipe
            buildProc.standardError = buildPipe

            let buildWatchdog = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
            buildWatchdog.schedule(deadline: .now() + 180.0)
            buildWatchdog.setEventHandler { [weak buildProc] in
                if let p = buildProc, p.isRunning {
                    p.terminate()
                }
            }
            buildWatchdog.resume()

            do {
                try buildProc.run()
                buildProc.waitUntilExit()
                buildWatchdog.cancel()

                let buildOut = String(data: buildPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                guard buildProc.terminationStatus == 0 else {
                    let errLine = buildOut.split(separator: "\n").filter { $0.contains("error:") }.last ?? "Compilation failed"
                    DispatchQueue.main.async {
                        completion(false, "xcodebuild failed (\(buildProc.terminationStatus)): \(errLine)")
                    }
                    return
                }

                // Verify built .app
                let builtApp = self.hubDerivedDataURL
                    .appendingPathComponent("Build/Products/Release-iphoneos/DmShell.app")
                guard FileManager.default.fileExists(atPath: builtApp.path) else {
                    DispatchQueue.main.async {
                        completion(false, "Built app not found at \(builtApp.path)")
                    }
                    return
                }

                DispatchQueue.main.async {
                    DeviceDeploymentService.shared.activeDeployment.phase = .installing
                    DeviceDeploymentService.shared.activeDeployment.statusMessage = "Installing Hub onto \(device.name)..."
                    DeviceDeploymentService.shared.activeDeployment.detailMessage = "Installing DmShell via devicectl..."
                    DeviceDeploymentService.shared.activeDeployment.logLines.append("==> Installing DmShell.app via devicectl...")
                }

                // Install on device
                let installProc = Process()
                let installPipe = Pipe()
                installProc.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
                installProc.arguments = [
                    "devicectl", "device", "install", "app",
                    "--device", device.id,
                    builtApp.path
                ]
                installProc.environment = buildEnv
                installProc.standardOutput = installPipe
                installProc.standardError = installPipe

                let installWatchdog = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
                installWatchdog.schedule(deadline: .now() + 60.0)
                installWatchdog.setEventHandler { [weak installProc] in
                    if let p = installProc, p.isRunning {
                        p.terminate()
                    }
                }
                installWatchdog.resume()

                try installProc.run()
                installProc.waitUntilExit()
                installWatchdog.cancel()

                let installOut = String(data: installPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                if installProc.terminationStatus == 0 {
                    DispatchQueue.main.async {
                        self.detectedHubBundleId = self.loadShellLibrary().bundleID
                        completion(true, "NxN Launcher instalado com sucesso.")
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(false, "Installation failed: \(installOut)")
                    }
                }
            } catch {
                buildWatchdog.cancel()
                DispatchQueue.main.async {
                    completion(false, "Shell installation error: \(error.localizedDescription)")
                }
            }
        }
    }
}
