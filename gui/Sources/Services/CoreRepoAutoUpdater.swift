import Foundation

public enum CoreRepoUpdateResult {
    case notARepo
    case upToDate
    case updated(String)       // new short commit
    case skipped(String)       // reason (dirty tree / diverged / etc.)
    case failed(String)
}

/// Silent, bounded, best-effort Core Repository updater (fetch + fast-forward only).
/// Never rebuilds or relaunches the launcher and never discards local changes.
public final class CoreRepoAutoUpdater {
    public static let shared = CoreRepoAutoUpdater()
    private var consecutiveFailures = 0
    private var nextAllowed = Date.distantPast

    /// Exponential backoff after failures / rate limits (1 min → max 1 h).
    public var isInBackoff: Bool { Date() < nextAllowed }

    /// Blocking: call from a background queue only.
    public func updateIfNeeded(repoPath: String) -> CoreRepoUpdateResult {
        let git = BoundedProcess.gitPath()
        guard FileManager.default.fileExists(atPath: repoPath + "/.git") else { return .notARepo }
        if isInBackoff { return .skipped("backoff") }

        let branch = BoundedProcess.run(git, ["rev-parse", "--abbrev-ref", "HEAD"], cwd: repoPath, timeout: 5)
            .output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard branch == "main" else { return .skipped("branch '\(branch)' is not main") }

        // Fetch from origin, falling back to the mirror.
        var fetched = BoundedProcess.run(git, ["fetch", "--quiet", "origin", "main"], cwd: repoPath, timeout: 60)
        if !fetched.success {
            fetched = BoundedProcess.run(git, ["fetch", "--quiet", SystemDetector.mirrorRepoURL, "main"], cwd: repoPath, timeout: 60)
        }
        guard fetched.success else {
            registerFailure()
            return .failed(fetched.timedOut ? "fetch timed out" : fetched.output)
        }
        consecutiveFailures = 0
        nextAllowed = .distantPast

        let behind = Int(BoundedProcess.run(git, ["rev-list", "--count", "HEAD..FETCH_HEAD"], cwd: repoPath, timeout: 5)
            .output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        if behind == 0 { return .upToDate }
        let ahead = Int(BoundedProcess.run(git, ["rev-list", "--count", "FETCH_HEAD..HEAD"], cwd: repoPath, timeout: 5)
            .output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        if ahead > 0 { return .skipped("local commits ahead of remote") }

        // ff-only never overwrites uncommitted work: it aborts if files conflict.
        let merge = BoundedProcess.run(git, ["merge", "--ff-only", "FETCH_HEAD"], cwd: repoPath, timeout: 60)
        guard merge.success else { return .skipped("fast-forward blocked by local changes") }
        let head = BoundedProcess.run(git, ["rev-parse", "--short", "HEAD"], cwd: repoPath, timeout: 5)
            .output.trimmingCharacters(in: .whitespacesAndNewlines)
        return .updated(head)
    }

    private func registerFailure() {
        consecutiveFailures += 1
        let delay = min(60.0 * pow(2.0, Double(consecutiveFailures - 1)), 3600.0)
        nextAllowed = Date().addingTimeInterval(delay)
    }
}
