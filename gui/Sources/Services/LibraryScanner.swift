import Foundation
import AppKit

public final class LibraryScanner {
    public static let shared = LibraryScanner()
    
    private var ipaMetadataCache: [String: (modDate: Date, size: Int64, game: PortedGame)] = [:]
    private let cacheLock = NSLock()
    
    private init() {}
    
    public func scan(directories: [URL], extraAppURLs: [URL] = []) -> [PortedGame] {
        let fm = FileManager.default
        var games: [PortedGame] = []
        var seenURLs = Set<URL>()
        
        let home = NSHomeDirectory()
        let forbiddenPrefixes = [
            "/",
            home,
            home + "/Music",
            home + "/Pictures",
            home + "/Documents",
            home + "/Library"
        ]
        
        for dir in directories {
            let path = dir.standardized.path
            
            // STRICT PRIVACY GUARD: Never scan filesystem root or user home folders directly
            if path == "/" || path == home || path.isEmpty {
                continue
            }
            
            // Don't scan forbidden media directories
            if forbiddenPrefixes.contains(where: { $0 == path && path != "/" }) {
                continue
            }
            
            guard fm.fileExists(atPath: path) else { continue }
            
            // If the folder itself is an .app package, parse it directly
            if dir.pathExtension.lowercased() == "app" {
                if !seenURLs.contains(dir) {
                    seenURLs.insert(dir)
                    if let game = parseMacApp(at: dir, isExplicit: false) {
                        games.append(game)
                    }
                }
                continue
            }
            
            guard let enumerator = fm.enumerator(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }
            
            for case let itemURL as URL in enumerator {
                let itemName = itemURL.lastPathComponent
                if itemName.hasPrefix("._") { continue }
                let ext = itemURL.pathExtension.lowercased()
                
                if ext == "app" {
                    enumerator.skipDescendants()
                    if !seenURLs.contains(itemURL) {
                        seenURLs.insert(itemURL)
                        if let game = parseMacApp(at: itemURL, isExplicit: false) {
                            games.append(game)
                        }
                    }
                } else if ext == "ipa" {
                    if !seenURLs.contains(itemURL) {
                        seenURLs.insert(itemURL)
                        if let game = parseIPA(at: itemURL) {
                            games.append(game)
                        }
                    }
                } else if (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                    let dirLower = itemName.lowercased()
                    if dirLower.hasSuffix("_build") ||
                       dirLower.hasSuffix("-work") ||
                       dirLower.hasSuffix("_survey") ||
                       dirLower.hasPrefix("patched_") ||
                       dirLower == "staging" ||
                       dirLower == "shader" ||
                       dirLower == "extract" ||
                       dirLower == "romfs" ||
                       dirLower == "exefs" ||
                       dirLower == ".git" ||
                       dirLower == "node_modules" {
                        enumerator.skipDescendants()
                    }
                }
            }
        }
        
        // Scan explicitly added Non-Switch Apps
        for appURL in extraAppURLs {
            let path = appURL.standardized.path
            guard !seenURLs.contains(appURL), fm.fileExists(atPath: path), appURL.pathExtension.lowercased() == "app" else { continue }
            seenURLs.insert(appURL)
            if let game = parseMacApp(at: appURL, isExplicit: true) {
                games.append(game)
            }
        }
        
        return games.sorted { $0.modificationDate > $1.modificationDate }
    }
    
    private var sizeCache: [URL: Int64] = [:]

    private static let nonGameCategories: Set<String> = [
        "public.app-category.developer-tools",
        "public.app-category.productivity",
        "public.app-category.graphics-design",
        "public.app-category.utilities",
        "public.app-category.social-networking",
        "public.app-category.business",
        "public.app-category.finance",
        "public.app-category.lifestyle",
        "public.app-category.medical",
        "public.app-category.music",
        "public.app-category.news",
        "public.app-category.photography",
        "public.app-category.video",
        "public.app-category.weather",
        "public.app-category.education",
        "public.app-category.travel",
        "public.app-category.reference"
    ]

    private static let excludedToolBundleIds: [String] = [
        "com.valvesoftware.steam",
        "com.epicgames.EpicGamesLauncher",
        "com.codeweavers.CrossOver",
        "com.heroicgameslauncher.hgl",
        "org.ryujinx.",
        "org.ryubing.",
        "com.rileytestut.AltServer",
        "org.nxnative."
    ]

