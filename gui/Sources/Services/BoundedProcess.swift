import Foundation

/// Runs a subprocess with a hard deadline. Output goes to a temp file (no pipe deadlocks),
/// the parent environment is always inherited, and the process is killed on timeout.
public enum BoundedProcess {
    public struct Result {
        public let status: Int32?   // nil => timed out / failed to launch
        public let output: String
        public var success: Bool { status == 0 }
        public var timedOut: Bool { status == nil }
    }

    @discardableResult
    public static func run(
        _ executable: String,
        _ arguments: [String],
        cwd: String? = nil,
        extraEnv: [String: String] = [:],
        timeout: TimeInterval
    ) -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let cwd = cwd { process.currentDirectoryURL = URL(fileURLWithPath: cwd) }

        var env = ProcessInfo.processInfo.environment
        let extraPaths = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        env["PATH"] = env["PATH"].map { "\(extraPaths):\($0)" } ?? extraPaths
        env["GIT_TERMINAL_PROMPT"] = "0"
        for (k, v) in extraEnv { env[k] = v }
        process.environment = env

        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("nx_bp_\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: tmp.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: tmp) }
        guard let handle = try? FileHandle(forWritingTo: tmp) else {
            return Result(status: nil, output: "cannot create temp log")
        }
        process.standardOutput = handle
        process.standardError = handle
        process.standardInput = FileHandle.nullDevice

        do { try process.run() } catch {
            try? handle.close()
            return Result(status: nil, output: error.localizedDescription)
        }
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline { usleep(40_000) }
        var timedOut = false
        if process.isRunning {
            timedOut = true
            process.terminate()
            usleep(300_000)
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }
        try? handle.close()
        let out = (try? String(contentsOf: tmp, encoding: .utf8)) ?? ""
        return Result(status: timedOut ? nil : process.terminationStatus, output: out)
    }

    public static func gitPath() -> String {
        ["/opt/homebrew/bin/git", "/usr/local/bin/git", "/usr/bin/git"]
            .first(where: { FileManager.default.fileExists(atPath: $0) }) ?? "/usr/bin/git"
    }
}
