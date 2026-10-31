import Foundation
import AppKit

public enum AppIconAppearanceMode: String, CaseIterable, Identifiable, Hashable {
    case light = "Light"
    case dark = "Dark"
    case mono = "Monochrome"
    case auto = "Auto (System)"
    
    public var id: String { rawValue }
}

public enum AppIconCache {
    private static var cache: [String: NSImage] = [:]
    private static let lock = NSLock()

    public static func image(named name: String) -> NSImage? {
        lock.lock()
        if let existing = cache[name] {
            lock.unlock()
            return existing
        }
        lock.unlock()

        var url = Bundle.main.url(forResource: name, withExtension: "png")
            ?? Bundle.main.url(forResource: name, withExtension: "icns")
            ?? Bundle.main.url(forResource: "AppIcon", withExtension: "png")
            ?? Bundle.main.url(forResource: "AppIcon", withExtension: "icns")

        if url == nil {
            let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            let candidates = [
                cwd.appendingPathComponent("gui/Resources/\(name).png"),
                cwd.appendingPathComponent("nxnative/gui/Resources/\(name).png"),
                cwd.appendingPathComponent("Resources/\(name).png"),
                cwd.appendingPathComponent("NxNative_Launcher.app/Contents/Resources/\(name).png"),
                cwd.appendingPathComponent("nxnative/NxNative_Launcher.app/Contents/Resources/\(name).png"),
                cwd.appendingPathComponent("gui/Resources/AppIcon-Light.png"),
                cwd.appendingPathComponent("nxnative/gui/Resources/AppIcon-Light.png")
            ]
            for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
                url = candidate
                break
            }
        }

        guard let targetURL = url, let img = NSImage(contentsOf: targetURL) else {
            return nil
        }

        lock.lock()
        cache[name] = img
        lock.unlock()
        return img
    }
}
