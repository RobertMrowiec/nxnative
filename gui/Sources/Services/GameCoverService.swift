import Foundation
import AppKit
import SwiftUI
import Vision

public final class GameCoverService: ObservableObject {
    public static let shared = GameCoverService()

    private let memoryCache = NSCache<NSString, NSImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let coversRepoDirectory: URL
    private let lock = NSLock()

    private var inFlightDownloads = Set<String>()
    private var failedLookups = Set<String>()

    @Published public var refreshRevision: Int = 0

    /// Verified Title ID -> GameTDB 5-letter IDs (checked against official switchtdb.txt)
    public static var verifiedGameTDBIds: [String: [String]] {
        GameTDBVerifiedDatabase.ids
    }

    private init() {
        let appSup = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/nxnative/covers")
        try? fileManager.createDirectory(at: appSup, withIntermediateDirectories: true)
        self.cacheDirectory = appSup

        let detected = SystemDetector.shared.detectNxnativeDirectory().path
        let repoCovers = URL(fileURLWithPath: detected).appendingPathComponent("docs/images/covers")
        if fileManager.fileExists(atPath: repoCovers.path) {
            self.coversRepoDirectory = repoCovers
        } else {
            self.coversRepoDirectory = URL(fileURLWithPath: "/Volumes/SSD FN501 PRO/Emulations/NativePort/nxnative/docs/images/covers")
        }

        // Expanded memory bounds for whole library/compatibility list: 512 images or 128 MB max
        memoryCache.countLimit = 512
        memoryCache.totalCostLimit = 128 * 1024 * 1024
    }

    public func purgeMemoryCaches() {
        memoryCache.removeAllObjects()
    }

    private func cacheImage(_ img: NSImage, forKeys keys: [String]) {
        let approxBytes = Int(img.size.width * img.size.height * 4)
        for key in keys {
            memoryCache.setObject(img, forKey: key.uppercased() as NSString, cost: max(approxBytes, 1024))
        }
    }

    private func getCachedImage(forKeys keys: [String]) -> NSImage? {
        for key in keys {
            if let cached = memoryCache.object(forKey: key.uppercased() as NSString) {
                return cached
            }
        }
        return nil
    }

    public func customCoverURL(for game: PortedGame) -> URL {
        let titleId = (game.titleId ?? CompatibilityService.shared.findTitleId(forGameTitle: game.name))?.uppercased()
        let key = (titleId ?? game.uniqueKey).uppercased()
        return cacheDirectory.appendingPathComponent("\(key).custom.jpg")
    }

    public func hasCustomCover(for game: PortedGame) -> Bool {
        fileManager.fileExists(atPath: customCoverURL(for: game).path)
    }

