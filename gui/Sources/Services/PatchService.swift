import Foundation

public final class PatchService {
    public static let shared = PatchService()
    
    private init() {}
    
    public func checkPatchStatuses(nxnativePath: String) -> [EnginePatchItem] {
        let root = URL(fileURLWithPath: nxnativePath)
        let fm = FileManager.default
        
        return EnginePatchRegistry.patches.map { def in
            let fileURL = root.appendingPathComponent(def.relativePath)
            guard fm.fileExists(atPath: fileURL.path),
                  let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
                return EnginePatchItem(id: def.id, name: def.name, summary: def.summary, relativePath: def.relativePath, isApplied: false)
            }
            let applied = content.contains(def.checkToken)
            return EnginePatchItem(id: def.id, name: def.name, summary: def.summary, relativePath: def.relativePath, isApplied: applied)
        }
    }
    
    /// Restores files left in an unmerged conflict state (e.g., interrupted stash pop or git pull)
    /// back to clean HEAD so compatibility patches can be reliably reapplied without syntax errors.
    @discardableResult
    public func repairUnmergedFiles(nxnativePath: String) -> [String] {
        let fm = FileManager.default
        let repoURL = URL(fileURLWithPath: nxnativePath)
        guard fm.fileExists(atPath: repoURL.appendingPathComponent(".git").path) else {
            return []
        }
        
        let gitPath = ["/opt/homebrew/bin/git", "/usr/local/bin/git", "/usr/bin/git"].first(where: { fm.fileExists(atPath: $0) }) ?? "/usr/bin/git"
        
        func runGit(_ args: [String], timeoutSeconds: Double = 2.0) -> String? {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: gitPath)
            p.arguments = ["-C", nxnativePath] + args
            p.environment = ["PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"]
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = Pipe()
            
            do {
                try p.run()
            } catch {
                return nil
            }
            
            let deadline = DispatchTime.now() + timeoutSeconds
            let sema = DispatchSemaphore(value: 0)
            var outputData = Data()
            
            DispatchQueue.global(qos: .utility).async {
                outputData = pipe.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                sema.signal()
            }
            
            if sema.wait(timeout: deadline) == .timedOut {
                p.terminate()
                return nil
            }
            
            return String(data: outputData, encoding: .utf8)
        }
        
        guard let output = runGit(["diff", "--name-only", "--diff-filter=U"]) else {
            return []
        }
        
        let files = output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        guard !files.isEmpty else { return [] }
        
        // Batch restoration of conflicted files in two bounded commands
        _ = runGit(["checkout", "HEAD", "--"] + files)
        _ = runGit(["reset", "-q", "HEAD", "--"] + files)
        
        return files
    }
    
    @discardableResult
    public func applyPatchesIfNeeded(
        nxnativePath: String,
        logger: ((String, Bool) -> Void)? = nil
    ) -> (applied: Int, skipped: Int, errors: [String]) {
        let root = URL(fileURLWithPath: nxnativePath)
        let fm = FileManager.default
        
        var appliedCount = 0
        var skippedCount = 0
        var errorMessages: [String] = []
        
        let repaired = repairUnmergedFiles(nxnativePath: nxnativePath)
        for f in repaired {
            logger?("[Repo] Restored \(f) from upstream (resolved merge conflict)", true)
        }
        
        for def in EnginePatchRegistry.patches {
            let fileURL = root.appendingPathComponent(def.relativePath)
            guard fm.fileExists(atPath: fileURL.path) else {
                let msg = "Skipped \(def.name): file not found at \(def.relativePath)"
                logger?(msg, false)
                continue
            }
            
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
                let msg = "Error reading \(def.relativePath)"
                errorMessages.append(msg)
                logger?(msg, false)
                continue
            }
            
            // If already contains token, it's either merged upstream or previously applied
            if content.contains(def.checkToken) {
                // Self-heal: if global_60fps_speed_sync was previously applied without the weak declaration of dm_fps_has_engine_lock, inject it now
                if def.id == "global_60fps_speed_sync" && !content.contains("int dm_fps_has_engine_lock(void)") {
                    let weakDecl = "__attribute__((weak)) int dm_fps_has_engine_lock(void) { return 0; }\n\nstatic int speed_sync_on(void)"
                    if content.contains("static int speed_sync_on(void)") {
                        let healed = content.replacingOccurrences(of: "static int speed_sync_on(void)", with: weakDecl)
                        try? healed.write(to: fileURL, atomically: true, encoding: .utf8)
                        appliedCount += 1
                        logger?("[Patch] Repaired missing weak declaration in \(def.relativePath)", true)
                        continue
                    }
                }
                skippedCount += 1
                logger?("[Patch] \(def.name): Already applied or upstream merged.", false)
                continue
            }
            
            // Perform non-destructive transformation
            guard let modified = def.applyTransform(content) else {
                let msg = "[Patch] Warning: Pattern anchor not found for \(def.name) in \(def.relativePath)"
                errorMessages.append(msg)
                logger?(msg, false)
                continue
            }
            
            do {
                try modified.write(to: fileURL, atomically: true, encoding: .utf8)
                appliedCount += 1
                logger?("[Patch] Successfully applied: \(def.name)", true)
            } catch {
                let msg = "[Patch] Failed to write \(def.relativePath): \(error.localizedDescription)"
                errorMessages.append(msg)
                logger?(msg, false)
            }
        }
        
        return (appliedCount, skippedCount, errorMessages)
    }
}
