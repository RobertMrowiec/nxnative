import Foundation
import AppKit

public final class UpdateCheckerService {
    public static let shared = UpdateCheckerService()
    public static let launcherRepoURL = "https://gitlab.com/rennan-group2/nxnative_Launcher.git"
    public static let upstreamRepoURL = "https://github.com/seedds/nxnative.git"
    
    public weak var delegate: UpdateCheckerDelegate?
    private var isChecking = false
    private var isUpdating = false
    
    // Concurrency lock preventing Git mutations during an active build
    private let buildLock = NSLock()
    private var _isBuildActive = false
    public var isBuildActive: Bool {
        get {
            buildLock.lock()
            defer { buildLock.unlock() }
            return _isBuildActive
        }
        set {
            buildLock.lock()
            _isBuildActive = newValue
            buildLock.unlock()
        }
    }
    
    private init() {}
    
    public func getLocalCommit(nxnativePath: String) -> String {
        guard !nxnativePath.isEmpty else { return "HEAD" }
        let localHead = runGit(["rev-parse", "--short", "HEAD"], in: nxnativePath).trimmingCharacters(in: .whitespacesAndNewlines)
        return localHead.isEmpty ? "HEAD" : localHead
    }
    
    public func checkForUpdates(nxnativePath: String, completion: @escaping (UpdateInfo?) -> Void) {
        guard !isChecking else { return }
        isChecking = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let fm = FileManager.default
            let gitDir = URL(fileURLWithPath: nxnativePath).appendingPathComponent(".git").path
            guard fm.fileExists(atPath: gitDir) else {
                self.isChecking = false
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            // Automatically migrate origin from seedds/nxnative to rennan101/nxnative_Launcher if needed
            let remoteURL = self.ensureOfficialRemote(in: nxnativePath)
            
            // 1. git fetch origin main
            let fetchRes = self.runGitWithStatus(["fetch", "origin", "main", "--quiet"], in: nxnativePath)
            if fetchRes.exitCode != 0 {
                self.isChecking = false
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            // 2. Local & Remote HEAD commits
            let localHead = self.runGit(["rev-parse", "--short", "HEAD"], in: nxnativePath).trimmingCharacters(in: .whitespacesAndNewlines)
            let remoteHead = self.runGit(["rev-parse", "--short", "origin/main"], in: nxnativePath).trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 3. Count commits that origin/main has ahead of HEAD
            let countStr = self.runGit(["rev-list", "--count", "HEAD..origin/main"], in: nxnativePath).trimmingCharacters(in: .whitespacesAndNewlines)
            let aheadCount = Int(countStr) ?? 0
            
            // 4. Log of incoming commits
            let logOutput = self.runGit(["log", "HEAD..origin/main", "--oneline"], in: nxnativePath).trimmingCharacters(in: .whitespacesAndNewlines)
            let commits = logOutput.isEmpty ? [] : logOutput.components(separatedBy: .newlines).filter { !$0.isEmpty }
            
            let hasUpdate = aheadCount > 0 && !commits.isEmpty && localHead != remoteHead
            let info = UpdateInfo(
                hasUpdate: hasUpdate,
                localCommit: localHead,
                remoteCommit: remoteHead,
                commitMessages: commits,
                checkDate: Date(),
                repoURL: remoteURL.isEmpty ? Self.launcherRepoURL : remoteURL
            )
            
            self.isChecking = false
            DispatchQueue.main.async {
                if hasUpdate {
                    self.delegate?.updateCheckerDidFindUpdate(info)
                }
                completion(info)
            }
        }
    }
    
    /// Pulls latest changes from GitHub, applies engine patches, and rebuilds + installs NxNative_Launcher.app automatically
    public func applyUpdate(
        nxnativePath: String,
        rebuildLauncher: Bool = true,
        progressHandler: ((String) -> Void)? = nil,
        completion: @escaping (Bool, String) -> Void
    ) {
        guard !isBuildActive else {
            let msg = "Update blocked: A compilation process is currently active. Repository updates are paused during build to prevent toolchain and shader hash mismatch."
            delegate?.updateCheckerDidProduceLog(msg)
            completion(false, msg)
            return
        }
        guard !isUpdating else {
            completion(false, "Update already in progress")
            return
        }
        isUpdating = true
        
        let reportProgress: (String) -> Void = { [weak self] msg in
            DispatchQueue.main.async {
                self?.delegate?.updateCheckerDidProduceLog(msg)
                progressHandler?(msg)
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            if self.isBuildActive {
                self.isUpdating = false
                reportProgress("==> Update aborted: A build process has started.")
                DispatchQueue.main.async { completion(false, "Update cancelled: Build in progress.") }
                return
            }
            
            reportProgress("==> Preparing repository for update...")
            _ = self.runGitWithStatus(["rebase", "--abort"], in: nxnativePath)
            _ = self.runGitWithStatus(["merge", "--abort"], in: nxnativePath)
            _ = self.ensureOfficialRemote(in: nxnativePath, reportProgress: reportProgress)
            
            // Discard auto-patched tracked modifications so git pull/merge never conflicts with PatchService edits
            _ = self.runGitWithStatus(["checkout", "--", "."], in: nxnativePath)
            
            reportProgress("==> Downloading latest version from GitHub (rennan101/nxnative_Launcher)...")
            let fetchRes = self.runGitWithStatus(["fetch", "origin", "main"], in: nxnativePath)
            if !fetchRes.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                reportProgress(fetchRes.output.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            
            reportProgress("==> Merging GitHub updates into local branch...")
            let mergeRes = self.runGitWithStatus(["merge", "-X", "theirs", "--no-edit", "origin/main"], in: nxnativePath)
            if !mergeRes.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                reportProgress(mergeRes.output.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            
            var isMergeSuccess = (mergeRes.exitCode == 0) &&
                !mergeRes.output.localizedCaseInsensitiveContains("fatal:") &&
                !mergeRes.output.localizedCaseInsensitiveContains("Automatic merge failed")
            
            if !isMergeSuccess {
                _ = self.runGitWithStatus(["merge", "--abort"], in: nxnativePath)
                reportProgress("==> Fast-forwarding local repository to origin/main...")
                let resetRes = self.runGitWithStatus(["reset", "--hard", "origin/main"], in: nxnativePath)
                isMergeSuccess = (resetRes.exitCode == 0)
            }
            
            _ = self.runGitWithStatus(["submodule", "update", "--init", "--recursive"], in: nxnativePath)
            
            guard isMergeSuccess else {
                self.isUpdating = false
                let errOut = mergeRes.output.trimmingCharacters(in: .whitespacesAndNewlines)
                DispatchQueue.main.async {
                    completion(false, "Git update failed: \(errOut.isEmpty ? "Merge conflict or network error" : errOut)")
                }
                return
            }
            
            // Re-apply compatibility patches
            reportProgress("==> Verifying & applying engine compatibility patches...")
            _ = PatchService.shared.applyPatchesIfNeeded(nxnativePath: nxnativePath)
            
            // Rebuild & install NxNative_Launcher.app if requested
            if rebuildLauncher {
                let buildScript = URL(fileURLWithPath: nxnativePath).appendingPathComponent("scripts/build_gui.sh").path
                if FileManager.default.fileExists(atPath: buildScript) {
                    reportProgress("==> Compiling & installing new NxNative Launcher (.app)...")
                    let buildRes = self.runShellScript(buildScript, workingDir: nxnativePath) { line in
                        reportProgress(line)
                    }
                    if buildRes != 0 {
                        self.isUpdating = false
                        DispatchQueue.main.async {
                            completion(false, "Git updated, but compiling NxNative Launcher failed (exit code \(buildRes)).")
                        }
                        return
                    }
                    
                    self.syncUpdatedBundleToRunningAppIfNeeded(nxnativePath: nxnativePath, reportProgress: reportProgress)
                }
            }
            
            let newHead = self.runGit(["rev-parse", "--short", "HEAD"], in: nxnativePath).trimmingCharacters(in: .whitespacesAndNewlines)
            self.isUpdating = false
            
            DispatchQueue.main.async {
                completion(true, "NxNative Launcher updated & installed successfully (commit [\(newHead)])!")
            }
        }
    }
    
    /// Relaunches the updated NxNative_Launcher.app bundle and terminates the current process
    public func relaunchLauncher(nxnativePath: String) {
        let fm = FileManager.default
        let workspaceRoot = URL(fileURLWithPath: nxnativePath).deletingLastPathComponent()
        let workspaceBundle = workspaceRoot.appendingPathComponent("NxNative_Launcher.app").path
        let repoBundle = URL(fileURLWithPath: nxnativePath).appendingPathComponent("NxNative_Launcher.app").path
        let currentBundle = Bundle.main.bundleURL.path
        
        let targetBundle: String
        if currentBundle.hasSuffix(".app") && fm.fileExists(atPath: currentBundle) {
            targetBundle = currentBundle
        } else if fm.fileExists(atPath: workspaceBundle) {
            targetBundle = workspaceBundle
        } else {
            targetBundle = repoBundle
        }
        
        let pid = ProcessInfo.processInfo.processIdentifier
        let script = "while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done; sleep 0.3; open \"\(targetBundle)\""
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script]
        try? process.run()
        
        DispatchQueue.main.async {
            NSApplication.shared.terminate(nil)
        }
    }
}
