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
            
            // Automatically migrate origin and ensure upstream
            let remoteURL = self.ensureOfficialRemote(in: nxnativePath)
            
            // 1. git fetch origin main (GitLab Launcher)
            let fetchRes = self.runGitWithStatus(["fetch", "origin", "main", "--quiet"], in: nxnativePath)
            if fetchRes.exitCode != 0 {
                self.isChecking = false
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            // 2. git fetch upstream main (seedds/nxnative GitHub Core Engine)
            _ = self.runGitWithStatus(["fetch", "upstream", "main", "--quiet"], in: nxnativePath)
            
            // 3. Local & Remote HEAD commits
            let localHead = self.runGit(["rev-parse", "--short", "HEAD"], in: nxnativePath).trimmingCharacters(in: .whitespacesAndNewlines)
            let remoteHead = self.runGit(["rev-parse", "--short", "origin/main"], in: nxnativePath).trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 4. Count commits that origin/main (GitLab) has ahead of HEAD
            let countStr = self.runGit(["rev-list", "--count", "HEAD..origin/main"], in: nxnativePath).trimmingCharacters(in: .whitespacesAndNewlines)
            let aheadCount = Int(countStr) ?? 0
            
            // 5. Log of incoming commits from GitLab
            let logOutput = self.runGit(["log", "HEAD..origin/main", "--oneline"], in: nxnativePath).trimmingCharacters(in: .whitespacesAndNewlines)
            let commits = logOutput.isEmpty ? [] : logOutput.components(separatedBy: .newlines).filter { !$0.isEmpty }
            
            // 6. Upstream checks (seedds/nxnative from GitHub)
            let upstreamCountStr = self.runGit(["rev-list", "--count", "HEAD..upstream/main"], in: nxnativePath).trimmingCharacters(in: .whitespacesAndNewlines)
            let upstreamAheadCount = Int(upstreamCountStr) ?? 0
            
            let upstreamLogOutput = self.runGit(["log", "HEAD..upstream/main", "--oneline", "-n", "10"], in: nxnativePath).trimmingCharacters(in: .whitespacesAndNewlines)
            let upstreamCommits = upstreamLogOutput.isEmpty ? [] : upstreamLogOutput.components(separatedBy: .newlines).filter { !$0.isEmpty }
            
            let hasUpdate = aheadCount > 0 && !commits.isEmpty && localHead != remoteHead
            let info = UpdateInfo(
                hasUpdate: hasUpdate,
                localCommit: localHead,
                remoteCommit: remoteHead,
                commitMessages: commits,
                checkDate: Date(),
                repoURL: remoteURL.isEmpty ? Self.launcherRepoURL : remoteURL,
                upstreamBehindCount: upstreamAheadCount,
                upstreamCommitMessages: upstreamCommits,
                upstreamRepoURL: Self.upstreamRepoURL
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
            
            reportProgress("==> Downloading latest version from GitLab (rennan-group2/nxnative_Launcher)...")
            let fetchRes = self.runGitWithStatus(["fetch", "origin", "main"], in: nxnativePath)
            if !fetchRes.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                reportProgress(fetchRes.output.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            
            reportProgress("==> Merging GitLab updates into local branch...")
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
    
    /// Safely fetches and merges upstream engine updates from seedds/nxnative (GitHub) into the local repository,
    /// re-applies compatibility patches, and rebuilds the launcher if requested.
    public func syncUpstream(
        nxnativePath: String,
        rebuildLauncher: Bool = true,
        progressHandler: ((String) -> Void)? = nil,
        completion: @escaping (Bool, String) -> Void
    ) {
        guard !isBuildActive else {
            let msg = "Sync blocked: A compilation process is currently active."
            delegate?.updateCheckerDidProduceLog(msg)
            completion(false, msg)
            return
        }
        guard !isUpdating else {
            completion(false, "Update or sync already in progress")
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
                reportProgress("==> Sync aborted: A build process has started.")
                DispatchQueue.main.async { completion(false, "Sync cancelled: Build in progress.") }
                return
            }
            
            reportProgress("==> Fetching upstream engine commits from GitHub (seedds/nxnative)...")
            _ = self.ensureOfficialRemote(in: nxnativePath, reportProgress: reportProgress)
            let fetchRes = self.runGitWithStatus(["fetch", "upstream", "main"], in: nxnativePath, timeout: 20.0)
            if fetchRes.exitCode != 0 {
                self.isUpdating = false
                let err = fetchRes.output.trimmingCharacters(in: .whitespacesAndNewlines)
                DispatchQueue.main.async {
                    completion(false, "Failed to reach upstream GitHub: \(err.isEmpty ? "Network error" : err)")
                }
                return
            }
            
            let countStr = self.runGit(["rev-list", "--count", "HEAD..upstream/main"], in: nxnativePath).trimmingCharacters(in: .whitespacesAndNewlines)
            let count = Int(countStr) ?? 0
            if count == 0 {
                self.isUpdating = false
                reportProgress("✅ Core engine is already 100% up to date with seedds/nxnative (GitHub)!")
                DispatchQueue.main.async {
                    completion(true, "Core engine is already up to date with seedds/nxnative.")
                }
                return
            }
            
            reportProgress("==> Merging \(count) upstream commits from seedds/nxnative...")
            let mergeRes = self.runGitWithStatus(["merge", "upstream/main", "--no-edit", "-m", "chore(sync): merge upstream updates from seedds/nxnative"], in: nxnativePath, timeout: 20.0)
            
            let isMergeSuccess = (mergeRes.exitCode == 0) &&
                !mergeRes.output.localizedCaseInsensitiveContains("fatal:") &&
                !mergeRes.output.localizedCaseInsensitiveContains("Automatic merge failed") &&
                !mergeRes.output.localizedCaseInsensitiveContains("CONFLICT")
            
            if !isMergeSuccess {
                _ = self.runGitWithStatus(["merge", "--abort"], in: nxnativePath)
                self.isUpdating = false
                reportProgress("⚠️ Merge conflict detected when syncing upstream. Aborted to protect local customizations.")
                DispatchQueue.main.async {
                    completion(false, "Merge conflict detected while syncing upstream. Aborted to safeguard local code.")
                }
                return
            }
            
            reportProgress("==> Verifying & re-applying engine compatibility patches...")
            _ = PatchService.shared.applyPatchesIfNeeded(nxnativePath: nxnativePath)
            
            if rebuildLauncher {
                let buildScript = URL(fileURLWithPath: nxnativePath).appendingPathComponent("scripts/build_gui.sh").path
                if FileManager.default.fileExists(atPath: buildScript) {
                    reportProgress("==> Compiling & reinstalling updated NxNative Launcher (.app)...")
                    let buildRes = self.runShellScript(buildScript, workingDir: nxnativePath) { line in
                        reportProgress(line)
                    }
                    if buildRes != 0 {
                        self.isUpdating = false
                        DispatchQueue.main.async {
                            completion(false, "Upstream synced, but compiling launcher failed (code \(buildRes)).")
                        }
                        return
                    }
                    self.syncUpdatedBundleToRunningAppIfNeeded(nxnativePath: nxnativePath, reportProgress: reportProgress)
                }
            }
            
            let newHead = self.runGit(["rev-parse", "--short", "HEAD"], in: nxnativePath).trimmingCharacters(in: .whitespacesAndNewlines)
            self.isUpdating = false
            DispatchQueue.main.async {
                completion(true, "Successfully merged \(count) upstream commits from seedds/nxnative (commit [\(newHead)])!")
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
