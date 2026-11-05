import Foundation
import AppKit

// MARK: - Route C Shell Library & Build Orchestration

public struct ShellLibraryState: Codable {
    public struct GameEntry: Codable, Equatable {
        public var titleID: String
        public var name: String
        public var framework: String

        public init(titleID: String, name: String, framework: String) {
            self.titleID = titleID
            self.name = name
            self.framework = framework
        }
    }

    public static var defaultBundleId: String {
        NxHubDeploymentService.hubBundleId
    }

    public var bundleID: String = defaultBundleId
    public var team: String = ""
    public var games: [GameEntry] = []

    public init(bundleID: String = defaultBundleId, team: String = "", games: [GameEntry] = []) {
        self.bundleID = bundleID
        self.team = team
        self.games = games
    }
}

extension NxHubDeploymentService {
    public var hubRootURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("NxNative/MobileHub", isDirectory: true)
    }

    public var hubFrameworksURL: URL {
        hubRootURL.appendingPathComponent("Frameworks", isDirectory: true)
    }

    public var hubProjectURL: URL {
        hubRootURL.appendingPathComponent("project", isDirectory: true)
    }

    public var hubDerivedDataURL: URL {
        hubRootURL.appendingPathComponent("dd", isDirectory: true)
    }

    public var shellJsonURL: URL {
        hubRootURL.appendingPathComponent("shell.json")
    }

    public func loadShellLibrary() -> ShellLibraryState {
        let fm = FileManager.default
        guard fm.fileExists(atPath: shellJsonURL.path),
              let data = try? Data(contentsOf: shellJsonURL),
              var state = try? JSONDecoder().decode(ShellLibraryState.self, from: data) else {
            return ShellLibraryState()
        }
        if state.bundleID == "org.nxnative.shell" {
            state.bundleID = ShellLibraryState.defaultBundleId
        }
        return state
    }

    public func saveShellLibrary(_ state: ShellLibraryState) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: hubRootURL, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: shellJsonURL, options: .atomic)
    }

    /// Registers a game in the Hub's `shell.json` registry.
    @discardableResult
    public func registerGameInHub(titleId: String, name: String, frameworkPath: String) throws -> ShellLibraryState {
        var state = loadShellLibrary()
        let cleanId = titleId.uppercased()
        let entry = ShellLibraryState.GameEntry(titleID: cleanId, name: name, framework: frameworkPath)
        if let idx = state.games.firstIndex(where: { $0.titleID == cleanId }) {
            state.games[idx] = entry
        } else {
            state.games.append(entry)
        }
        try saveShellLibrary(state)
        return state
    }

    /// Generates the DmShell Xcode project using `build_shell.sh --prepare-xcode`.
    public func prepareShellProject(
        library: ShellLibraryState,
        teamId: String,
        completion: @escaping (Bool, String) -> Void
    ) {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: hubProjectURL, withIntermediateDirectories: true)
            try fm.createDirectory(at: hubFrameworksURL, withIntermediateDirectories: true)
            try fm.createDirectory(at: hubDerivedDataURL, withIntermediateDirectories: true)
        } catch {
            completion(false, "Failed to create Hub directories: \(error.localizedDescription)")
            return
        }

        let repoPath = BundledTools.nxnativeRootPath
        let scriptPath = (repoPath as NSString).appendingPathComponent("dm/ios/tools/build_shell.sh")
        let packagePath = (repoPath as NSString).appendingPathComponent("frontend-ios")

        guard fm.fileExists(atPath: scriptPath) else {
            completion(false, "build_shell.sh not found at \(scriptPath)")
            return
        }

        let fwPaths = library.games.map { $0.framework }.filter { fm.fileExists(atPath: $0) }
        guard !fwPaths.isEmpty else {
            completion(false, "No valid game frameworks found in Hub registry.")
            return
        }

        var env = ProcessInfo.processInfo.environment
        env["SHELL_DIR"] = hubProjectURL.path
        env["DM_SHELL_FRAMEWORKS"] = fwPaths.joined(separator: "\n")
        env["DM_BUNDLE_ID"] = library.bundleID
        env["DM_TEAM_ID"] = teamId
        env["DM_SHELL_NAME"] = "NxN Launcher"
        env["DM_SHELL_PACKAGE"] = packagePath
        env["DM_XCODE_DERIVED_DATA"] = hubDerivedDataURL.path
        env["DM_ALLOW_OTHER_CHAIN"] = "1"
        let currentPath = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + currentPath

        DispatchQueue.global(qos: .userInitiated).async {
            let proc = Process()
            let pipe = Pipe()
            proc.executableURL = URL(fileURLWithPath: "/bin/bash")
            proc.arguments = [scriptPath, "--prepare-xcode"]
            proc.environment = env
            proc.standardOutput = pipe
            proc.standardError = pipe

            let watchdog = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
            watchdog.schedule(deadline: .now() + 30.0)
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

                let outData = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outData, encoding: .utf8) ?? ""

                if proc.terminationStatus == 0 {
                    DispatchQueue.main.async { completion(true, "Shell project prepared successfully.") }
                } else {
                    DispatchQueue.main.async { completion(false, "Project preparation failed (\(proc.terminationStatus)): \(output)") }
                }
            } catch {
                watchdog.cancel()
                DispatchQueue.main.async { completion(false, "Failed to execute build_shell.sh: \(error.localizedDescription)") }
            }
        }
    }
}
