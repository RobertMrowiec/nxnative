import Foundation
import AppKit

// MARK: - Multi-Game Batch Deployment & Storage Validation for NxN Launcher
extension NxHubDeploymentService {

    /// Validates device storage before deploying a batch of games.
    public func validateDeviceStorage(
        for games: [PortedGame],
        on device: ConnectedAppleDevice,
        completion: @escaping (Bool, String) -> Void
    ) {
        let fm = FileManager.default
        var totalBytes: Int64 = 0

        for game in games {
            let parentDir = game.url.deletingLastPathComponent()
            let candidates = [
                parentDir.appendingPathComponent("RomFS.img"),
                parentDir.appendingPathComponent("romfs.img"),
                game.url.appendingPathComponent("romfs.img")
            ]
            var foundSize: Int64 = 0
            for c in candidates where fm.fileExists(atPath: c.path) {
                foundSize = (try? fm.attributesOfItem(atPath: c.path)[.size] as? Int64) ?? 0
                break
            }
            if foundSize == 0 {
                foundSize = (try? fm.attributesOfItem(atPath: game.url.path)[.size] as? Int64) ?? 0
            }
            totalBytes += foundSize
        }

        let formattedTotal = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)

        // Query available device storage via xcrun devicectl
        DispatchQueue.global(qos: .userInitiated).async {
            let proc = Process()
            let pipe = Pipe()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            proc.arguments = ["devicectl", "device", "info", "storage", "--device", device.id, "--json-output", "-"]
            proc.standardOutput = pipe
            proc.standardError = Pipe()

            let wd = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
            wd.schedule(deadline: .now() + 4.0)
            wd.setEventHandler { [weak proc] in if let p = proc, p.isRunning { p.terminate() } }

            do {
                try proc.run()
                wd.resume()
                proc.waitUntilExit()
                wd.cancel()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let result = json["result"] as? [String: Any],
                   let storageList = result["storage"] as? [[String: Any]],
                   let primary = storageList.first,
                   let freeBytes = primary["free"] as? Int64 {
                    let formattedFree = ByteCountFormatter.string(fromByteCount: freeBytes, countStyle: .file)
                    let safetyMargin: Int64 = 1024 * 1024 * 1024 // 1 GB safety buffer
                    if freeBytes < (totalBytes + safetyMargin) {
                        DispatchQueue.main.async {
                            completion(false, "Espaço insuficiente em \(device.name). Necessário: \(formattedTotal), Livre: \(formattedFree).")
                        }
                        return
                    }
                }
            } catch {
                wd.cancel()
            }

            DispatchQueue.main.async {
                completion(true, "Armazenamento verificado: \(formattedTotal) para \(games.count) jogo(s).")
            }
        }
    }

    /// Deploys a collection of games sequentially to the NxN Launcher container.
    public func deployBatchToHub(
        games: [PortedGame],
        device: ConnectedAppleDevice,
        team: DeveloperSigningTeam?,
        onProgress: @escaping (_ currentIndex: Int, _ totalCount: Int, _ status: String) -> Void,
        completion: @escaping (Bool, String) -> Void
    ) {
        guard !games.isEmpty else {
            completion(false, "Nenhum jogo selecionado para envio.")
            return
        }

        var completedCount = 0
        var failedGames: [String] = []

        func deployNext(index: Int) {
            guard index < games.count else {
                let msg = failedGames.isEmpty
                    ? "Todos os \(completedCount) jogos foram enviados com sucesso para o NxN Launcher!"
                    : "\(completedCount) jogos enviados. Falhas: \(failedGames.joined(separator: ", "))"
                completion(failedGames.isEmpty, msg)
                return
            }

            let game = games[index]
            onProgress(index + 1, games.count, "Enviando \(game.name) (\(index + 1)/\(games.count))...")

            self.deployToHub(game: game, device: device, team: team) { success, msg in
                if success {
                    completedCount += 1
                } else {
                    failedGames.append(game.name)
                }
                // Small settling pause between games to ensure file handles flush
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    deployNext(index: index + 1)
                }
            }
        }

        deployNext(index: 0)
    }
}
