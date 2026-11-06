import Foundation

public struct ProdKeysDetectionResult {
    public let path: String
    public let sourceName: String
    public let isValid: Bool
}

public struct NxNativeDetectionResult {
    public let path: String
    public let isValid: Bool
}

public struct PythonRuntimeInfo {
    public let path: String?
    public let version: String
    public let isSufficient: Bool
    public let isStable: Bool
    public let isBundled: Bool
    public let isExperimental: Bool
}

public final class SystemDetector {
    public static let shared = SystemDetector()
    public static let officialRepoURL = "https://gitlab.com/rennan-group2/nxnative_Launcher.git"
    public static let upstreamRepoURL = "https://github.com/seedds/nxnative.git"
    public static let mirrorRepoURL = "https://gitlab.com/rennan-group2/nxnative_Launcher.git"
    
    private init() {}
    
    /// Queries the Python version and compatibility for a given executable path.
    public static func queryPythonVersion(_ path: String) -> (major: Int, minor: Int, micro: Int, versionStr: String)? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["-B", "-c", "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')"]
        
        var env = ProcessInfo.processInfo.environment
        env["PYTHONDONTWRITEBYTECODE"] = "1"
        process.environment = env
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let str = (String(data: data, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let parts = str.split(separator: ".").compactMap { Int($0) }
            guard parts.count >= 2 else { return nil }
            let micro = parts.count > 2 ? parts[2] : 0
            return (parts[0], parts[1], micro, str)
        } catch {
            return nil
        }
    }
    
