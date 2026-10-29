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
    
    private init() {}
    
    /// Queries the Python version and compatibility for a given executable path.
    public static func queryPythonVersion(_ path: String) -> (major: Int, minor: Int, micro: Int, versionStr: String)? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["-c", "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
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
    
    /// Determines the best available Python interpreter with strict stability prioritization.
    public static func findBestPython() -> PythonRuntimeInfo {
        let fm = FileManager.default
        
        // 1. Bundled Standalone Python runtime (inside .app/Contents/Resources/python)
        if let bundled = BundledTools.python(), fm.fileExists(atPath: bundled) {
            if let ver = queryPythonVersion(bundled) {
                return PythonRuntimeInfo(
                    path: bundled,
                    version: "Python \(ver.versionStr)",
                    isSufficient: true,
                    isStable: true,
                    isBundled: true,
                    isExperimental: false
                )
            }
        }
        
        // 2. Custom user-specified Python override (via UserDefaults)
        if let custom = UserDefaults.standard.string(forKey: "nxnative_custom_python_path"),
           !custom.isEmpty,
           fm.fileExists(atPath: custom),
           let ver = queryPythonVersion(custom) {
            let isSufficient = (ver.major > 3) || (ver.major == 3 && ver.minor >= 12)
            let isStable = (ver.major == 3 && ver.minor >= 12 && ver.minor <= 14)
            let isExp = (ver.major == 3 && ver.minor >= 15)
            return PythonRuntimeInfo(
                path: custom,
                version: "Python \(ver.versionStr)",
                isSufficient: isSufficient && !isExp,
                isStable: isStable,
                isBundled: false,
                isExperimental: isExp
            )
        }
        
        // 3. Search system paths in strict priority order (Stable versions 3.13, 3.14, 3.12 first)
        let prioritizedCandidates = [
            // Python 3.13 (Preferred default for macOS ARM64 wheels)
            "/opt/homebrew/bin/python3.13",
            "/opt/homebrew/opt/python@3.13/libexec/bin/python3",
            "/opt/homebrew/opt/python@3.13/bin/python3.13",
            "/opt/homebrew/opt/python@3.13/bin/python3",
            "/usr/local/bin/python3.13",
            "/usr/local/opt/python@3.13/libexec/bin/python3",
            "/usr/local/opt/python@3.13/bin/python3.13",
            "/Library/Frameworks/Python.framework/Versions/3.13/bin/python3",
            
            // Python 3.14 (Stable modern release)
            "/opt/homebrew/bin/python3.14",
            "/opt/homebrew/opt/python@3.14/libexec/bin/python3",
            "/opt/homebrew/opt/python@3.14/bin/python3.14",
            "/opt/homebrew/opt/python@3.14/bin/python3",
            "/usr/local/bin/python3.14",
            "/usr/local/opt/python@3.14/libexec/bin/python3",
            "/usr/local/opt/python@3.14/bin/python3.14",
            "/Library/Frameworks/Python.framework/Versions/3.14/bin/python3",
            
            // Python 3.12 (Minimum required by NxNative)
            "/opt/homebrew/bin/python3.12",
            "/opt/homebrew/opt/python@3.12/libexec/bin/python3",
            "/opt/homebrew/opt/python@3.12/bin/python3.12",
            "/opt/homebrew/opt/python@3.12/bin/python3",
            "/usr/local/bin/python3.12",
            "/usr/local/opt/python@3.12/libexec/bin/python3",
            "/usr/local/opt/python@3.12/bin/python3.12",
            "/Library/Frameworks/Python.framework/Versions/3.12/bin/python3",
            
            // Generic unversioned Homebrew / system links
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3"
        ]
        
        var experimentalCandidate: (path: String, version: String)? = nil
        var outdatedCandidate: (path: String, version: String)? = nil
        
        for candidate in prioritizedCandidates where fm.fileExists(atPath: candidate) {
            guard let ver = queryPythonVersion(candidate) else { continue }
            let verStr = "Python \(ver.versionStr)"
            
            if ver.major == 3 && ver.minor >= 12 && ver.minor <= 14 {
                // Verified stable and fully supported by pre-built wheels
                return PythonRuntimeInfo(
                    path: candidate,
                    version: verStr,
                    isSufficient: true,
                    isStable: true,
                    isBundled: false,
                    isExperimental: false
                )
            } else if ver.major == 3 && ver.minor >= 15 {
                if experimentalCandidate == nil {
                    experimentalCandidate = (candidate, verStr)
                }
            } else if ver.major == 3 && ver.minor < 12 {
                if outdatedCandidate == nil {
                    outdatedCandidate = (candidate, verStr)
                }
            }
        }
        
        // If no stable version was found, check if an experimental version (3.15+) exists
        if let exp = experimentalCandidate {
            return PythonRuntimeInfo(
                path: exp.path,
                version: exp.version,
                isSufficient: false,
                isStable: false,
                isBundled: false,
                isExperimental: true
            )
        }
        
        // If an outdated version was found
        if let old = outdatedCandidate {
            return PythonRuntimeInfo(
                path: old.path,
                version: old.version,
                isSufficient: false,
                isStable: false,
                isBundled: false,
                isExperimental: false
            )
        }
        
        return PythonRuntimeInfo(
            path: nil,
            version: "Not Found",
            isSufficient: false,
            isStable: false,
            isBundled: false,
            isExperimental: false
        )
    }
    
    /// Returns the active executable path for the best available Python interpreter.
    public static func findBestPythonPath() -> String {
        findBestPython().path ?? "/usr/bin/python3"
    }
    
    /// Resolves the true workspace directory (folder containing NXNative.app or external SSD)
    public func resolveRootDirectory() -> URL {
        let bundleDir = Bundle.main.bundleURL.deletingLastPathComponent()
        let fm = FileManager.default
        
        // 1. Check if nxnative is a sibling of the bundle
        if fm.fileExists(atPath: bundleDir.appendingPathComponent("nxnative").path) {
            return bundleDir
        }
        
        // 2. Check the specific external SSD location
        let ssdPath = URL(fileURLWithPath: "/Volumes/SSD FN501 PRO/Emulations/NativePort")
        if fm.fileExists(atPath: ssdPath.path) {
            return ssdPath
        }
        
        // 3. Fallback to bundle directory, ensuring it is never "/" or system Applications
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
    
    /// Clones the official nxnative repository if missing
    public func cloneNxnativeRepository(to destinationURL: URL, completion: @escaping (Bool, String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["clone", "https://github.com/seedds/nxnative.git", destinationURL.path]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let success = process.terminationStatus == 0
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
            (
                NSString(string: "~/Library/Application Support/Ryujinx/system/prod.keys").expandingTildeInPath,
                "Ryujinx (App Support)"
            ),
            (
                NSString(string: "~/Library/Application Support/ryujinx/system/prod.keys").expandingTildeInPath,
                "Ryujinx (App Support)"
            )
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
        
        candidateLocations.append((
            NSString(string: "~/.switch/prod.keys").expandingTildeInPath,
            "Switch Homebrew"
        ))
        
        let fileManager = FileManager.default
        for candidate in candidateLocations {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: candidate.path, isDirectory: &isDir) && !isDir.boolValue {
                if let attrs = try? fileManager.attributesOfItem(atPath: candidate.path),
                   let size = attrs[.size] as? Int64, size > 100 {
                    return ProdKeysDetectionResult(path: candidate.path, sourceName: candidate.name, isValid: true)
                }
            }
        }
        
        return nil
    }
    
    private func runQuickCommand(_ cmd: String, args: [String]) -> (output: String, success: Bool) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: cmd)
        process.arguments = args
        
        var env = ProcessInfo.processInfo.environment
        let extraPaths = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        if let existing = env["PATH"] {
            env["PATH"] = "\(extraPaths):\(existing)"
        } else {
            env["PATH"] = extraPaths
        }
        process.environment = env
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let str = String(data: data, encoding: .utf8) ?? ""
            return (str.trimmingCharacters(in: .whitespacesAndNewlines), process.terminationStatus == 0)
        } catch {
            return (error.localizedDescription, false)
        }
    }
    
    public func checkPrerequisites() -> SystemPrerequisites {
        var prereqs = SystemPrerequisites()
        let fm = FileManager.default
        
        // 1. Xcode & Command Line Tools
        let xcodeRes = runQuickCommand("/usr/bin/xcode-select", args: ["-p"])
        let hasXcodeApp = fm.fileExists(atPath: "/Applications/Xcode.app")
        if xcodeRes.success && !xcodeRes.output.isEmpty {
            let versionRes = runQuickCommand("/usr/bin/xcodebuild", args: ["-version"])
            let firstLine = versionRes.output.components(separatedBy: .newlines).first ?? xcodeRes.output
            prereqs.xcode = DependencyStatus(id: "xcode", name: "Xcode & Command Line Tools", isAvailable: true, details: firstLine, recommendation: nil, installCommand: "xcode-select --install", repairCommand: "xcode-select --reset", uninstallCommand: nil, isProtected: true)
        } else if hasXcodeApp {
            prereqs.xcode = DependencyStatus(id: "xcode", name: "Xcode & Command Line Tools", isAvailable: false, details: "Xcode detected, CLT not linked", recommendation: "Run 'xcode-select --install' or switch to Xcode path", installCommand: "xcode-select --install", repairCommand: "sudo xcode-select -s /Applications/Xcode.app/Contents/Developer", uninstallCommand: nil, isProtected: true)
        } else {
            prereqs.xcode = DependencyStatus(id: "xcode", name: "Xcode & Command Line Tools", isAvailable: false, details: "Not Installed", recommendation: "Install Apple Command Line Tools via 'xcode-select --install'", installCommand: "xcode-select --install", repairCommand: "xcode-select --reset", uninstallCommand: nil, isProtected: true)
        }
        
        func findBinary(_ name: String) -> String? {
            if let bundled = BundledTools.tool(name) {
                return bundled
            }
            let userHome = fm.homeDirectoryForCurrentUser.path
            let search = [
                "/opt/homebrew/bin/\(name)",
                "/usr/local/bin/\(name)",
                "/usr/local/share/dotnet/\(name)",
                "\(userHome)/.dotnet/\(name)",
                "/usr/bin/\(name)"
            ]
            for path in search where fm.fileExists(atPath: path) {
                return path
            }
            return nil
        }
        
        // 2. Homebrew Package Manager
        let isHomebrewInstalled: Bool
        let isBundled = BundledTools.isBundledPythonAvailable
        if let brewPath = findBinary("brew") {
            isHomebrewInstalled = true
            let brewVer = runQuickCommand(brewPath, args: ["--version"])
            let firstLine = brewVer.output.components(separatedBy: .newlines).first ?? brewVer.output
            prereqs.homebrew = DependencyStatus(
                id: "homebrew",
                name: "Homebrew Package Manager",
                isAvailable: true,
                details: "\(firstLine) (\(brewPath))",
                recommendation: nil,
                installCommand: prereqs.homebrew.installCommand,
                repairCommand: "brew update",
                uninstallCommand: nil,
                isProtected: true
            )
        } else {
            isHomebrewInstalled = false
            prereqs.homebrew = DependencyStatus(
                id: "homebrew",
                name: "Homebrew Package Manager",
                isAvailable: isBundled,
                details: isBundled ? "Not Installed (Optional — Standalone Tools Bundled)" : "Not Installed",
                recommendation: isBundled ? nil : "Required to install and manage compilers and tools. Click Install to set up automatically.",
                installCommand: prereqs.homebrew.installCommand,
                repairCommand: "brew update",
                uninstallCommand: nil,
                isProtected: true
            )
        }
        
        // 3. Git Version Control
        if let gitPath = findBinary("git") {
            let gitVer = runQuickCommand(gitPath, args: ["--version"])
            prereqs.git = DependencyStatus(id: "git", name: "Git Version Control", isAvailable: true, details: "\(gitVer.output) (\(gitPath))", recommendation: nil, installCommand: "brew install git", repairCommand: "brew reinstall git", uninstallCommand: nil, isProtected: true)
        } else {
            let rec = isHomebrewInstalled ? "Install Git via Homebrew or Xcode CLT" : "Install Homebrew first to install Git"
            prereqs.git = DependencyStatus(id: "git", name: "Git Version Control", isAvailable: false, details: "Not Found", recommendation: rec, installCommand: "brew install git", repairCommand: "brew reinstall git", uninstallCommand: nil, isProtected: true)
        }
        
        // 4. Python 3 Runtime Detection (Bundled or System Stable 3.12-3.14)
        let pyInfo = SystemDetector.findBestPython()
        let chosenPyPath = pyInfo.path
        let chosenPyVersion = pyInfo.version
        
        let pipInstallCmd: String
        let pipRepairCmd: String
        let pipUninstallCmd: String
        
        if let pyPath = chosenPyPath {
            pipInstallCmd = "if \"\(pyPath)\" -m pip install --help 2>&1 | grep -q -- '--break-system-packages'; then \"\(pyPath)\" -m pip install --break-system-packages lz4 capstone fonttools && (\"\(pyPath)\" -m pip install --break-system-packages nsz 2>/dev/null || true); else \"\(pyPath)\" -m pip install lz4 capstone fonttools && (\"\(pyPath)\" -m pip install nsz 2>/dev/null || true); fi"
            pipRepairCmd = "if \"\(pyPath)\" -m pip install --help 2>&1 | grep -q -- '--break-system-packages'; then \"\(pyPath)\" -m pip install --force-reinstall --break-system-packages lz4 capstone fonttools && (\"\(pyPath)\" -m pip install --force-reinstall --break-system-packages nsz 2>/dev/null || true); else \"\(pyPath)\" -m pip install --force-reinstall lz4 capstone fonttools && (\"\(pyPath)\" -m pip install --force-reinstall nsz 2>/dev/null || true); fi"
            pipUninstallCmd = "if \"\(pyPath)\" -m pip uninstall --help 2>&1 | grep -q -- '--break-system-packages'; then \"\(pyPath)\" -m pip uninstall -y --break-system-packages lz4 capstone fonttools nsz 2>/dev/null || true; else \"\(pyPath)\" -m pip uninstall -y lz4 capstone fonttools nsz 2>/dev/null || true; fi"
        } else {
            pipInstallCmd = "brew install python@3.13"
            pipRepairCmd = "brew reinstall python@3.13"
            pipUninstallCmd = ""
        }

        if pyInfo.isBundled, let pyPath = chosenPyPath {
            prereqs.python = DependencyStatus(
                id: "python",
                name: "Python 3",
                isAvailable: true,
                details: "\(chosenPyVersion) (Isolated Standalone)",
                recommendation: nil,
                installCommand: "",
                repairCommand: "",
                uninstallCommand: nil,
                isProtected: true
            )
            
            let pyCheck = runQuickCommand(pyPath, args: ["-c", "import lz4, capstone, fontTools; print('OK')"])
            let nszCheck = runQuickCommand(pyPath, args: ["-c", "import nsz; print('OK')"])
            let hasPackages = pyCheck.success && pyCheck.output.contains("OK")
            let nszNote = nszCheck.success ? " + nsz" : ""
            
            prereqs.pythonPackages = DependencyStatus(
                id: "python_packages",
                name: "Python Modules",
                isAvailable: hasPackages,
                details: hasPackages ? "lz4, capstone, fonttools\(nszNote) (Pre-bundled)" : "Bundled packages need verification",
                recommendation: nil,
                installCommand: pipInstallCmd,
                repairCommand: pipRepairCmd,
                uninstallCommand: pipUninstallCmd,
                isProtected: true
            )
        } else if pyInfo.isSufficient, let pyPath = chosenPyPath {
            prereqs.python = DependencyStatus(
                id: "python",
                name: "Python 3",
                isAvailable: true,
                details: "\(chosenPyVersion) (\(pyPath))",
                recommendation: nil,
                installCommand: "brew install python@3.13",
                repairCommand: "brew reinstall python@3.13",
                uninstallCommand: nil,
                isProtected: false
            )
            
            // Check required Python modules
            let pyCheck = runQuickCommand(pyPath, args: ["-c", "import lz4, capstone, fontTools; print('OK')"])
            if pyCheck.success && pyCheck.output.contains("OK") {
                let nszCheck = runQuickCommand(pyPath, args: ["-c", "import nsz; print('OK')"])
                let nszNote = nszCheck.success ? " + nsz" : " (nsz optional)"
                prereqs.pythonPackages = DependencyStatus(
                    id: "python_packages",
                    name: "Python Modules",
                    isAvailable: true,
                    details: "lz4, capstone, fonttools\(nszNote) installed",
                    recommendation: nszCheck.success ? nil : "Note: Compressed .nsz/.xcz files require standalone nsz or Python <= 3.14",
                    installCommand: pipInstallCmd,
                    repairCommand: pipRepairCmd,
                    uninstallCommand: pipUninstallCmd,
                    isProtected: false
                )
            } else {
                prereqs.pythonPackages = DependencyStatus(
                    id: "python_packages",
                    name: "Python Modules",
                    isAvailable: false,
                    details: "Missing required packages for \(chosenPyVersion)",
                    recommendation: "Install packages via pip",
                    installCommand: pipInstallCmd,
                    repairCommand: pipRepairCmd,
                    uninstallCommand: pipUninstallCmd,
                    isProtected: false
                )
            }
        } else if pyInfo.isExperimental, let pyPath = chosenPyPath {
            // Python 3.15+ detected: wheels fail to compile on macOS
            let rec = isHomebrewInstalled
                ? "Python 3.15+ cannot compile native extensions (lz4). Click Repair to install stable Python 3.13 via Homebrew."
                : "Install Homebrew first, then install stable Python 3.13 via 'brew install python@3.13'."
            prereqs.python = DependencyStatus(
                id: "python",
                name: "Python 3",
                isAvailable: false,
                details: "\(chosenPyVersion) (\(pyPath)) — Incompatible with C-extensions (lz4)",
                recommendation: rec,
                installCommand: "brew install python@3.13",
                repairCommand: "brew reinstall python@3.13",
                uninstallCommand: nil,
                isProtected: false
            )
            prereqs.pythonPackages = DependencyStatus(
                id: "python_packages",
                name: "Python Modules",
                isAvailable: false,
                details: "Cannot build packages on Python 3.15+",
                recommendation: "Install Python 3.13: click Repair on Python 3 above",
                installCommand: "brew install python@3.13",
                repairCommand: "brew reinstall python@3.13",
                uninstallCommand: nil,
                isProtected: false
            )
        } else if let pyPath = chosenPyPath {
            let rec = isHomebrewInstalled ? "Python 3.12+ is required. Click Install to install modern Python via Homebrew." : "Install Homebrew first, then install Python 3.12+."
            prereqs.python = DependencyStatus(
                id: "python",
                name: "Python 3",
                isAvailable: false,
                details: "\(chosenPyVersion) (\(pyPath)) - Python 3.12-3.14 required",
                recommendation: rec,
                installCommand: "brew install python@3.13",
                repairCommand: "brew reinstall python@3.13",
                uninstallCommand: nil,
                isProtected: false
            )
            prereqs.pythonPackages = DependencyStatus(
                id: "python_packages",
                name: "Python Modules",
                isAvailable: false,
                details: "Requires Python 3.12-3.14",
                recommendation: isHomebrewInstalled ? "Install Python 3.13 first via Homebrew" : "Install Homebrew first",
                installCommand: "brew install python@3.13",
                repairCommand: "brew reinstall python@3.13",
                uninstallCommand: nil,
                isProtected: false
            )
        } else {
            let rec = isHomebrewInstalled ? "Install Python 3.13 via Homebrew" : "Install Homebrew first to install Python 3"
            prereqs.python = DependencyStatus(
                id: "python",
                name: "Python 3",
                isAvailable: false,
                details: "Not Found",
                recommendation: rec,
                installCommand: "brew install python@3.13",
                repairCommand: "brew reinstall python@3.13",
                uninstallCommand: nil,
                isProtected: false
            )
            prereqs.pythonPackages = DependencyStatus(
                id: "python_packages",
                name: "Python Modules",
                isAvailable: false,
                details: "Python 3 Not Found",
                recommendation: isHomebrewInstalled ? "Install Python 3 first via Homebrew" : "Install Homebrew first",
                installCommand: "brew install python@3.13",
                repairCommand: "brew reinstall python@3.13",
                uninstallCommand: nil,
                isProtected: false
            )
        }
        
        // 5. .NET SDK
        if let dotnetPath = findBinary("dotnet") {
            let dotnetVer = runQuickCommand(dotnetPath, args: ["--version"])
            prereqs.dotnet = DependencyStatus(id: "dotnet", name: ".NET SDK", isAvailable: true, details: "v\(dotnetVer.output) (\(dotnetPath))", recommendation: nil, installCommand: "brew install --cask dotnet-sdk", repairCommand: "brew reinstall --cask dotnet-sdk", uninstallCommand: "brew uninstall --cask dotnet-sdk", isProtected: false)
        } else {
            let rec = isHomebrewInstalled ? "Install .NET SDK via Homebrew" : "Install .NET 10 SDK via Microsoft installer"
            let cmd = isHomebrewInstalled ? "brew install --cask dotnet-sdk" : "curl -sSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 10.0"
            prereqs.dotnet = DependencyStatus(id: "dotnet", name: ".NET SDK", isAvailable: false, details: "Not Found", recommendation: rec, installCommand: cmd, repairCommand: cmd, uninstallCommand: nil, isProtected: false)
        }
        
        // 6. XcodeGen
        if let xcodegenPath = findBinary("xcodegen") {
            let xcodegenVer = runQuickCommand(xcodegenPath, args: ["--version"])
            prereqs.xcodegen = DependencyStatus(id: "xcodegen", name: "XcodeGen", isAvailable: true, details: xcodegenVer.output, recommendation: nil, installCommand: "brew install xcodegen", repairCommand: "brew reinstall xcodegen", uninstallCommand: "brew uninstall xcodegen", isProtected: false)
        } else {
            let rec = isHomebrewInstalled ? "Install XcodeGen via Homebrew" : "Install Homebrew first to install XcodeGen"
            prereqs.xcodegen = DependencyStatus(id: "xcodegen", name: "XcodeGen", isAvailable: false, details: "Not Found", recommendation: rec, installCommand: "brew install xcodegen", repairCommand: "brew reinstall xcodegen", uninstallCommand: "brew uninstall xcodegen", isProtected: false)
        }
        
        // 7. zstd
        if let zstdPath = findBinary("zstd") {
            prereqs.zstd = DependencyStatus(id: "zstd", name: "zstd", isAvailable: true, details: "Installed (\(zstdPath))", recommendation: nil, installCommand: "brew install zstd", repairCommand: "brew reinstall zstd", uninstallCommand: "brew uninstall zstd", isProtected: false)
        } else {
            let rec = isHomebrewInstalled ? "Install zstd via Homebrew" : "Install Homebrew first to install zstd"
            prereqs.zstd = DependencyStatus(id: "zstd", name: "zstd", isAvailable: false, details: "Not Found", recommendation: rec, installCommand: "brew install zstd", repairCommand: "brew reinstall zstd", uninstallCommand: "brew uninstall zstd", isProtected: false)
        }
        
        // 8. spirv-cross
        if let spirvPath = findBinary("spirv-cross") {
            prereqs.spirvCross = DependencyStatus(id: "spirv_cross", name: "spirv-cross", isAvailable: true, details: "Installed (\(spirvPath))", recommendation: nil, installCommand: "brew install spirv-cross", repairCommand: "brew reinstall spirv-cross", uninstallCommand: "brew uninstall spirv-cross", isProtected: false)
        } else {
            let rec = isHomebrewInstalled ? "Install spirv-cross via Homebrew" : "Install Homebrew first to install spirv-cross"
            prereqs.spirvCross = DependencyStatus(id: "spirv_cross", name: "spirv-cross", isAvailable: false, details: "Not Found", recommendation: rec, installCommand: "brew install spirv-cross", repairCommand: "brew reinstall spirv-cross", uninstallCommand: "brew uninstall spirv-cross", isProtected: false)
        }
        
        // 9. glslangValidator
        if let glslangPath = findBinary("glslangValidator") {
            prereqs.glslang = DependencyStatus(id: "glslang", name: "glslang", isAvailable: true, details: "Installed (\(glslangPath))", recommendation: nil, installCommand: "brew install glslang", repairCommand: "brew reinstall glslang", uninstallCommand: "brew uninstall glslang", isProtected: false)
        } else {
            let rec = isHomebrewInstalled ? "Install glslang via Homebrew" : "Install Homebrew first to install glslang"
            prereqs.glslang = DependencyStatus(id: "glslang", name: "glslang", isAvailable: false, details: "Not Found", recommendation: rec, installCommand: "brew install glslang", repairCommand: "brew reinstall glslang", uninstallCommand: "brew uninstall glslang", isProtected: false)
        }
        
        return prereqs
    }
}
