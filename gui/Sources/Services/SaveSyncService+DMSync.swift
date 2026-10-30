import Foundation
import CryptoKit
import Darwin

// Writes <iCloud>/nxnative_launcher/<TITLE_ID>/save.dmsync in the format of dm/host/save_sync.c, so the
// iPhone app (which reads <picked folder>/<TITLE_ID>/save.dmsync) gets the Mac save without the Mac game having run.
// The hash covers each entry's first 16 header bytes, path, guest name and contents, walked in byte order; it must
// match save_sync.c exactly or the iPhone treats the file as damaged.
extension SaveSyncService {

    /// iCloud Drive folder the iPhone picks; the game's file is `<root>/<TITLE_ID>/save.dmsync`.
    /// Real directories only: iCloud Drive does not sync symlinks.
    public func dmsyncFileURL(titleId: String) -> URL {
        iCloudRootURL
            .appendingPathComponent(titleId.uppercased(), isDirectory: true)
            .appendingPathComponent("save.dmsync")
    }

    @discardableResult
    public func writeDMSync(for game: PortedGame) -> Result<Int, Error> {
        guard let titleId = game.titleId, !titleId.isEmpty else {
            return .failure(Self.dmsyncError("Title ID unknown for this game"))
        }
        guard isICloudDriveAvailable else {
            return .failure(Self.dmsyncError("iCloud Drive is not available on this Mac"))
        }
        let save = resolvedSaveDirectory(forTitleId: titleId)
        let device = URL(fileURLWithPath: save.path + "_device")
        normalizeBackslashSaveFiles(in: save)
        normalizeBackslashSaveFiles(in: device)
        let dest = dmsyncFileURL(titleId: titleId)

        var entries: [(rel: String, abs: String, isFile: Bool, size: UInt64, mtime: Int64)] = []
        var files = 0
        var newest: Int64 = 0
        for (i, dir) in [save, device].enumerated() {
            guard hasEntries(dir.path) else { continue }
            collect(dir.path, rel: i == 0 ? "save" : "save_device", into: &entries)
        }
        for e in entries where e.isFile { files += 1; newest = max(newest, e.mtime) }
        guard files > 0 else { return .success(0) }

        do {
            try fileManager.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            var sha = SHA256()
            var body = Data()
            for e in entries {
                let guest = Self.guestName(e.abs)
                var h = Data(count: 24)
                h[0] = e.isFile ? 2 : 1
                Self.put(&h, 2, UInt16(e.rel.utf8.count))
                Self.put(&h, 4, UInt16(guest.count))
                Self.put(&h, 8, e.isFile ? e.size : 0)
                Self.put(&h, 16, e.mtime)
                sha.update(data: h.prefix(16))
                sha.update(data: Data(e.rel.utf8))
                sha.update(data: guest)
                body.append(h); body.append(Data(e.rel.utf8)); body.append(guest)
                if e.isFile {
                    let content = try Data(contentsOf: URL(fileURLWithPath: e.abs))
                    guard UInt64(content.count) == e.size else { throw Self.dmsyncError("\(e.rel) changed while packing") }
                    sha.update(data: content)
                    body.append(content)
                }
            }
            let hash = Data(sha.finalize().prefix(16)).map { String(format: "%02x", $0) }.joined()

            var hdr = Data(count: 144)
            hdr.replaceSubrange(0..<8, with: Data("DMSYNC1\n".utf8))
            Self.put(&hdr, 8, UInt32(1))
            Self.put(&hdr, 12, UInt32(entries.count))
            hdr.replaceSubrange(16..<48, with: Data(hash.utf8))
            Self.put(&hdr, 48, newest)
            hdr.replaceSubrange(56..<(56 + min(23, titleId.count)), with: Data(titleId.uppercased().utf8.prefix(23)))
            hdr.replaceSubrange(80..<(80 + "Mac".count), with: Data("Mac".utf8))
            let out = hdr + body + Data("DMSYNCE\n".utf8)

            // Written under a .nosync name first so iCloud uploads one whole file, as save_sync.c does.
            let part = dest.deletingLastPathComponent().appendingPathComponent("save.dmsync.\(getpid()).nosync")
            try? fileManager.removeItem(at: part)
            try out.write(to: part)
            if fileManager.fileExists(atPath: dest.path) {
                _ = try fileManager.replaceItemAt(dest, withItemAt: part)
            } else {
                try fileManager.moveItem(at: part, to: dest)
            }
            return .success(files)
        } catch {
            return .failure(error)
        }
    }

