import Foundation

extension UpdateCheckerService {
    /// Ensures `origin` points to `rennan101/nxnative_Launcher` so all users receive unified engine + GUI updates,
    /// while preserving `seedds/nxnative` as `upstream`.
    @discardableResult
    internal func ensureOfficialRemote(in nxnativePath: String, reportProgress: ((String) -> Void)? = nil) -> String {
        let currentOrigin = runGit(["remote", "get-url", "origin"], in: nxnativePath).trimmingCharacters(in: .whitespacesAndNewlines)
        if currentOrigin.isEmpty {
            _ = runGitWithStatus(["remote", "add", "origin", Self.launcherRepoURL], in: nxnativePath)
            _ = runGitWithStatus(["remote", "add", "upstream", Self.upstreamRepoURL], in: nxnativePath)
            return Self.launcherRepoURL
        }
        if currentOrigin.localizedCaseInsensitiveContains("seedds/nxnative") {
            reportProgress?("==> Migrating origin remote from seedds/nxnative to official rennan101/nxnative_Launcher...")
            let upstreamURL = runGit(["remote", "get-url", "upstream"], in: nxnativePath).trimmingCharacters(in: .whitespacesAndNewlines)
            if upstreamURL.isEmpty {
                _ = runGitWithStatus(["remote", "add", "upstream", Self.upstreamRepoURL], in: nxnativePath)
            }
            _ = runGitWithStatus(["remote", "set-url", "origin", Self.launcherRepoURL], in: nxnativePath)
            return Self.launcherRepoURL
        }
        return currentOrigin
    }
    
    internal func syncUpdatedBundleToRunningAppIfNeeded(nxnativePath: String, reportProgress: (String) -> Void) {
        let fm = FileManager.default
        let currentBundleURL = Bundle.main.bundleURL.standardizedFileURL
        guard currentBundleURL.pathExtension == "app" else { return }
        
        let workspaceRoot = URL(fileURLWithPath: nxnativePath).deletingLastPathComponent().standardizedFileURL
        let workspaceApp = workspaceRoot.appendingPathComponent("NxNative_Launcher.app").standardizedFileURL
        let repoApp = URL(fileURLWithPath: nxnativePath).appendingPathComponent("NxNative_Launcher.app").standardizedFileURL
        
        if currentBundleURL.path != workspaceApp.path && currentBundleURL.path != repoApp.path {
            let sourceApp = fm.fileExists(atPath: workspaceApp.path) ? workspaceApp : repoApp
            guard fm.fileExists(atPath: sourceApp.path) else { return }
            reportProgress("==> Updating running bundle at \(currentBundleURL.path)...")
            let cpProc = Process()
            cpProc.executableURL = URL(fileURLWithPath: "/bin/cp")
            cpProc.arguments = ["-Rf", "\(sourceApp.path)/Contents", "\(currentBundleURL.path)/"]
            try? cpProc.run()
            cpProc.waitUntilExit()
        }
    }
    
    internal func runShellScript(_ scriptPath: String, workingDir: String, onLine: @escaping (String) -> Void) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptPath]
        process.currentDirectoryURL = URL(fileURLWithPath: workingDir)
        process.environment = ["PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            chunk.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .forEach { onLine($0) }
        }
        
        do {
            try process.run()
            process.waitUntilExit()
            handle.readabilityHandler = nil
            return process.terminationStatus
        } catch {
            handle.readabilityHandler = nil
            onLine("Error running build script: \(error.localizedDescription)")
            return -1
        }
    }
    
    @discardableResult
    internal func runGitWithStatus(_ args: [String], in dir: String) -> (exitCode: Int32, output: String) {
        let fm = FileManager.default
        let gitPath = ["/opt/homebrew/bin/git", "/usr/local/bin/git", "/usr/bin/git"].first(where: { fm.fileExists(atPath: $0) }) ?? "/usr/bin/git"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gitPath)
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: dir)
        process.environment = ["PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
        } catch {
            return (-1, error.localizedDescription)
        }
    }
    
    internal func runGit(_ args: [String], in dir: String) -> String {
        runGitWithStatus(args, in: dir).output
    }
}