    public func setCustomCover(imageURL: URL, for game: PortedGame) -> Bool {
        guard let image = ImageDownsampler.downsample(url: imageURL, maxPixelSize: 320) ?? NSImage(contentsOf: imageURL) else { return false }
        let titleId = (game.titleId ?? CompatibilityService.shared.findTitleId(forGameTitle: game.name))?.uppercased()
        let key = (titleId ?? game.uniqueKey).uppercased()
        let dest = customCoverURL(for: game)

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpgData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.90]) else {
            return false
        }

        do {
            try jpgData.write(to: dest, options: .atomic)
            injectCoverIfPossible(sourceImageData: jpgData, targetAppURL: game.url)

            var keysToCache = [key]
            if let tid = titleId { keysToCache.append(tid) }
            cacheImage(image, forKeys: keysToCache)

            DispatchQueue.main.async {
                self.refreshRevision += 1
                self.objectWillChange.send()
                ArtworkStore.shared.notifyArtworkUpdated(for: key, titleId: titleId)
            }
            return true
        } catch {
            return false
        }
    }

    public func resetCustomCover(for game: PortedGame) {
        let titleId = (game.titleId ?? CompatibilityService.shared.findTitleId(forGameTitle: game.name))?.uppercased()
        let key = (titleId ?? game.uniqueKey).uppercased()
        let dest = customCoverURL(for: game)
        try? fileManager.removeItem(at: dest)

        if game.url.pathExtension.lowercased() == "app" {
            let bundleCover = game.url.appendingPathComponent("Contents/Resources/cover.jpg")
            try? fileManager.removeItem(at: bundleCover)
        }

        memoryCache.removeObject(forKey: key as NSString)
        if let tid = titleId {
            memoryCache.removeObject(forKey: tid as NSString)
        }

        _ = coverImage(for: game)
        DispatchQueue.main.async {
            self.refreshRevision += 1
            self.objectWillChange.send()
            ArtworkStore.shared.notifyArtworkUpdated(for: key, titleId: titleId)
        }
    }

    public func coverImage(for game: PortedGame) -> NSImage? {
        let titleId = (game.titleId ?? CompatibilityService.shared.findTitleId(forGameTitle: game.name))?.uppercased()
        let key = (titleId ?? game.uniqueKey).uppercased()
        var lookupKeys = [key]
        if let tid = titleId { lookupKeys.append(tid) }

        if let memoryImage = getCachedImage(forKeys: lookupKeys) {
            return memoryImage
        }

        // 1. User custom cover
        let customFile = customCoverURL(for: game)
        if fileManager.fileExists(atPath: customFile.path),
           let img = ImageDownsampler.downsample(url: customFile, maxPixelSize: 320) ?? NSImage(contentsOf: customFile) {
            cacheImage(img, forKeys: lookupKeys)
            return img
        }

        // 2. Check game bundle's Contents/Resources for cover art
        let bundleResources = game.url.appendingPathComponent("Contents/Resources")
        for filename in ["cover.jpg", "cover.png", "coverHQ.jpg", "boxart.jpg"] {
            let bundleCover = bundleResources.appendingPathComponent(filename)
            if fileManager.fileExists(atPath: bundleCover.path),
               let img = ImageDownsampler.downsample(url: bundleCover, maxPixelSize: 320) ?? NSImage(contentsOf: bundleCover),
               img.isValid, img.size.width >= 32, img.size.height >= 32 {
                cacheImage(img, forKeys: lookupKeys)
                return img
            }
        }

        // 3. Check disk cache in ~/Library/Application Support/nxnative/covers/<TitleID>.jpg
        if let tid = titleId, !tid.isEmpty {
            let cached = cacheDirectory.appendingPathComponent("\(tid).jpg")
            if fileManager.fileExists(atPath: cached.path),
               let img = ImageDownsampler.downsample(url: cached, maxPixelSize: 320) ?? NSImage(contentsOf: cached),
               img.isValid, img.size.width >= 32, img.size.height >= 32 {
                cacheImage(img, forKeys: lookupKeys)
                injectCoverIfPossible(sourceImageURL: cached, targetAppURL: game.url)
                return img
            }
        }

        // 4. Check local docs/images/covers/ repository for matching portrait box art
        if let localCover = findLocalRepoCover(forGameName: game.name, titleId: titleId) {
            if let img = ImageDownsampler.downsample(url: localCover, maxPixelSize: 320) ?? NSImage(contentsOf: localCover) {
                cacheImage(img, forKeys: lookupKeys)
                if let tid = titleId, !tid.isEmpty {
                    let cacheTarget = cacheDirectory.appendingPathComponent("\(tid).jpg")
                    if !fileManager.fileExists(atPath: cacheTarget.path) {
                        try? fileManager.copyItem(at: localCover, to: cacheTarget)
                    }
                }
                injectCoverIfPossible(sourceImageURL: localCover, targetAppURL: game.url)
                return img
            }
        }

        // 5. For Non-Switch games, use high-resolution macOS application bundle icon
        if game.platform == .nonSwitch {
            let icon = NSWorkspace.shared.icon(forFile: game.url.path)
            icon.size = NSSize(width: 320, height: 320)
            cacheImage(icon, forKeys: lookupKeys)
            return icon
        }

        // 6. Asynchronously fetch from online databases (GameTDB, Libretro, Nintendo CDN)
        fetchOfficialCoverAsync(titleId: titleId, gameName: game.name, targetAppURL: game.url, gameKey: key)
        return nil
    }

    public func ensureCover(for game: PortedGame) {
        _ = coverImage(for: game)
    }

    public func coverImage(titleId: String?, gameName: String) -> NSImage? {
        let resolvedId = (titleId ?? CompatibilityService.shared.findTitleId(forGameTitle: gameName))?.uppercased()
        let key = (resolvedId ?? gameName).uppercased()
        var lookupKeys = [key]
        if let tid = resolvedId { lookupKeys.append(tid) }

        if let memoryImage = getCachedImage(forKeys: lookupKeys) {
            return memoryImage
        }

        if let tid = resolvedId, !tid.isEmpty {
            let cached = cacheDirectory.appendingPathComponent("\(tid).jpg")
            if fileManager.fileExists(atPath: cached.path),
               let img = ImageDownsampler.downsample(url: cached, maxPixelSize: 320) ?? NSImage(contentsOf: cached),
               img.isValid, img.size.width >= 32, img.size.height >= 32 {
                cacheImage(img, forKeys: lookupKeys)
                return img
            }
        }

        if let localCover = findLocalRepoCover(forGameName: gameName, titleId: resolvedId) {
            if let img = ImageDownsampler.downsample(url: localCover, maxPixelSize: 320) ?? NSImage(contentsOf: localCover),
               img.isValid, img.size.width >= 32, img.size.height >= 32 {
                cacheImage(img, forKeys: lookupKeys)
                return img
            }
        }

        fetchOfficialCoverAsync(titleId: resolvedId, gameName: gameName, targetAppURL: nil, gameKey: key)
        return nil
    }

    public func injectCoverIntoBundle(at appURL: URL, gameName: String, titleId: String?) {
        let resolvedId = (titleId ?? CompatibilityService.shared.findTitleId(forGameTitle: gameName))?.uppercased()
        if let localCover = findLocalRepoCover(forGameName: gameName, titleId: resolvedId) {
            injectCoverIfPossible(sourceImageURL: localCover, targetAppURL: appURL)
        } else if let tid = resolvedId, !tid.isEmpty {
            let cached = cacheDirectory.appendingPathComponent("\(tid).jpg")
            if fileManager.fileExists(atPath: cached.path) {
                injectCoverIfPossible(sourceImageURL: cached, targetAppURL: appURL)
            }
        }
    }

    private func injectCoverIfPossible(sourceImageURL: URL, targetAppURL: URL) {
        guard targetAppURL.pathExtension.lowercased() == "app" else { return }
        let resources = targetAppURL.appendingPathComponent("Contents/Resources")
        let targetCover = resources.appendingPathComponent("cover.jpg")

        if !fileManager.fileExists(atPath: targetCover.path) && fileManager.fileExists(atPath: resources.path) {
            try? fileManager.copyItem(at: sourceImageURL, to: targetCover)
        }
    }

    private func injectCoverIfPossible(sourceImageData: Data, targetAppURL: URL) {
        guard targetAppURL.pathExtension.lowercased() == "app" else { return }
        let resources = targetAppURL.appendingPathComponent("Contents/Resources")
        let targetCover = resources.appendingPathComponent("cover.jpg")

        if !fileManager.fileExists(atPath: targetCover.path) && fileManager.fileExists(atPath: resources.path) {
            try? sourceImageData.write(to: targetCover)
        }
    }

    private func findLocalRepoCover(forGameName name: String, titleId: String?) -> URL? {
        if let tid = titleId, !tid.isEmpty {
            for ext in ["jpg", "png", "jpeg"] {
                let byId = coversRepoDirectory.appendingPathComponent("\(tid.uppercased()).\(ext)")
                if fileManager.fileExists(atPath: byId.path),
                   let img = ImageDownsampler.downsample(url: byId, maxPixelSize: 320) ?? NSImage(contentsOf: byId),
                   img.isValid, img.size.width >= 32, img.size.height >= 32 {
                    return byId
                }
            }
        }

        let imagesDir = coversRepoDirectory.deletingLastPathComponent()
        let slug = slugify(name)
        if !slug.isEmpty {
            for ext in ["jpg", "png", "jpeg"] {
                let bySlug = imagesDir.appendingPathComponent("\(slug).\(ext)")
                if fileManager.fileExists(atPath: bySlug.path),
                   let img = ImageDownsampler.downsample(url: bySlug, maxPixelSize: 320) ?? NSImage(contentsOf: bySlug),
                   img.isValid, img.size.width >= 32, img.size.height >= 32 {
                    return bySlug
                }
            }
        }

        return nil
    }

    private func slugify(_ str: String) -> String {
        let folded = str.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let allowed = CharacterSet.alphanumerics
        let clean = folded.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        return String(clean)
            .components(separatedBy: "-")
            .filter { !$0.isEmpty }
            .joined(separator: "-")
            .lowercased()
    }

    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 3.0
        config.timeoutIntervalForResource = 6.0
        config.httpMaximumConnectionsPerHost = 4
        return URLSession(configuration: config)
    }()

    private var updateTimer: Timer? = nil
    private func scheduleBatchUpdateNotification() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.updateTimer?.invalidate()
            self.updateTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
                self?.refreshRevision += 1
                self?.objectWillChange.send()
            }
        }
    }

    private func fetchOfficialCoverAsync(titleId: String?, gameName: String, targetAppURL: URL?, gameKey: String? = nil) {
        let tidUpper = titleId?.uppercased()
        let searchKey = (gameKey ?? tidUpper ?? gameName).uppercased()

        lock.lock()
        if inFlightDownloads.contains(searchKey) || failedLookups.contains(searchKey) {
            lock.unlock()
            return
        }
        inFlightDownloads.insert(searchKey)
        lock.unlock()

        var candidates: [URL] = []

        // 1. High-Quality Clean Game Artwork from upstream repository (Gallery / Showcase)
        if let fn = ArtworkStore.shared.galleryFilename(for: tidUpper ?? searchKey) ?? ArtworkStore.shared.galleryFilename(for: gameName) {
            let localGallery = self.coversRepoDirectory.deletingLastPathComponent().appendingPathComponent(fn)
            if fileManager.fileExists(atPath: localGallery.path) {
                candidates.append(localGallery)
            }
            if let rawGitURL = URL(string: "https://raw.githubusercontent.com/seedds/nxnative/main/docs/images/\(fn)") {
                candidates.append(rawGitURL)
            }
        }

        // 2. High-Probability GameTDB Box Arts (Priority: US, EN, JA)
        if let tid = tidUpper {
            let gids = Self.verifiedGameTDBIds[tid] ?? []
            for gid in gids {
                for sub in ["coverHQ", "cover"] {
                    for reg in ["US", "EN", "JA"] {
                        if let u = URL(string: "https://art.gametdb.com/switch/\(sub)/\(reg)/\(gid).jpg") {
                            candidates.append(u)
                        }
                    }
                }
            }
        }

        // 3. High-Probability Libretro Named_Boxarts
        let cleanTitle = gameName
            .replacingOccurrences(of: ":", with: " -")
            .replacingOccurrences(of: "\u{2122}", with: "")
            .replacingOccurrences(of: "\u{00AE}", with: "")
        for suffix in ["", " (World)", " (USA)"] {
            if let encoded = "\(cleanTitle)\(suffix).png".addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
               let libretroURL = URL(string: "https://thumbnails.libretro.com/Nintendo%20-%20Switch/Named_Boxarts/\(encoded)") {
                candidates.append(libretroURL)
            }
        }

        guard !candidates.isEmpty else {
            lock.lock()
            inFlightDownloads.remove(searchKey)
            lock.unlock()
            return
        }

        tryFetchCandidate(candidates: candidates, index: 0) { [weak self] rawData, rawImg in
            guard let self = self else { return }
            defer {
                self.lock.lock()
                self.inFlightDownloads.remove(searchKey)
                self.lock.unlock()
            }

            guard let rawData = rawData, let rawImg = rawImg else {
                self.lock.lock()
                self.failedLookups.insert(searchKey)
                self.lock.unlock()
                return
            }

            // Strip console branding banners, age ratings, and platform logos (Steam/Playnite/RetroArch clean art style)
            let (data, img) = self.cleanArtworkForCleanPresentation(from: rawImg, originalData: rawData)

            // Strict Anti-Store Branding Guard: if image still contains eShop text, discard immediately
            if self.containsForbiddenStoreBranding(in: img) {
                self.lock.lock()
                self.failedLookups.insert(searchKey)
                self.lock.unlock()
                return
            }

            if let tid = tidUpper {
                let target = self.cacheDirectory.appendingPathComponent("\(tid).jpg")
                try? data.write(to: target, options: .atomic)
            }
            if let appURL = targetAppURL {
                self.injectCoverIfPossible(sourceImageData: data, targetAppURL: appURL)
            }

            var keysToCache = [searchKey]
            if let tid = tidUpper { keysToCache.append(tid) }
            self.cacheImage(img, forKeys: keysToCache)

            DispatchQueue.main.async {
                self.scheduleBatchUpdateNotification()
                ArtworkStore.shared.notifyArtworkUpdated(for: searchKey, titleId: tidUpper)
            }
        }
    }

    /// Strips retail plastic console header banners, age ratings, and console logos from box arts,
    /// ensuring only pure game illustration and title logo are displayed (matching Steam Grid / Playnite clean room style).
    private func cleanArtworkForCleanPresentation(from image: NSImage, originalData: Data) -> (Data, NSImage) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return (originalData, image)
        }
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        
        // Only crop retail box art scans where aspect ratio indicates a vertical case (height >= width * 1.05)
        guard height >= width * 1.05 else {
            return (originalData, image)
        }
        
        let rep = NSBitmapImageRep(cgImage: cgImage)
        let w = rep.pixelsWide
        let h = rep.pixelsHigh
        
        // Dynamic Red Console Header Detection (Nintendo Switch red bar #E60012)
        var lastRedY = 0
        let scanLimit = Int(Double(h) * 0.35)
        for y in 0..<scanLimit {
            var redCount = 0
            for x in 0..<w {
                if let c = rep.colorAt(x: x, y: y),
                   c.redComponent > 0.55 && c.greenComponent < 0.35 && c.blueComponent < 0.35 {
                    redCount += 1
                }
            }
            if Double(redCount) / Double(w) > 0.55 {
                lastRedY = y
            }
        }
        
        // Top cut: if solid red header found, cut through the last red row + 6px safety padding into the illustration.
        // If no solid red detected (e.g. monochromatic or dark header), enforce universal 18.5% console header standard.
        var topCut = CGFloat(lastRedY > 0 ? lastRedY + 6 : Int(Double(h) * 0.185))
        topCut = max(CGFloat(h) * 0.18, min(topCut, CGFloat(h) * 0.33))
        
        // Bottom cut: 9% removes publisher logos, Nintendo red oval mark, and ESRB/PEGI rating boxes.
        let bottomCut = CGFloat(h) * 0.09
        
        // Side cut: 2.5% removes plastic case bevel, shadows, and spine edges.
        let sideCut = CGFloat(w) * 0.025
        
        let cropRect = CGRect(
            x: sideCut,
            y: topCut,
            width: max(10, CGFloat(w) - (sideCut * 2)),
            height: max(10, CGFloat(h) - topCut - bottomCut)
        )
        
        guard let croppedCg = cgImage.cropping(to: cropRect) else {
            return (originalData, image)
        }
        
        let croppedRep = NSBitmapImageRep(cgImage: croppedCg)
        guard let jpgData = croppedRep.representation(using: .jpeg, properties: [.compressionFactor: 0.90]) else {
            return (originalData, image)
        }
        let cleanedImage = NSImage(cgImage: croppedCg, size: NSSize(width: cropRect.width, height: cropRect.height))
        return (jpgData, cleanedImage)
    }

    private func containsForbiddenStoreBranding(in image: NSImage) -> Bool {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return false }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        try? handler.perform([request])
        for obs in request.results ?? [] {
            let text = obs.topCandidates(1).first?.string.lowercased() ?? ""
            if text.contains("eshop") || text.contains("e-shop") || text.contains("nintendo eshop") {
                return true
            }
        }
        return false
    }

    private func tryFetchCandidate(
        candidates: [URL],
        index: Int,
        completion: @escaping (Data?, NSImage?) -> Void
    ) {
        guard index < candidates.count else {
            completion(nil, nil)
            return
        }
        let url = candidates[index]
        let task = urlSession.dataTask(with: url) { [weak self] data, response, _ in
            guard let self = self else { return }
            if let http = response as? HTTPURLResponse, http.statusCode == 200,
               let d = data, !d.isEmpty,
               let img = ImageDownsampler.downsample(data: d, maxPixelSize: 480) ?? NSImage(data: d),
               img.isValid, img.size.width >= 32, img.size.height >= 32 {
                
                // Real-time Vision Guard: reject candidate if it has eShop marks
                if self.containsForbiddenStoreBranding(in: img) {
                    self.tryFetchCandidate(candidates: candidates, index: index + 1, completion: completion)
                    return
                }

                completion(d, img)
            } else {
                self.tryFetchCandidate(candidates: candidates, index: index + 1, completion: completion)
            }
        }
        task.resume()
    }
}
