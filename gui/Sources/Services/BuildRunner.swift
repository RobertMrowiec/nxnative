import Foundation

public protocol BuildRunnerDelegate: AnyObject {
    func buildRunner(_ runner: BuildRunner, didProduceLog entry: LogEntry)
    func buildRunner(_ runner: BuildRunner, didUpdateStage stage: String, index: Int, total: Int)
    func buildRunner(_ runner: BuildRunner, didUpdateStep step: String)
    func buildRunner(_ runner: BuildRunner, didUpdateProgress fraction: Double, doneBytes: Double?, totalBytes: Double?, etaSeconds: Double?)
    func buildRunner(_ runner: BuildRunner, didEndStage stage: String, index: Int, ok: Bool, elapsed: Double?, summary: String?)
    func buildRunner(_ runner: BuildRunner, didFinishSuccess outputPath: String?)
    func buildRunner(_ runner: BuildRunner, didFinishWithError error: String)
}

public final class BuildRunner {
    private var process: Process?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var isCancelled = false
    private var lastReportedError: String? = nil
    
    public weak var delegate: BuildRunnerDelegate?
    
    public init() {}
    
    public var isRunning: Bool {
        process?.isRunning ?? false
    }
    
    public func startBuild(
        nxnativePath: String,
        gameDirectory: URL,
        prodKeysPath: String,
        platform: TargetPlatform,
        customOutputFolder: URL?,
        appName: String?,
        bundleId: String?,
        language: String?,
        showFps: Bool,
        keepExtracted: Bool,
        surveyOnly: Bool,
        romfsSeparate: Bool = false,
        allowOtherMetal: Bool = true
    ) {
        guard !isRunning else { return }
        isCancelled = false
        lastReportedError = nil
        
        let scriptPath = URL(fileURLWithPath: nxnativePath)
            .appendingPathComponent("scripts/build_ipa_from_nsp.py")
            .standardized.path
        
        guard FileManager.default.fileExists(atPath: scriptPath) else {
            delegate?.buildRunner(self, didFinishWithError: "Build script not found at: \(scriptPath)")
            return
        }
        
        // Ensure engine patches (60 FPS, allocators, shader fallback) are applied
        PatchService.shared.applyPatchesIfNeeded(nxnativePath: nxnativePath) { [weak self] message, isSuccess in
            guard let self = self else { return }
            self.delegate?.buildRunner(self, didProduceLog: LogEntry(level: isSuccess ? .success : .info, message: message))
        }
        
        // Determina caminho do python usando deteccao centralizada e estavel
        let pythonPath = SystemDetector.findBestPythonPath()
        
        let isDump = FileManager.default.fileExists(atPath: gameDirectory.appendingPathComponent("base/exefs/main.npdm").path) || gameDirectory.pathExtension.lowercased() == "nup"
        
        var arguments: [String] = [
            scriptPath,
            gameDirectory.path,
            "--progress", "json"
        ]
        
        if !isDump && !prodKeysPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            arguments.append(contentsOf: ["-k", prodKeysPath])
        }
        
        // Plataforma (Dumps are Mac-native)
        if isDump {
            arguments.append(contentsOf: ["--platform", "mac-app"])
        } else {
            switch platform {
            case .ios:
                arguments.append(contentsOf: ["--platform", "ios"])
            case .macApp, .nonSwitch:
                arguments.append(contentsOf: ["--platform", "mac-app"])
            }
        }
        