    private func parseMacApp(at url: URL, isExplicit: Bool = false) -> PortedGame? {
        let fm = FileManager.default
        let plistURL = url.appendingPathComponent("Contents/Info.plist")
        guard fm.fileExists(atPath: plistURL.path) else { return nil }
        
        // Exclude the builder app itself
        if url.lastPathComponent == "NXNative.app" || url.lastPathComponent == "NxNative_Launcher.app" { return nil }
        
        var name = url.deletingPathExtension().lastPathComponent
        var bundleId: String? = nil
        var titleId: String? = nil
        var version: String? = nil
        
        var rawPlist: [String: Any]? = nil
        if let data = try? Data(contentsOf: plistURL),
           let plist = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any] {
            rawPlist = plist
            if let dispName = plist["CFBundleDisplayName"] as? String, !dispName.isEmpty {
                name = dispName
            } else if let bundleName = plist["CFBundleName"] as? String, !bundleName.isEmpty {
                name = bundleName
            }
            bundleId = plist["CFBundleIdentifier"] as? String
            titleId = plist["DMTitleID"] as? String
            version = plist["CFBundleShortVersionString"] as? String
        }
        
        let hasDmhost = fm.fileExists(atPath: url.appendingPathComponent("Contents/MacOS/dmhost").path)
        let hasExplicitDmTitleId = rawPlist?["DMTitleID"] != nil
        
        // Secondary titleId extraction if missing from DMTitleID (only if it has dmhost or DMTitleID)
        if hasDmhost || hasExplicitDmTitleId {
            if titleId == nil || titleId?.isEmpty == true {
                if let bid = bundleId {
                    let range = NSRange(bid.startIndex..., in: bid)
                    if let regex = try? NSRegularExpression(pattern: "((?:0100|0400)[0-9A-Fa-f]{12})", options: [.caseInsensitive]),
                       let match = regex.firstMatch(in: bid, range: range),
                       let r = Range(match.range(at: 1), in: bid) {
                        titleId = String(bid[r]).uppercased()
                    }
                }
            }
            if titleId == nil || titleId?.isEmpty == true {
                let fname = url.lastPathComponent
                let range = NSRange(fname.startIndex..., in: fname)
                if let regex = try? NSRegularExpression(pattern: "\\[((?:0100|0400)[0-9A-Fa-f]{12})\\]", options: [.caseInsensitive]),
                   let match = regex.firstMatch(in: fname, range: range),
                   let r = Range(match.range(at: 1), in: fname) {
                    titleId = String(fname[r]).uppercased()
                }
            }
            if titleId == nil || titleId?.isEmpty == true {
                titleId = CompatibilityService.shared.findTitleId(forGameTitle: name)?.uppercased()
            }
        } else {
            // Non-Switch Game: do not force a Switch Title ID
            titleId = nil
        }
        
        let isSwitchPort = hasDmhost || hasExplicitDmTitleId || (titleId != nil && (titleId?.hasPrefix("0100") == true || titleId?.hasPrefix("0400") == true))
        
        // Strict Game Filter for folder scans (unless explicitly selected by user via Add Game (.app))
        if !isSwitchPort && !isExplicit {
            let appFileName = url.lastPathComponent
            let helperSuffixes = ["Helper.app", "CrashHandler.app", "CrashReporter.app", "Updater.app", "Uninstall.app", "Service.app"]
            if helperSuffixes.contains(where: { appFileName.hasSuffix($0) }) || appFileName.hasPrefix(".") {
                return nil
            }
            
            let bid = bundleId?.lowercased() ?? ""
            let category = (rawPlist?["LSApplicationCategoryType"] as? String)?.lowercased() ?? ""
            
            // Exclude Apple system utilities unless Apple Arcade / game
            if bid.hasPrefix("com.apple.") && !category.contains("game") && !bid.contains("arcade") && !bid.contains("game") {
                return nil
            }
            
            // Exclude known launchers, translation tools and emulators
            if Self.excludedToolBundleIds.contains(where: { bid.hasPrefix($0.lowercased()) }) {
                return nil
            }
            
            // Non-game category rejection
            if Self.nonGameCategories.contains(category) {
                return nil
            }
            
            // If explicit game category, accept immediately
            var isVerifiedGame = category.contains("game")
            
            // If no category declared, verify game engine / runtime signature
            if !isVerifiedGame {
                let contentsURL = url.appendingPathComponent("Contents")
                
                // 1. Unity
                if fm.fileExists(atPath: contentsURL.appendingPathComponent("Frameworks/UnityPlayer.dylib").path) ||
                   fm.fileExists(atPath: contentsURL.appendingPathComponent("Resources/Data/Managed").path) ||
                   fm.fileExists(atPath: contentsURL.appendingPathComponent("Resources/Data/boot.config").path) {
                    isVerifiedGame = true
                }
                
                // 2. Unreal Engine
                if !isVerifiedGame && (fm.fileExists(atPath: contentsURL.appendingPathComponent("UE4").path) ||
                                       fm.fileExists(atPath: contentsURL.appendingPathComponent("UE5").path) ||
                                       fm.fileExists(atPath: contentsURL.appendingPathComponent("Engine/Binaries").path)) {
                    isVerifiedGame = true
                }
                
                // 3. Godot, Love2D, GameMaker, Steam in Resources
                let resourcesURL = contentsURL.appendingPathComponent("Resources")
                if !isVerifiedGame, let rContents = try? fm.contentsOfDirectory(atPath: resourcesURL.path) {
                    if rContents.contains(where: { $0.hasSuffix(".pck") || $0.hasSuffix(".love") || $0 == "game.unx" || $0 == "game.ios" || $0 == "steam_appid.txt" }) {
                        isVerifiedGame = true
                    }
                }
                
                // 4. Steam or Wineskin in MacOS
                let macosURL = contentsURL.appendingPathComponent("MacOS")
                if !isVerifiedGame, let mContents = try? fm.contentsOfDirectory(atPath: macosURL.path) {
                    if mContents.contains(where: { $0 == "steam_appid.txt" || $0 == "wineskinlauncher" }) {
                        isVerifiedGame = true
                    }
                }
                
                // 5. Wine / GPTK / PortingKit prefix
                if !isVerifiedGame && (fm.fileExists(atPath: contentsURL.appendingPathComponent("SharedSupport/prefix/drive_c").path) ||
                                       fm.fileExists(atPath: resourcesURL.appendingPathComponent("drive_c").path)) {
                    isVerifiedGame = true
                }
            }
            
            if !isVerifiedGame {
                return nil
            }
        }
        