    // MARK: - helpers

    /// Migrates legacy save files created before `fwd_slashes` in `hle_fs.c` (e.g. `\savedata0.bin` -> `savedata0.bin`).
    public func normalizeBackslashSaveFiles(in directory: URL) {
        guard let items = try? fileManager.contentsOfDirectory(atPath: directory.path) else { return }
        for item in items where item != ".DS_Store" {
            let fullURL = directory.appendingPathComponent(item)
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: fullURL.path, isDirectory: &isDir) else { continue }
            if isDir.boolValue {
                normalizeBackslashSaveFiles(in: fullURL)
                continue
            }
            guard item.contains("\\") else { continue }
            let cleanRelative = item.replacingOccurrences(of: "\\", with: "/")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard !cleanRelative.isEmpty && cleanRelative != item else { continue }
            let cleanURL = directory.appendingPathComponent(cleanRelative)
            try? fileManager.createDirectory(at: cleanURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !fileManager.fileExists(atPath: cleanURL.path) {
                try? fileManager.moveItem(at: fullURL, to: cleanURL)
            } else {
                // If both exist, keep whichever has a newer modification date (or if the backslash file was just copied in)
                let srcDate = (try? fileManager.attributesOfItem(atPath: fullURL.path)[.modificationDate] as? Date) ?? .distantPast
                let dstDate = (try? fileManager.attributesOfItem(atPath: cleanURL.path)[.modificationDate] as? Date) ?? .distantPast
                if srcDate > dstDate {
                    try? fileManager.removeItem(at: cleanURL)
                    try? fileManager.moveItem(at: fullURL, to: cleanURL)
                } else {
                    try? fileManager.removeItem(at: fullURL)
                }
            }
        }
    }

    private static func dmsyncError(_ msg: String) -> NSError {
        NSError(domain: "SaveSyncService", code: 500, userInfo: [NSLocalizedDescriptionKey: msg])
    }

    private static func put<T: FixedWidthInteger>(_ d: inout Data, _ at: Int, _ v: T) {
        var le = v.littleEndian
        withUnsafeBytes(of: &le) { d.replaceSubrange(at..<(at + MemoryLayout<T>.size), with: $0) }
    }

    private static func guestName(_ path: String) -> Data {
        let attr = "org.d2rmobile.guest-name"
        let n = getxattr(path, attr, nil, 0, 0, XATTR_NOFOLLOW)
        guard n > 0 else { return Data() }
        var buf = [UInt8](repeating: 0, count: n)
        let r = getxattr(path, attr, &buf, n, 0, XATTR_NOFOLLOW)
        return r > 0 ? Data(buf.prefix(r)) : Data()
    }

    private func hasEntries(_ dir: String) -> Bool {
        ((try? fileManager.contentsOfDirectory(atPath: dir)) ?? []).contains { $0 != ".DS_Store" }
    }

    /// Depth first, a folder before its contents, names in byte order, .DS_Store and links skipped (save_sync.c walk()).
    private func collect(_ abs: String, rel: String,
                         into out: inout [(rel: String, abs: String, isFile: Bool, size: UInt64, mtime: Int64)]) {
        let names = ((try? fileManager.contentsOfDirectory(atPath: abs)) ?? [])
            .sorted { Array($0.utf8).lexicographicallyPrecedes(Array($1.utf8)) }
        for name in names where name != ".DS_Store" {
            let a = abs + "/" + name, r = rel + "/" + name
            var st = stat()
            guard lstat(a, &st) == 0 else { continue }
            if (st.st_mode & S_IFMT) == S_IFDIR {
                out.append((r, a, false, 0, Int64(st.st_mtimespec.tv_sec)))
                collect(a, rel: r, into: &out)
            } else if (st.st_mode & S_IFMT) == S_IFREG {
                out.append((r, a, true, UInt64(st.st_size), Int64(st.st_mtimespec.tv_sec)))
            }
        }
    }
}
