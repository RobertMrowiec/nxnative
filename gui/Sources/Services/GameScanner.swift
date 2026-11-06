import Foundation

public struct NupMetadata {
    public let titleId: String?
    public let embeddedTitle: String?
    public let versionString: String?
    public let updateCount: Int
    public let dlcCount: Int
}

public final class GameScanner {
    public static let shared = GameScanner()
    public static let allowedExtensions: Set<String> = ["nsp", "nsz", "xci", "xcz", "nup"]
    
    private static let skippedDirectoryNames: Set<String> = [
        "staging", "shader", "extract", "romfs", "exefs", "pso", "logs", "tools", "font", "aoc", ".git", "node_modules", ".build", "build"
    ]
    
    private init() {}
    
    public func scan(directory: URL) -> [GameFileItem] {
        let fm = FileManager.default
        
        // Support passing a single ROM / .nup file directly
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: directory.path, isDirectory: &isDir) else { return [] }
        if !isDir.boolValue {
            if let single = scanFile(url: directory) {
                return [single]
            }
            return []
        }
        
        // Check if directory itself is a game dump folder
        let rootDumpItems = inspectDumpItems(url: directory)
        if !rootDumpItems.isEmpty {
            return rootDumpItems
        }
        
        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }
        
        var results: [GameFileItem] = []
        let titleIdRegex = try? NSRegularExpression(pattern: "\\[([0-9A-Fa-f]{16})\\]", options: [])
        let versionRegex = try? NSRegularExpression(pattern: "\\[v([0-9]+)\\]|v([0-9]+\\.[0-9]+(?:\\.[0-9]+)?)", options: [.caseInsensitive])
        
        for case let fileURL as URL in enumerator {
            let filename = fileURL.lastPathComponent
            if filename.hasPrefix("._") { continue }
            
            let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey])
            
            if resourceValues?.isDirectory == true {
                let dirLower = filename.lowercased()
                if dirLower.hasSuffix("_build") ||
                   dirLower.hasSuffix("-work") ||
                   dirLower.hasSuffix("_survey") ||
                   dirLower.hasSuffix(".app") ||
                   dirLower.hasSuffix(".framework") ||
                   dirLower.hasSuffix(".xcarchive") ||
                   dirLower.hasPrefix("patched_") ||
                   Self.skippedDirectoryNames.contains(dirLower) {
                    enumerator.skipDescendants()
                    continue
                }
                
                // Check for game dumps (folders containing base/exefs/main.npdm)
                let dumpItems = inspectDumpItems(url: fileURL)
                if !dumpItems.isEmpty {
                    enumerator.skipDescendants()
                    results.append(contentsOf: dumpItems)
                    continue
                }
            }
            
            if let item = scanFile(url: fileURL, preloadedValues: resourceValues, titleIdRegex: titleIdRegex, versionRegex: versionRegex) {
                results.append(item)
            }
        }
        
        // Sort: Base and Switch 2 Dumps first, then Update, then DLC
        return results.sorted { a, b in
            let scoreA: Int
            switch a.type { case .base, .switch2Dump: scoreA = 0; case .update: scoreA = 1; case .dlc: scoreA = 2; case .unknown: scoreA = 3 }
            let scoreB: Int
            switch b.type { case .base, .switch2Dump: scoreB = 0; case .update: scoreB = 1; case .dlc: scoreB = 2; case .unknown: scoreB = 3 }
            if scoreA != scoreB { return scoreA < scoreB }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }
    
    public func scanFile(
        url fileURL: URL,
        preloadedValues: URLResourceValues? = nil,
        titleIdRegex: NSRegularExpression? = nil,
        versionRegex: NSRegularExpression? = nil
    ) -> GameFileItem? {
        let filename = fileURL.lastPathComponent
        guard !filename.hasPrefix("._") else { return nil }
        let ext = fileURL.pathExtension.lowercased()
        guard Self.allowedExtensions.contains(ext) else { return nil }
        
        let resourceValues = preloadedValues ?? (try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey]))
        guard resourceValues?.isRegularFile == true else { return nil }
        let size = Int64(resourceValues?.fileSize ?? 0)
        
        let tidRegex = titleIdRegex ?? (try? NSRegularExpression(pattern: "\\[([0-9A-Fa-f]{16})\\]", options: []))
        let verRegex = versionRegex ?? (try? NSRegularExpression(pattern: "\\[v([0-9]+)\\]|v([0-9]+\\.[0-9]+(?:\\.[0-9]+)?)", options: [.caseInsensitive]))
        
        let nupMeta: NupMetadata? = (ext == "nup") ? inspectNupMetadata(url: fileURL) : nil
        
        // Extrai Title ID (1. Tag [0100...] no nome, 2. Header NUP / PFS0 .tik, 3. Busca por nome no banco)
        var titleId: String? = nil
        var hasExplicitTitleId = false
        if let regex = tidRegex,
           let match = regex.firstMatch(in: filename, range: NSRange(filename.startIndex..., in: filename)),
           let range = Range(match.range(at: 1), in: filename) {
            titleId = String(filename[range]).uppercased()
            hasExplicitTitleId = true
        } else if let nupTid = nupMeta?.titleId ?? (ext == "nup" ? extractTitleIdFromNup(url: fileURL) : nil) {
            titleId = nupTid.uppercased()
            hasExplicitTitleId = true
        } else if let headerTid = extractTitleIdFromPFS0(url: fileURL) {
            titleId = headerTid.uppercased()
            hasExplicitTitleId = true
        } else {
            let clean = cleanGameTitle(filename)
            if let matchedTid = CompatibilityService.shared.findTitleId(forGameTitle: clean) {
                titleId = matchedTid.uppercased()
            } else if let embeddedName = nupMeta?.embeddedTitle,
                      let matchedTid = CompatibilityService.shared.findTitleId(forGameTitle: embeddedName) {
                titleId = matchedTid.uppercased()
            }
        }
        
        // Extract Version
        var versionString: String? = nil
        if let regex = verRegex,
           let match = regex.firstMatch(in: filename, range: NSRange(filename.startIndex..., in: filename)) {
            if match.range(at: 1).location != NSNotFound, let r = Range(match.range(at: 1), in: filename) {
                versionString = "v" + String(filename[r])
            } else if match.range(at: 2).location != NSNotFound, let r = Range(match.range(at: 2), in: filename) {
                versionString = "v" + String(filename[r])
            }
        }
        if versionString == nil, let nupVer = nupMeta?.versionString {
            versionString = nupVer
        }
        
        // Determina tipo (Base, Update ou DLC)
        let lower = filename.lowercased()
        let parentFolderLower = fileURL.deletingLastPathComponent().lastPathComponent.lowercased()
        let type: GameFileType
        if ext == "nup" {
            if let tid = titleId, tid.hasPrefix("0400") || lower.contains("switch 2") || lower.contains("switch2") || parentFolderLower.contains("switch 2") || parentFolderLower.contains("switch2") {
                type = .switch2Dump
            } else {
                type = .base
            }
        } else if hasExplicitTitleId, let tid = titleId, let val = UInt64(tid, radix: 16) {
            let low = val & 0xFFF
            if low == 0 {
                type = .base
            } else if low == 0x800 {
                type = .update
            } else {
                type = .dlc
            }
        } else if lower.contains("dlc") || parentFolderLower == "dlc" || parentFolderLower == "dlcs" {
            type = .dlc
        } else if lower.contains("update") || lower.contains("patch") || parentFolderLower == "update" || parentFolderLower == "updates" || (versionString != nil && versionString != "v0" && !lower.contains("base")) {
            type = .update
        } else if let tid = titleId {
            if tid.hasSuffix("000") {
                type = .base
            } else if tid.hasSuffix("800") {
                type = .update
            } else {
                type = .dlc
            }
        } else if lower.contains("base") || versionString == "v0" || ext == "nsp" || ext == "xci" {
            type = .base
        } else {
            type = .unknown
        }
        
        let cleanFromFilename = cleanGameTitle(filename)
        let displayFilename: String
        if ext == "nup",
           (cleanFromFilename.isEmpty || cleanFromFilename.count <= 4),
           let embedded = nupMeta?.embeddedTitle, !embedded.isEmpty {
            displayFilename = embedded
        } else {
            displayFilename = filename
        }
        
        return GameFileItem(
            url: fileURL,
            name: displayFilename,
            sizeBytes: size,
            type: type,
            titleId: titleId,
            versionString: versionString,
            nupUpdateCount: nupMeta?.updateCount ?? 0,
            nupDlcCount: nupMeta?.dlcCount ?? 0
        )
    }
    
    /// Scans multiple directories and all their subdirectories recursively, aggregating and deduplicating game files.
    public func scan(directories: [URL]) -> [GameFileItem] {
        var allItems: [GameFileItem] = []
        var seenPaths = Set<String>()
        
        for dir in directories {
            let items = scan(directory: dir)
            for item in items {
                let standardPath = item.url.standardizedFileURL.path
                if !seenPaths.contains(standardPath) {
                    seenPaths.insert(standardPath)
                    allItems.append(item)
                }
            }
        }
        
        return allItems.sorted { a, b in
            let scoreA: Int
            switch a.type { case .base, .switch2Dump: scoreA = 0; case .update: scoreA = 1; case .dlc: scoreA = 2; case .unknown: scoreA = 3 }
            let scoreB: Int
            switch b.type { case .base, .switch2Dump: scoreB = 0; case .update: scoreB = 1; case .dlc: scoreB = 2; case .unknown: scoreB = 3 }
            if scoreA != scoreB { return scoreA < scoreB }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }
    
    /// Converte qualquer Title ID (Base ...000, Update ...800, ou DLC ...(Y+1)ZZZ) para o Title ID de 16 caracteres do jogo Base.
    public func baseApplicationTitleId(for tid: String) -> String? {
        let trimmed = tid.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard trimmed.count == 16, let val = UInt64(trimmed, radix: 16) else { return nil }
        let low = val & 0xFFF
        let baseVal: UInt64
        if low == 0 {
            baseVal = val
        } else if low == 0x800 {
            baseVal = val & ~0xFFF
        } else {
            baseVal = (val & ~0xFFF) &- 0x1000
        }
        return String(format: "%016llX", baseVal)
    }
    
    /// Lê o cabeçalho PFS0 de um arquivo .nsp / .nsz para extrair o Title ID do ticket (<32-hex>.tik), igual ao build_ipa_from_nsp.py.
    public func extractTitleIdFromPFS0(url: URL) -> String? {
        let ext = url.pathExtension.lowercased()
        guard ext == "nsp" || ext == "nsz" else { return nil }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        
        guard let header = try? handle.read(upToCount: 16), header.count == 16 else { return nil }
        guard header[0] == 0x50, header[1] == 0x46, header[2] == 0x53, header[3] == 0x30 else { return nil } // "PFS0"
        
        let numFiles = header.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self).littleEndian }
        let strTableSize = header.withUnsafeBytes { $0.load(fromByteOffset: 8, as: UInt32.self).littleEndian }
        guard numFiles > 0, numFiles < 2048, strTableSize > 0, strTableSize < 262144 else { return nil }
        
        let entriesBytes = Int(numFiles) * 24
        guard let rest = try? handle.read(upToCount: entriesBytes + Int(strTableSize)),
              rest.count >= entriesBytes + Int(strTableSize) else { return nil }
        
        let strTableData = rest.subdata(in: entriesBytes..<(entriesBytes + Int(strTableSize)))
        guard let rawStrings = String(data: strTableData, encoding: .ascii) else { return nil }
        
        let tikRegex = try? NSRegularExpression(pattern: "([0-9A-Fa-f]{16})[0-9A-Fa-f]{16}\\.tik", options: [])
        if let regex = tikRegex,
           let match = regex.firstMatch(in: rawStrings, range: NSRange(rawStrings.startIndex..., in: rawStrings)),
           let range = Range(match.range(at: 1), in: rawStrings) {
            return String(rawStrings[range]).uppercased()
        }
        return nil
    }
    
    /// Lê os cabeçalhos de um contêiner .nup para extrair o Title ID do primeiro pacote registrado (SPEC v1).
    public func extractTitleIdFromNup(url: URL) -> String? {
        return inspectNupMetadata(url: url)?.titleId
    }
    
    /// Inspeciona o cabeçalho TOC e os registros de metadados TLV de um contêiner .nup (SPEC v1) sem descompactar o arquivo.
    public func inspectNupMetadata(url: URL) -> NupMetadata? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        
        guard let superData = try? handle.read(upToCount: 128), superData.count >= 24 else { return nil }
        guard superData[0] == 0x4E, superData[1] == 0x55, superData[2] == 0x50, superData[3] == 0x01 else { return nil } // "NUP\x01"
        
        let tocOff = superData.subdata(in: 8..<16).withUnsafeBytes { $0.load(as: UInt64.self).littleEndian }
        let tocSize = superData.subdata(in: 16..<24).withUnsafeBytes { $0.load(as: UInt64.self).littleEndian }
        guard tocSize >= 48 + 64 else { return nil }
        
        guard (try? handle.seek(toOffset: tocOff)) != nil else { return nil }
        let readCap = Int(min(tocSize, 48 + 32 * 64))
        guard let tocHead = try? handle.read(upToCount: readCap), tocHead.count >= 48 + 64 else { return nil }
        guard tocHead[0] == 0x54, tocHead[1] == 0x4F, tocHead[2] == 0x43, tocHead[3] == 0x01 else { return nil } // "TOC\x01"
        
        let numPkgs = tocHead.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
        guard numPkgs > 0 else { return nil }
        
        let pkgLimit = min(Int(numPkgs), (tocHead.count - 48) / 64)
        var resolvedBaseTid: String? = nil
        var fallbackTid: String? = nil
        var updateCount = 0
        var dlcCount = 0
        var maxVersion: UInt32 = 0
        var metaTarget: (off: UInt64, size: UInt32)? = nil
        
        for i in 0..<pkgLimit {
            let offset = 48 + i * 64
            let pkgTid = tocHead.subdata(in: offset..<(offset + 8)).withUnsafeBytes { $0.load(as: UInt64.self).littleEndian }
            let pkgVer = tocHead.subdata(in: (offset + 20)..<(offset + 24)).withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
            let pkgKind = tocHead[offset + 24]
            let metaOff = tocHead.subdata(in: (offset + 32)..<(offset + 40)).withUnsafeBytes { $0.load(as: UInt64.self).littleEndian }
            let metaSize = tocHead.subdata(in: (offset + 40)..<(offset + 44)).withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
            
            if pkgTid != 0 {
                let hexTid = String(format: "%016llX", pkgTid).uppercased()
                if pkgKind == 0 || (pkgTid & 0xFFF) == 0 {
                    if resolvedBaseTid == nil {
                        resolvedBaseTid = hexTid
                    }
                } else if fallbackTid == nil {
                    fallbackTid = baseApplicationTitleId(for: hexTid) ?? hexTid
                }
            }
            
            if pkgKind == 1 {
                updateCount += 1
                if pkgVer > maxVersion {
                    maxVersion = pkgVer
                }
            } else if pkgKind == 2 {
                dlcCount += 1
            } else if pkgKind == 0 && pkgVer > maxVersion {
                maxVersion = pkgVer
            }
            
            if metaTarget == nil && metaOff > 0 && metaSize >= 8 && metaSize <= 524_288 {
                metaTarget = (metaOff, metaSize)
            }
        }
        
        var embeddedTitle: String? = nil
        if let meta = metaTarget, (try? handle.seek(toOffset: meta.off)) != nil,
           let metaData = try? handle.read(upToCount: Int(meta.size)) {
            var pos = 0
            while pos + 8 <= metaData.count {
                let tlvType = metaData.subdata(in: pos..<(pos + 2)).withUnsafeBytes { $0.load(as: UInt16.self).littleEndian }
                let tlvLen = Int(metaData.subdata(in: (pos + 4)..<(pos + 8)).withUnsafeBytes { $0.load(as: UInt32.self).littleEndian })
                pos += 8
                guard tlvLen >= 0 && pos + tlvLen <= metaData.count else { break }
                if tlvType == 5, tlvLen > 0 {
                    let payload = metaData.subdata(in: pos..<(pos + tlvLen))
                    if let str = String(data: payload, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty {
                        embeddedTitle = str
                        break
                    }
                }
                pos += tlvLen
            }
        }
        
        let finalTid = resolvedBaseTid ?? fallbackTid
        let verStr = maxVersion > 0 ? "v\(maxVersion)" : nil
        return NupMetadata(
            titleId: finalTid,
            embeddedTitle: embeddedTitle,
            versionString: verStr,
            updateCount: updateCount,
            dlcCount: dlcCount
        )
    }
    
    /// Inspeciona pasta de dump e seus updates embutidos (updates/<version>), retornando o item base e os updates
    public func inspectDumpItems(url: URL) -> [GameFileItem] {
        guard let baseItem = inspectDumpFolder(url: url) else { return [] }
        var items = [baseItem]
        let fm = FileManager.default
        let updatesURL = url.appendingPathComponent("updates")
        if let updateFolders = try? fm.contentsOfDirectory(at: updatesURL, includingPropertiesForKeys: [.isDirectoryKey]) {
            for u in updateFolders {
                guard (try? u.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
                let verName = u.lastPathComponent
                if fm.fileExists(atPath: u.appendingPathComponent("exefs").path) || fm.fileExists(atPath: u.appendingPathComponent("romfs").path) {
                    let uSize = fastDumpSubfolderSize(url: u, parentDumpURL: url, titleId: baseItem.titleId, verName: verName)
                    items.append(GameFileItem(
                        url: u,
                        name: "\(url.lastPathComponent) (Update v\(verName))",
                        sizeBytes: uSize,
                        type: .update,
                        titleId: baseItem.titleId,
                        versionString: "v\(verName)"
                    ))
                }
            }
        }
        return items
    }
    
    /// Detecta se uma pasta é um dump de Nintendo Switch (Switch 1 ou Switch 2: base/exefs/main.npdm).
    public func inspectDumpFolder(url: URL) -> GameFileItem? {
        let fm = FileManager.default
        let npdmURL = url.appendingPathComponent("base/exefs/main.npdm")
        guard fm.fileExists(atPath: npdmURL.path) else { return nil }
        
        guard let data = try? Data(contentsOf: npdmURL, options: .mappedIfSafe), data.count >= 0x80 else { return nil }
        guard data.prefix(4) == Data([0x4D, 0x45, 0x54, 0x41]) else { return nil } // "META"
        
        let aci0Offset = data.subdata(in: 0x70..<0x74).withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
        let aci0Size = data.subdata(in: 0x74..<0x78).withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
        guard aci0Size >= 0x18, data.count >= Int(aci0Offset) + Int(aci0Size) else { return nil }
        
        let aci0Header = data.subdata(in: Int(aci0Offset)..<(Int(aci0Offset) + 4))
        guard aci0Header == Data([0x41, 0x43, 0x49, 0x30]) else { return nil } // "ACI0"
        
        let programId = data.subdata(in: (Int(aci0Offset) + 0x10)..<(Int(aci0Offset) + 0x18)).withUnsafeBytes {
            $0.load(as: UInt64.self).littleEndian
        }
        let tidString = String(format: "%016llX", programId).uppercased()
        
        // Detecta versão em updates/
        var versionString: String? = nil
        let updatesURL = url.appendingPathComponent("updates")
        if let updateFolders = try? fm.contentsOfDirectory(at: updatesURL, includingPropertiesForKeys: [.isDirectoryKey]) {
            let numericVers = updateFolders.compactMap { u -> Int? in
                let name = u.lastPathComponent
                guard (try? u.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { return nil }
                return Int(name)
            }
            if let maxVer = numericVers.max() {
                versionString = "v\(maxVer)"
            }
        }
        
        // Fast instant size calculation (avoids walking 100,000+ shader/cache or extracted files inside *_build)
        let totalSize = fastDumpFolderSize(url: url, titleId: tidString)
        
        let isSwitch2 = tidString.hasPrefix("0400")
        let fileType: GameFileType = isSwitch2 ? .switch2Dump : .base
        
        return GameFileItem(
            url: url,
            name: url.lastPathComponent,
            sizeBytes: totalSize,
            type: fileType,
            titleId: tidString,
            versionString: versionString
        )
    }
    
    /// Calcula rapidamente o tamanho de um dump sem varrer pastas *_build ou centenas de milhares de arquivos soltos.
    private func fastDumpFolderSize(url: URL, titleId: String) -> Int64 {
        let fm = FileManager.default
        var totalSize: Int64 = 0
        
        // 1. Sum base/exefs (typically ~5 files)
        let exefsURL = url.appendingPathComponent("base/exefs")
        if let exefsFiles = try? fm.contentsOfDirectory(at: exefsURL, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) {
            for f in exefsFiles {
                if let vals = try? f.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]), vals.isRegularFile == true {
                    totalSize += Int64(vals.fileSize ?? 0)
                }
            }
        }
        
        // 2. Check if a packed RomFS.img already exists in <titleId>_build/extract/*/RomFS.img (1 stat call!)
        let buildExtractURL = url.appendingPathComponent("\(titleId)_build/extract")
        if let verDirs = try? fm.contentsOfDirectory(at: buildExtractURL, includingPropertiesForKeys: [.isDirectoryKey]) {
            var maxImgSize: Int64 = 0
            for vDir in verDirs {
                let imgURL = vDir.appendingPathComponent("RomFS.img")
                if let imgSize = (try? imgURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                    maxImgSize = max(maxImgSize, Int64(imgSize))
                }
            }
            if maxImgSize > 0 {
                return totalSize + maxImgSize
            }
        }
        
        // 3. Otherwise do a bounded sample of base/romfs (max 300 files / 20ms)
        let romfsURL = url.appendingPathComponent("base/romfs")
        totalSize += boundedDirectorySize(at: romfsURL, maxFiles: 300)
        return totalSize
    }
    
    private func fastDumpSubfolderSize(url: URL, parentDumpURL: URL, titleId: String?, verName: String) -> Int64 {
        let fm = FileManager.default
        var totalSize: Int64 = 0
        let exefsURL = url.appendingPathComponent("exefs")
        if let exefsFiles = try? fm.contentsOfDirectory(at: exefsURL, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) {
            for f in exefsFiles {
                if let vals = try? f.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]), vals.isRegularFile == true {
                    totalSize += Int64(vals.fileSize ?? 0)
                }
            }
        }
        if let tid = titleId {
            let imgURL = parentDumpURL.appendingPathComponent("\(tid)_build/extract/v\(verName)/RomFS.img")
            if let imgSize = (try? imgURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                return totalSize + Int64(imgSize)
            }
        }
        let romfsURL = url.appendingPathComponent("romfs")
        totalSize += boundedDirectorySize(at: romfsURL, maxFiles: 200)
        return totalSize
    }
    
    private func boundedDirectorySize(at url: URL, maxFiles: Int) -> Int64 {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path),
              let en = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return 0
        }
        var total: Int64 = 0
        var count = 0
        let deadline = DispatchTime.now() + 0.025 // 25ms hard cap
        for case let file as URL in en {
            count += 1
            if let vals = try? file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]), vals.isRegularFile == true {
                total += Int64(vals.fileSize ?? 0)
            }
            if count >= maxFiles || (count % 50 == 0 && DispatchTime.now() >= deadline) {
                break
            }
        }
        return total
    }
    
    public func groupFilesIntoGames(files: [GameFileItem]) -> [SelectableGame] {
        var groups: [String: (title: String, tid: String?, items: [GameFileItem])] = [:]
        var looseAddons: [GameFileItem] = []
        
        for file in files {
            let clean = cleanGameTitle(file.name)
            let baseTid = file.titleId.flatMap { baseApplicationTitleId(for: $0) }
            
            // Se for um Update ou DLC sem Title ID explícito, guarda para anexar ao jogo base da mesma pasta
            if baseTid == nil && (file.type == .update || file.type == .dlc) {
                looseAddons.append(file)
                continue
            }
            
            let key: String
            if let bTid = baseTid {
                key = bTid
            } else {
                key = clean.lowercased()
            }
            
            if var existing = groups[key] {
                existing.items.append(file)
                if existing.tid == nil, let bTid = baseTid {
                    existing.tid = bTid
                }
                if file.type == .base && !clean.isEmpty {
                    existing.title = clean
                }
                groups[key] = existing
            } else {
                groups[key] = (title: clean, tid: baseTid ?? file.titleId, items: [file])
            }
        }
        
        // Anexa Updates/DLCs sem Title ID explícito ao jogo Base correspondente (por nome ou se houver apenas 1 jogo Base na pasta)
        if !looseAddons.isEmpty {
            let groupKeys = Array(groups.keys)
            for addon in looseAddons {
                let addonClean = cleanGameTitle(addon.name).lowercased()
                if let matchedKey = groupKeys.first(where: { key in
                    guard let grp = groups[key] else { return false }
                    let grpTitle = grp.title.lowercased()
                    return !grpTitle.isEmpty && !addonClean.isEmpty && (addonClean.contains(grpTitle) || grpTitle.contains(addonClean))
                }) {
                    groups[matchedKey]?.items.append(addon)
                } else if groupKeys.count == 1, let onlyKey = groupKeys.first {
                    groups[onlyKey]?.items.append(addon)
                } else {
                    let fallbackKey = addonClean.isEmpty ? addon.name.lowercased() : addonClean
                    if var existing = groups[fallbackKey] {
                        existing.items.append(addon)
                        groups[fallbackKey] = existing
                    } else {
                        groups[fallbackKey] = (title: cleanGameTitle(addon.name), tid: addon.titleId, items: [addon])
                    }
                }
            }
        }
        
        // Caso ainda existam grupos apenas com Updates/DLCs e apenas 1 grupo com jogo Base na mesma pasta, mescla automaticamente
        let baseGroupKeys = groups.keys.filter { key in
            groups[key]?.items.contains(where: { $0.type == .base || $0.type == .switch2Dump || $0.type == .unknown }) == true
        }
        let addonOnlyKeys = groups.keys.filter { key in
            !baseGroupKeys.contains(key)
        }
        if baseGroupKeys.count == 1, let mainKey = baseGroupKeys.first, !addonOnlyKeys.isEmpty {
            for addonKey in addonOnlyKeys {
                if let addonGroup = groups.removeValue(forKey: addonKey) {
                    groups[mainKey]?.items.append(contentsOf: addonGroup.items)
                }
            }
        }
        
        var games: [SelectableGame] = []
        for (k, val) in groups {
            let sortedItems = val.items.sorted { a, b in
                let scoreA = (a.type == .base || a.type == .switch2Dump ? 0 : (a.type == .update ? 1 : 2))
                let scoreB = (b.type == .base || b.type == .switch2Dump ? 0 : (b.type == .update ? 1 : 2))
                if scoreA != scoreB { return scoreA < scoreB }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
            
            let baseItemTitle = sortedItems.first(where: { $0.type == .base || $0.type == .switch2Dump }).map { cleanGameTitle($0.name) }
            let resolvedTitle = (baseItemTitle?.isEmpty == false ? baseItemTitle! : val.title)
            let gameTitle = resolvedTitle.isEmpty ? (sortedItems.first?.name ?? "Unknown Game") : resolvedTitle
            games.append(SelectableGame(
                id: k,
                name: gameTitle,
                titleId: val.tid,
                files: sortedItems
            ))
        }
        
        return games.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    
    public func cleanGameTitle(_ filename: String) -> String {
        var name = (filename as NSString).deletingPathExtension
        name = name.replacingOccurrences(of: "\\[[^\\]]+\\]", with: "", options: .regularExpression)
        name = name.replacingOccurrences(of: "\\([^\\)]+\\)", with: "", options: .regularExpression)
        name = name.replacingOccurrences(of: "(?i)v[0-9]+(?:\\.[0-9]+)*", with: "", options: .regularExpression)
        name = name.replacingOccurrences(of: "(?i)\\b(update|dlc|base)\\b", with: "", options: .regularExpression)
        name = name.replacingOccurrences(of: "[_\\-+]+", with: " ", options: .regularExpression)
        return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