        // Output path (always explicitly provided so .app is generated for Mac App)
        let outDir = customOutputFolder ?? gameDirectory
        let rawName = (appName?.isEmpty == false ? appName! : gameDirectory.lastPathComponent)
            .replacingOccurrences(of: "\\[[^\\]]+\\]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanName = rawName.isEmpty ? "Game" : rawName
        let ext = (platform == .macApp ? ".app" : ".ipa")
        let outPath = outDir.appendingPathComponent(cleanName + ext).path
        arguments.append(contentsOf: ["-o", outPath])
        
        if let name = appName, !name.trimmingCharacters(in: .whitespaces).isEmpty {
            arguments.append(contentsOf: ["--app-name", name.trimmingCharacters(in: .whitespaces)])
        }
        
        if let bid = bundleId, !bid.trimmingCharacters(in: .whitespaces).isEmpty {
            arguments.append(contentsOf: ["--bundle-id", bid.trimmingCharacters(in: .whitespaces)])
        }
        
        if let lang = language, lang != "auto", !lang.isEmpty {
            arguments.append(contentsOf: ["-l", lang])
        }
        
        if showFps {
            arguments.append("--show-fps")
        } else {
            arguments.append("--no-show-fps")
        }
        
        let shouldSeparateRomfs = (platform == .ios && romfsSeparate)
        if shouldSeparateRomfs {
            arguments.append(contentsOf: ["--romfs", "separate"])
            // --romfs separate strictly requires --keep-extracted (build_ipa_from_nsp.py:2222)
            arguments.append("--keep-extracted")
            delegate?.buildRunner(self, didProduceLog: LogEntry(level: .info, message: "[Config] RomFS separate mode enabled: preserving extracted image for device transfer (--keep-extracted enforced)."))
        } else if platform == .macApp {
            // Mac App runs natively from extracted engine files (build_ipa_from_nsp.py:2216)
            arguments.append("--keep-extracted")
            if !keepExtracted {
                delegate?.buildRunner(self, didProduceLog: LogEntry(level: .info, message: "[Config] Mac App runs directly from extracted game assets: enforcing --keep-extracted."))
            }
        } else {
            if keepExtracted {
                arguments.append("--keep-extracted")
            } else {
                arguments.append("--no-keep-extracted")
                delegate?.buildRunner(self, didProduceLog: LogEntry(level: .info, message: "[Config] Intermediate extracted files will be cleaned up upon completion (--no-keep-extracted)."))
            }
        }
        
        if surveyOnly {
            arguments.append("--survey-only")
        }
        
        if allowOtherMetal {
            arguments.append("--allow-other-metal")
            delegate?.buildRunner(self, didProduceLog: LogEntry(level: .info, message: "[Config] Allowing current Xcode Metal compiler version (--allow-other-metal)."))
        }
        
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: pythonPath)
        proc.arguments = arguments
        proc.currentDirectoryURL = URL(fileURLWithPath: nxnativePath)
        
        // Augmented PATH ensuring bundled tools, bundled python, and system tools are available
        var env = ProcessInfo.processInfo.environment
        let brewPaths = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        let basePaths = env["PATH"] != nil ? "\(brewPaths):\(env["PATH"]!)" : brewPaths
        env["PATH"] = BundledTools.augmentedPath(base: basePaths, python: pythonPath)
        env["PYTHONUNBUFFERED"] = "1"
        for (k, v) in BundledTools.environment(for: pythonPath) {
            env[k] = v
        }
        proc.environment = env
        
        let stdout = Pipe()
        let stderr = Pipe()
        proc.standardOutput = stdout
        proc.standardError = stderr
        
        self.process = proc
        self.stdoutPipe = stdout
        self.stderrPipe = stderr
        
        delegate?.buildRunner(self, didProduceLog: LogEntry(level: .info, message: "Starting: \(pythonPath) \(arguments.joined(separator: " "))"))
        
