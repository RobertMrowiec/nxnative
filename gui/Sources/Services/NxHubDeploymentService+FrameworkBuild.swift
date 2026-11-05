import Foundation
import AppKit

// MARK: - On-The-Fly Framework Building for NxN Launcher

extension NxHubDeploymentService {
    /// Discovers candidate NSP, build directory, or source folder for the given game.
    private func locateSourceOrBuildDirectory(for game: PortedGame) -> URL? {
        let fm = FileManager.default
        let titleId = game.titleId?.uppercased() ?? ""

        // 1. Check known staging directories
        let stagingBase = URL(fileURLWithPath: "/Volumes/SSD FN501 PRO/Emulations/NativePort/Staging")
        if let subs = try? fm.contentsOfDirectory(at: stagingBase, includingPropertiesForKeys: nil) {
            for sub in subs {
                let buildDir = sub.appendingPathComponent("\(titleId)_build")
                if fm.fileExists(atPath: buildDir.path) {
                    return sub
                }
            }
        }

        // 2. Check Nintendo Games directories
        let nintendoBase = URL(fileURLWithPath: "/Volumes/Nintendo/Games")
        if let entries = try? fm.contentsOfDirectory(at: nintendoBase, includingPropertiesForKeys: nil) {
            for folder in entries {
                let buildDir = folder.appendingPathComponent("\(titleId)_build")
                if fm.fileExists(atPath: buildDir.path) {
                    return folder
                }
                // Check if folder contains NSP for this titleId
                if let files = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
                    for f in files where f.pathExtension.lowercased() == "nsp" && (f.lastPathComponent.contains(titleId) || f.lastPathComponent.localizedCaseInsensitiveContains(game.name)) {
                        return folder
                    }
                }
            }
        }

        // 3. Check game URL parent directory
        let parent = game.url.deletingLastPathComponent()
        let directBuild = parent.appendingPathComponent("\(titleId)_build")
        if fm.fileExists(atPath: directBuild.path) {
            return parent
        }

        return nil
    }

    /// Ensures that DmGame<TitleID>.framework exists. If missing, attempts to compile it on-the-fly.
    public func ensureFramework(
        for game: PortedGame,
        device: ConnectedAppleDevice,
        team: DeveloperSigningTeam?,
        completion: @escaping (Bool, URL?, String?) -> Void
    ) {
        let fm = FileManager.default
        let titleId = game.titleId?.uppercased() ?? "0100000000000000"
        let fw = hubFrameworksURL.appendingPathComponent("DmGame\(titleId).framework")

        // 1. Check if already in Hub frameworks directory
        if fm.fileExists(atPath: fw.path) {
            completion(true, fw, nil)
            return
        }

        // 2. Check temporary build caches
        let tempCandidates = [
            URL(fileURLWithPath: "/private/tmp/hub_frameworks/DmGame\(titleId).framework"),
            URL(fileURLWithPath: "/tmp/hub_frameworks/DmGame\(titleId).framework")
        ]
        for tempFw in tempCandidates where fm.fileExists(atPath: tempFw.path) {
            try? fm.createDirectory(at: hubFrameworksURL, withIntermediateDirectories: true)
            try? fm.copyItem(at: tempFw, to: fw)
            if fm.fileExists(atPath: fw.path) {
                completion(true, fw, nil)
                return
            }
        }

        // 3. Locate source directory to compile framework
        guard let sourceDir = locateSourceOrBuildDirectory(for: game) else {
            let errorMsg = "Não foi encontrada pasta de origem ou NSP para \(game.name) (\(titleId))."
            completion(false, nil, errorMsg)
            return
        }

        DispatchQueue.main.async {
            DeviceDeploymentService.shared.activeDeployment.phase = .compiling
            DeviceDeploymentService.shared.activeDeployment.progressFraction = 0.15
            DeviceDeploymentService.shared.activeDeployment.statusMessage = "Compilando framework para NxN Launcher..."
            DeviceDeploymentService.shared.activeDeployment.detailMessage = "Gerando DmGame\(titleId).framework a partir de \(sourceDir.lastPathComponent)..."
            DeviceDeploymentService.shared.activeDeployment.logLines.append("==> Compilando DmGame\(titleId).framework para NxN Launcher...")
        }

        // 4. Run build_ipa_from_nsp.py with --shell-framework
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let scriptURL = URL(fileURLWithPath: "/Volumes/SSD FN501 PRO/Emulations/NativePort/nxnative/scripts/build_ipa_from_nsp.py")
            let keysURL = URL(fileURLWithPath: "/Volumes/Nintendo/RiuJinx Roms/Riujinx/system/prod.keys")

            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            var args = [
                scriptURL.path,
                sourceDir.path,
                "--shell-framework", self.hubFrameworksURL.path,
                "--progress", "json"
            ]
            if fm.fileExists(atPath: keysURL.path) {
                args.append(contentsOf: ["-k", keysURL.path])
            }
            proc.arguments = args

            var env = ProcessInfo.processInfo.environment
            env["LC_ALL"] = "en_US.UTF-8"
            env["LANG"] = "en_US.UTF-8"
            proc.environment = env

            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe

            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                for line in text.split(separator: "\n") {
                    let str = String(line)
                    if str.contains("\"ev\": \"say\"") || str.contains("\"name\":") {
                        DispatchQueue.main.async {
                            DeviceDeploymentService.shared.activeDeployment.logLines.append(str)
                        }
                    }
                }
            }

            // Watchdog: 8 minutes max for game framework compilation
            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
            timer.schedule(deadline: .now() + 480.0)
            timer.setEventHandler { [weak proc] in
                if let p = proc, p.isRunning {
                    p.terminate()
                }
            }
            timer.resume()

            do {
                try proc.run()
                proc.waitUntilExit()
                timer.cancel()
                pipe.fileHandleForReading.readabilityHandler = nil

                if fm.fileExists(atPath: fw.path) {
                    DispatchQueue.main.async {
                        DeviceDeploymentService.shared.activeDeployment.logLines.append("[OK] DmGame\(titleId).framework gerado com sucesso!")
                        completion(true, fw, nil)
                    }
                } else {
                    let failMsg = "Falha ao gerar DmGame\(titleId).framework (código de saída: \(proc.terminationStatus))."
                    DispatchQueue.main.async {
                        completion(false, nil, failMsg)
                    }
                }
            } catch {
                timer.cancel()
                pipe.fileHandleForReading.readabilityHandler = nil
                DispatchQueue.main.async {
                    completion(false, nil, error.localizedDescription)
                }
            }
        }
    }
}