        let targetPlatform: TargetPlatform = isSwitchPort ? .macApp : .nonSwitch
        
        // Fast instant size retrieval without blocking RomFS traversal
        var size: Int64 = sizeCache[url] ?? 0
        if size == 0 {
            let romfsImg = url.appendingPathComponent("Contents/Resources/romfs.img")
            if let imgSize = (try? romfsImg.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                size = Int64(imgSize)
            } else if let exeSize = (try? url.appendingPathComponent("Contents/MacOS/dmhost").resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                size = Int64(exeSize)
            } else if let exeName = rawPlist?["CFBundleExecutable"] as? String,
                      let exeSize = (try? url.appendingPathComponent("Contents/MacOS/\(exeName)").resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                size = Int64(exeSize)
            } else if let appSize = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                size = Int64(appSize)
            }
        }
        
        let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
        
        return PortedGame(
            name: name,
            url: url,
            platform: targetPlatform,
            sizeBytes: size,
            modificationDate: modDate,
            bundleId: bundleId,
            titleId: titleId?.uppercased(),
            versionString: version
        )
    }
    
    private func parseIPA(at url: URL) -> PortedGame? {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let size = Int64(values?.fileSize ?? 0)
        let modDate = values?.contentModificationDate ?? Date()
        let pathKey = url.standardized.path
        
        cacheLock.lock()
        if let cached = ipaMetadataCache[pathKey], cached.modDate == modDate, cached.size == size {
            cacheLock.unlock()
            return cached.game
        }
        cacheLock.unlock()

        var name = url.deletingPathExtension().lastPathComponent
        var bundleId: String? = nil
        var titleId: String? = nil
        var version: String? = nil
        
        // Fast inspect Payload/*/Info.plist from inside the IPA (zip archive)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-p", url.path, "Payload/*/Info.plist"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        if (try? process.run()) != nil {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            if !data.isEmpty,
               let plist = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any] {
                if let dispName = plist["CFBundleDisplayName"] as? String, !dispName.isEmpty {
                    name = dispName
                } else if let bundleName = plist["CFBundleName"] as? String, !bundleName.isEmpty && bundleName != "DmIOS" {
                    name = bundleName
                }
                bundleId = plist["CFBundleIdentifier"] as? String
                titleId = plist["DMTitleID"] as? String
                version = plist["CFBundleShortVersionString"] as? String
            }
        }
        
        // Extract TitleID from CFBundleIdentifier if needed
        if titleId == nil || titleId?.isEmpty == true {
            if let bid = bundleId {
                let range = NSRange(bid.startIndex..., in: bid)
                if let regex = try? NSRegularExpression(pattern: "((?:0100|0400)[0-9A-Fa-f]{12})", options: [.caseInsensitive]),
                   let match = regex.firstMatch(in: bid, range: range),
                   let r = Range(match.range(at: 1), in: bid) {
                    titleId = String(bid[r]).uppercased()
                }
            }
        }
        
        // Extract TitleID from filename regex [0100...] or [0400...]
        if titleId == nil || titleId?.isEmpty == true {
            let fname = url.lastPathComponent
            let range = NSRange(fname.startIndex..., in: fname)
            if let regex = try? NSRegularExpression(pattern: "\\[((?:0100|0400)[0-9A-Fa-f]{12})\\]", options: [.caseInsensitive]),
               let match = regex.firstMatch(in: fname, range: range),
               let r = Range(match.range(at: 1), in: fname) {
                titleId = String(fname[r]).uppercased()
            }
        }
        
        // Fall back to title database matching across 29,000+ Switch titles
        if titleId == nil || titleId?.isEmpty == true {
            titleId = CompatibilityService.shared.findTitleId(forGameTitle: name)?.uppercased()
        }
        
        if bundleId == nil, let tid = titleId {
            bundleId = "org.nxnative.\(tid.lowercased())"
        }
        
        let game = PortedGame(
            name: name,
            url: url,
            platform: .ios,
            sizeBytes: size,
            modificationDate: modDate,
            bundleId: bundleId,
            titleId: titleId?.uppercased(),
            versionString: version
        )
        cacheLock.lock()
        ipaMetadataCache[pathKey] = (modDate: modDate, size: size, game: game)
        cacheLock.unlock()
        return game
    }
    
    private func calculateDirectorySize(url: URL) -> Int64 {
        let fm = FileManager.default
        guard let files = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let file as URL in files {
            if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize { total += Int64(size) }
        }
        return total
    }
    
    public func launchGame(at url: URL, env: [String: String]? = nil, completion: @escaping (Bool, String?) -> Void) {
        guard url.pathExtension.lowercased() == "app" else {
            completion(false, "Cannot launch non-macOS application bundle locally.")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(false, "Internal error: LibraryScanner unavailable.")
                }
                return
            }

            // 1. Remove macOS quarantine attribute safely with timeout to satisfy Gatekeeper
            self.runProcessWithTimeout(executable: "/usr/bin/xattr", arguments: ["-d", "com.apple.quarantine", url.path], timeoutSeconds: 2.0)
            self.runProcessWithTimeout(executable: "/usr/bin/xattr", arguments: ["-cr", url.appendingPathComponent("Contents/MacOS").path], timeoutSeconds: 2.0)

            // 2. Ensure executable permissions and ad-hoc sign Mach-O binaries in Contents/MacOS (fast ~0.02s, not deep bundle hashing)
            let fm = FileManager.default
            let macosDir = url.appendingPathComponent("Contents/MacOS")
            let dmhostURL = macosDir.appendingPathComponent("dmhost")
            if fm.fileExists(atPath: dmhostURL.path) {
                try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dmhostURL.path)
                self.runProcessWithTimeout(executable: "/usr/bin/codesign", arguments: ["--force", "--sign", "-", dmhostURL.path], timeoutSeconds: 2.0)
            }

            if let binFiles = try? fm.contentsOfDirectory(at: macosDir, includingPropertiesForKeys: nil) {
                for bin in binFiles where bin.lastPathComponent != "dmhost" {
                    try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: bin.path)
                    self.runProcessWithTimeout(executable: "/usr/bin/codesign", arguments: ["--force", "--sign", "-", bin.path], timeoutSeconds: 2.0)
                }
            }

            // Remove any stale/partial bundle-level _CodeSignature left by interrupted bundle signing
            // (signing the top-level .app hashes all of Contents/Resources/ which can be 40+ GB; Mach-O binaries in Contents/MacOS carry their own embedded LC_CODE_SIGNATURE)
            let codeSigDir = url.appendingPathComponent("Contents/_CodeSignature")
            if fm.fileExists(atPath: codeSigDir.path) {
                try? fm.removeItem(at: codeSigDir)
            }

            DispatchQueue.main.async {
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                
                // MANDATORY ZERO-HANG RULE: Inherit system environment (PATH, HOME, USER)
                // dmhost and system libraries crash or abort if HOME/USER/PATH are missing!
                var envDict = ProcessInfo.processInfo.environment
                if let env = env {
                    for (k, v) in env { envDict[k] = v }
                }
                if envDict["DM_LAUNCHER"] == nil {
                    envDict["DM_LAUNCHER"] = "0"
                }
                config.environment = envDict
                
                NSWorkspace.shared.openApplication(at: url, configuration: config) { app, error in
                    if let err = error {
                        completion(false, err.localizedDescription)
                    } else {
                        GameControllerService.shared.activeRunningGameApp = app
                        completion(true, nil)
                    }
                }
            }
        }
    }

    @discardableResult
    private func runProcessWithTimeout(executable: String, arguments: [String], timeoutSeconds: Double = 3.0) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            let deadline = DispatchTime.now() + timeoutSeconds
            while process.isRunning && DispatchTime.now() < deadline {
                usleep(30_000) // 30ms polling
            }
            if process.isRunning {
                process.terminate()
                return false
            }
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