    /// Checks whether the specified Python interpreter has all required modules for building games (lz4, capstone, fontTools, zbic).
    public static func hasRequiredPythonModules(_ pyPath: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pyPath)
        process.arguments = ["-B", "-c", "import lz4.block, capstone, fontTools, zbic; print('OK')"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                return output.contains("OK")
            }
        } catch {}
        return false
    }
    
    /// Determines the best available Python interpreter with strict stability prioritization.
    public static func findBestPython() -> PythonRuntimeInfo {
        let fm = FileManager.default
        
        // 1. Check Bundled Standalone Python runtime (inside .app/Contents/Resources/python)
        var bundledCandidate: PythonRuntimeInfo? = nil
        if let bundled = BundledTools.python(), fm.fileExists(atPath: bundled),
           let ver = queryPythonVersion(bundled) {
            let hasModules = hasRequiredPythonModules(bundled)
            let info = PythonRuntimeInfo(path: bundled, version: "Python \(ver.versionStr)", isSufficient: hasModules, isStable: true, isBundled: true, isExperimental: false)
            if hasModules {
                return info
            }
            bundledCandidate = info
        }
        
        // 2. Custom user-specified Python override (via UserDefaults)
        if let custom = UserDefaults.standard.string(forKey: "nxnative_custom_python_path"),
           !custom.isEmpty, fm.fileExists(atPath: custom),
           let ver = queryPythonVersion(custom) {
            let isSufficient = (ver.major > 3) || (ver.major == 3 && ver.minor >= 12)
            let isStable = (ver.major == 3 && ver.minor >= 12 && ver.minor <= 14)
            let isExp = (ver.major == 3 && ver.minor >= 15)
            let hasModules = hasRequiredPythonModules(custom)
            return PythonRuntimeInfo(path: custom, version: "Python \(ver.versionStr)", isSufficient: isSufficient && !isExp && hasModules, isStable: isStable, isBundled: false, isExperimental: isExp)
        }
        
        // 3. Search system & environment paths in strict priority order (Stable versions 3.13, 3.14, 3.12 first)
        var prioritizedCandidates = [
            "/opt/homebrew/bin/python3.13", "/opt/homebrew/opt/python@3.13/libexec/bin/python3",
            "/opt/homebrew/opt/python@3.13/bin/python3.13", "/opt/homebrew/opt/python@3.13/bin/python3",
            "/usr/local/bin/python3.13", "/usr/local/opt/python@3.13/libexec/bin/python3",
            "/usr/local/opt/python@3.13/bin/python3.13", "/Library/Frameworks/Python.framework/Versions/3.13/bin/python3",
            "/opt/homebrew/bin/python3.14", "/opt/homebrew/opt/python@3.14/libexec/bin/python3",
            "/opt/homebrew/opt/python@3.14/bin/python3.14", "/opt/homebrew/opt/python@3.14/bin/python3",
            "/usr/local/bin/python3.14", "/usr/local/opt/python@3.14/libexec/bin/python3",
            "/usr/local/opt/python@3.14/bin/python3.14", "/Library/Frameworks/Python.framework/Versions/3.14/bin/python3",
            "/opt/homebrew/bin/python3.12", "/opt/homebrew/opt/python@3.12/libexec/bin/python3",
            "/opt/homebrew/opt/python@3.12/bin/python3.12", "/opt/homebrew/opt/python@3.12/bin/python3",
            "/usr/local/bin/python3.12", "/usr/local/opt/python@3.12/libexec/bin/python3",
            "/usr/local/opt/python@3.12/bin/python3.12", "/Library/Frameworks/Python.framework/Versions/3.12/bin/python3",
            "/opt/homebrew/bin/python3", "/usr/local/bin/python3", "/usr/bin/python3"
        ]
        
        // Include Pyenv shims and installed versions if present in user home
        if let home = ProcessInfo.processInfo.environment["HOME"] {
            prioritizedCandidates.insert("\(home)/.pyenv/shims/python3", at: 0)
            if let pyenvVersions = try? fm.contentsOfDirectory(atPath: "\(home)/.pyenv/versions") {
                for v in pyenvVersions.sorted().reversed() {
                    let pyBin = "\(home)/.pyenv/versions/\(v)/bin/python3"
                    if fm.isExecutableFile(atPath: pyBin) {
                        prioritizedCandidates.append(pyBin)
                    }
                }
            }
        }
        
        var workingSystemCandidate: PythonRuntimeInfo? = nil
        var fallbackStableCandidate: PythonRuntimeInfo? = nil
        var experimentalCandidate: (path: String, version: String)? = nil
        var outdatedCandidate: (path: String, version: String)? = nil
        
        for candidate in prioritizedCandidates where fm.isExecutableFile(atPath: candidate) {
            guard let ver = queryPythonVersion(candidate) else { continue }
            let verStr = "Python \(ver.versionStr)"
            if ver.major == 3 && ver.minor >= 12 && ver.minor <= 14 {
                let hasModules = hasRequiredPythonModules(candidate)
                let info = PythonRuntimeInfo(path: candidate, version: verStr, isSufficient: hasModules, isStable: true, isBundled: false, isExperimental: false)
                if hasModules {
                    workingSystemCandidate = info
                    break
                } else if fallbackStableCandidate == nil {
                    fallbackStableCandidate = info
                }
            } else if ver.major == 3 && ver.minor >= 15 {
                if experimentalCandidate == nil { experimentalCandidate = (candidate, verStr) }
            } else if ver.major == 3 && ver.minor < 12 {
                if outdatedCandidate == nil { outdatedCandidate = (candidate, verStr) }
            }
        }
        
        if let working = workingSystemCandidate {
            return working
        }
        if let bundled = bundledCandidate {
            return bundled
        }
        if let fallback = fallbackStableCandidate {
            return fallback
        }
        if let exp = experimentalCandidate {
            return PythonRuntimeInfo(path: exp.path, version: exp.version, isSufficient: false, isStable: false, isBundled: false, isExperimental: true)
        }
        if let old = outdatedCandidate {
            return PythonRuntimeInfo(path: old.path, version: old.version, isSufficient: false, isStable: false, isBundled: false, isExperimental: false)
        }
        return PythonRuntimeInfo(path: nil, version: "Not Found", isSufficient: false, isStable: false, isBundled: false, isExperimental: false)
    }
    
    /// Returns the active executable path for the best available Python interpreter.
    public static func findBestPythonPath() -> String {
        findBestPython().path ?? "/usr/bin/python3"
    }
    
    /// Resolves the true workspace directory (folder containing NXNative.app or external SSD)
    public func resolveRootDirectory() -> URL {
        let bundleDir = Bundle.main.bundleURL.deletingLastPathComponent()
        let fm = FileManager.default
        if fm.fileExists(atPath: bundleDir.appendingPathComponent("nxnative").path) {
            return bundleDir
        }
        let ssdPath = URL(fileURLWithPath: "/Volumes/SSD FN501 PRO/Emulations/NativePort")
        if fm.fileExists(atPath: ssdPath.path) {
            return ssdPath
        }
        if bundleDir.path != "/" && !bundleDir.path.hasPrefix("/Applications") {
            return bundleDir
        }
        return URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("NativePort")
    }
    
    /// Locates the nxnative repository directory
    public func detectNxnativeDirectory(customDir: String? = nil) -> NxNativeDetectionResult {
        let root = resolveRootDirectory()
        let fileManager = FileManager.default
        
        var candidatePaths: [String] = []
        if let custom = customDir, !custom.isEmpty {
            candidatePaths.append(custom)
        }
        candidatePaths.append(contentsOf: [
            root.appendingPathComponent("nxnative").standardized.path,
            root.standardized.path,
            Bundle.main.resourceURL?.appendingPathComponent("nxnative").path ?? ""
        ])
        
        for path in candidatePaths where !path.isEmpty {
            let scriptPath = URL(fileURLWithPath: path).appendingPathComponent("scripts/build_ipa_from_nsp.py").path
            let dmPath = URL(fileURLWithPath: path).appendingPathComponent("dm").path
            if fileManager.fileExists(atPath: scriptPath) && fileManager.fileExists(atPath: dmPath) {
                return NxNativeDetectionResult(path: path, isValid: true)
            }
        }
        
        let fallbackPath = root.appendingPathComponent("nxnative").path
        return NxNativeDetectionResult(path: fallbackPath, isValid: false)
    }
    
    /// Clones the official nxnative_Launcher repository if missing and registers seedds/nxnative as upstream
    public func cloneNxnativeRepository(to destinationURL: URL, completion: @escaping (Bool, String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            let gitBin = ["/opt/homebrew/bin/git", "/usr/local/bin/git", "/usr/bin/git"].first(where: { fm.fileExists(atPath: $0) }) ?? "/usr/bin/git"
            let process = Process()
            process.executableURL = URL(fileURLWithPath: gitBin)
            process.arguments = ["clone", Self.officialRepoURL, destinationURL.path]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let success = process.terminationStatus == 0
                if success {
                    let upProc = Process()
                    upProc.executableURL = URL(fileURLWithPath: gitBin)
                    upProc.currentDirectoryURL = destinationURL
                    upProc.arguments = ["remote", "add", "upstream", Self.upstreamRepoURL]
                    try? upProc.run()
                    upProc.waitUntilExit()
                }
                DispatchQueue.main.async {
                    completion(success, output)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, error.localizedDescription)
                }
            }
        }
    }
    
    /// Auto-detects prod.keys from Ryujinx and Switch homebrew locations
    public func detectProdKeys(additionalSearchDir: String? = nil) -> ProdKeysDetectionResult? {
        var candidateLocations: [(path: String, name: String)] = [
            (NSString(string: "~/Library/Application Support/Ryujinx/system/prod.keys").expandingTildeInPath, "Ryujinx (App Support)"),
            (NSString(string: "~/Library/Application Support/ryujinx/system/prod.keys").expandingTildeInPath, "Ryujinx (App Support)"),
            (NSString(string: "~/Library/Application Support/Ryubing/system/prod.keys").expandingTildeInPath, "Ryubing (App Support)"),
            (NSString(string: "~/Library/Application Support/ryubing/system/prod.keys").expandingTildeInPath, "Ryubing (App Support)"),
            (NSString(string: "~/.config/Ryujinx/system/prod.keys").expandingTildeInPath, "Ryujinx Config"),
            (NSString(string: "~/.config/ryujinx/system/prod.keys").expandingTildeInPath, "Ryujinx Config"),
            (NSString(string: "~/.config/Ryubing/system/prod.keys").expandingTildeInPath, "Ryubing Config"),
            (NSString(string: "~/.config/ryubing/system/prod.keys").expandingTildeInPath, "Ryubing Config")
        ]
        
        let root = resolveRootDirectory()
        let siblingCandidates = [
            root.deletingLastPathComponent().appendingPathComponent("Riujinx/system/prod.keys").path,
            root.deletingLastPathComponent().appendingPathComponent("Riujinx/ProdKeys.Net-21.2.0/prod.keys").path,
            root.appendingPathComponent("Riujinx/system/prod.keys").path
        ]
        for p in siblingCandidates {
            candidateLocations.append((p, "Ryujinx Folder"))
        }
        
        if let customDir = additionalSearchDir, !customDir.isEmpty {
            let direct = URL(fileURLWithPath: customDir).appendingPathComponent("prod.keys").path
            let systemSub = URL(fileURLWithPath: customDir).appendingPathComponent("system/prod.keys").path
            candidateLocations.insert((direct, "Selected Directory"), at: 0)
            candidateLocations.insert((systemSub, "Selected Directory/system"), at: 0)
        }
        
        candidateLocations.append((NSString(string: "~/.switch/prod.keys").expandingTildeInPath, "Switch Homebrew"))
        
        let fileManager = FileManager.default
        for candidate in candidateLocations {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: candidate.path, isDirectory: &isDir) && !isDir.boolValue,
               let attrs = try? fileManager.attributesOfItem(atPath: candidate.path),
               let size = attrs[.size] as? Int64, size > 100 {
                return ProdKeysDetectionResult(path: candidate.path, sourceName: candidate.name, isValid: true)
            }
        }
        return nil
    }

    public func isRyujinxOrRyubingInstalled() -> Bool {
        let appPaths = [
            "/Applications/Ryujinx.app",
            "/Applications/Ryubing.app",
            NSString(string: "~/Applications/Ryujinx.app").expandingTildeInPath,
            NSString(string: "~/Applications/Ryubing.app").expandingTildeInPath,
            NSString(string: "~/Library/Application Support/Ryujinx").expandingTildeInPath,
            NSString(string: "~/Library/Application Support/ryujinx").expandingTildeInPath,
            NSString(string: "~/Library/Application Support/Ryubing").expandingTildeInPath,
            NSString(string: "~/Library/Application Support/ryubing").expandingTildeInPath
        ]
        let fm = FileManager.default
        for path in appPaths where fm.fileExists(atPath: path) {
            return true
        }
        return false
    }
    
    internal func runQuickCommand(_ cmd: String, args: [String]) -> (output: String, success: Bool) {
        return runQuickCommandWithTimeout(cmd, args: args, timeoutSeconds: 3.0)
    }
    
    internal func runQuickCommandWithTimeout(_ cmd: String, args: [String], timeoutSeconds: Double = 2.0) -> (output: String, success: Bool) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: cmd)
        process.arguments = args
        
        var env = ProcessInfo.processInfo.environment
        let extraPaths = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        env["PATH"] = env["PATH"].map { "\(extraPaths):\($0)" } ?? extraPaths
        env["PYTHONDONTWRITEBYTECODE"] = "1"
        process.environment = env
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            let deadline = DispatchTime.now() + timeoutSeconds
            while process.isRunning && DispatchTime.now() < deadline {
                usleep(30_000) // 30ms polling
            }
            if process.isRunning {
                process.terminate()
                return ("", false)
            }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let str = String(data: data, encoding: .utf8) ?? ""
            return (str.trimmingCharacters(in: .whitespacesAndNewlines), process.terminationStatus == 0)
        } catch {
            return (error.localizedDescription, false)
        }
    }
}