        // Read stdout
        let stdoutHandle = stdout.fileHandleForReading
        stdoutHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let self = self else { return }
            self.processOutputData(data, isError: false)
        }
        
        // Leitura de stderr
        let stderrHandle = stderr.fileHandleForReading
        stderrHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let self = self else { return }
            self.processOutputData(data, isError: true)
        }
        
        proc.terminationHandler = { [weak self] p in
            guard let self = self else { return }
            stdoutHandle.readabilityHandler = nil
            stderrHandle.readabilityHandler = nil
            UpdateCheckerService.shared.isBuildActive = false
            
            DispatchQueue.main.async {
                if self.isCancelled {
                    self.delegate?.buildRunner(self, didFinishWithError: "Build cancelled by user.")
                } else if p.terminationStatus == 0 {
                    let outPath = self.resolveFinalOutputPath(gameDir: gameDirectory, customOut: customOutputFolder, platform: platform, appName: appName)
                    self.delegate?.buildRunner(self, didFinishSuccess: outPath)
                } else {
                    if let specificError = self.lastReportedError, !specificError.isEmpty {
                        self.delegate?.buildRunner(self, didFinishWithError: specificError)
                    } else {
                        self.delegate?.buildRunner(self, didFinishWithError: "Process exited with error (code: \(p.terminationStatus)). Check logs for details.")
                    }
                }
            }
        }
        
        do {
            UpdateCheckerService.shared.isBuildActive = true
            try proc.run()
        } catch {
            UpdateCheckerService.shared.isBuildActive = false
            delegate?.buildRunner(self, didFinishWithError: "Failed to start build process: \(error.localizedDescription)")
        }
    }
    
    public func cancel() {
        guard isRunning else { return }
        isCancelled = true
        UpdateCheckerService.shared.isBuildActive = false
        delegate?.buildRunner(self, didProduceLog: LogEntry(level: .warning, message: "Cancelling build process..."))
        process?.terminate()
    }
    
    private var stdoutBuffer = ""
    private var stderrBuffer = ""
    private let decoder = JSONDecoder()
    
    private func processOutputData(_ data: Data, isError: Bool) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if isError {
                self.stderrBuffer += text
                while let newlineRange = self.stderrBuffer.range(of: "\n") {
                    let line = String(self.stderrBuffer[..<newlineRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                    self.stderrBuffer.removeSubrange(..<newlineRange.upperBound)
                    if !line.isEmpty {
                        self.handleOutputLine(line, isError: true)
                    }
                }
            } else {
                self.stdoutBuffer += text
                while let newlineRange = self.stdoutBuffer.range(of: "\n") {
                    let line = String(self.stdoutBuffer[..<newlineRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                    self.stdoutBuffer.removeSubrange(..<newlineRange.upperBound)
                    if !line.isEmpty {
                        self.handleOutputLine(line, isError: false)
                    }
                }
            }
        }
    }
    
    private func handleOutputLine(_ line: String, isError: Bool) {
        if line.hasPrefix("{") && line.hasSuffix("}"),
           let jsonData = line.data(using: .utf8),
           let event = try? decoder.decode(ProgressEvent.self, from: jsonData) {
            
            switch event.ev {
            case "stage":
                let stageName = event.name ?? "Processing"
                let k = event.k ?? 1
                let n = event.n ?? 1
                delegate?.buildRunner(self, didUpdateStage: stageName, index: k, total: n)
                delegate?.buildRunner(self, didProduceLog: LogEntry(level: .step, message: "[\(k)/\(n)] \(stageName)"))
                
            case "step":
                if let step = event.step {
                    delegate?.buildRunner(self, didUpdateStep: step)
                    delegate?.buildRunner(self, didProduceLog: LogEntry(level: .info, message: "↳ \(step)"))
                }
                
            case "progress":
                let frac = event.frac ?? 0.0
                delegate?.buildRunner(self, didUpdateProgress: frac, doneBytes: event.done, totalBytes: event.total, etaSeconds: event.eta)
                
            case "stage_end":
                let ok = event.ok ?? true
                let name = event.name ?? ""
                let summary = event.summary ?? ""
                let k = event.k ?? 1
                delegate?.buildRunner(self, didEndStage: name, index: k, ok: ok, elapsed: event.elapsed, summary: summary)
                let msg = ok ? "[OK] \(name) completed \(summary)" : "[FAIL] \(name) failed \(summary)"
                delegate?.buildRunner(self, didProduceLog: LogEntry(level: ok ? .success : .error, message: msg))
                
            case "say":
                if let msg = event.msg {
                    let isRed = msg.hasPrefix("[RED]")
                    if isRed {
                        let cleanMsg = String(msg.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !cleanMsg.isEmpty {
                            self.lastReportedError = cleanMsg
                        }
                    }
                    delegate?.buildRunner(self, didProduceLog: LogEntry(level: isRed ? .error : .info, message: msg))
                }
                
            default:
                break
            }
        } else {
            let level: LogLevel = isError ? .error : .info
            delegate?.buildRunner(self, didProduceLog: LogEntry(level: level, message: line))
        }
    }
    
    private func resolveFinalOutputPath(gameDir: URL, customOut: URL?, platform: TargetPlatform, appName: String?) -> String {
        let searchDir = customOut ?? gameDir
        let fm = FileManager.default
        let ext = (platform == .macApp || platform == .nonSwitch) ? "app" : "ipa"
        
        // Search for newly generated file in destination folder
        if let items = try? fm.contentsOfDirectory(at: searchDir, includingPropertiesForKeys: [.contentModificationDateKey]) {
            let matching = items.filter { $0.pathExtension.lowercased() == ext }
                .sorted {
                    let date1 = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                    let date2 = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                    return date1 > date2
                }
            if let first = matching.first {
                return first.path
            }
        }
        
        return searchDir.path
    }
}
