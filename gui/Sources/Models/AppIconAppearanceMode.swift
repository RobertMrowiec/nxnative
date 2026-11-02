import Foundation
import AppKit

public enum AppIconAppearanceMode: String, CaseIterable, Identifiable, Hashable {
    case `default` = "Default"
    case dark = "Dark"
    case clearLight = "Clear Light"
    case clearDark = "Clear Dark"
    case tintedLight = "Tinted Light"
    case tintedDark = "Tinted Dark"
    case auto = "Auto (System)"
    
    public var id: String { rawValue }

    public var resourceName: String {
        switch self {
        case .default:
            return "AppIcon-Default"
        case .dark:
            return "AppIcon-Dark"
        case .clearLight:
            return "AppIcon-ClearLight"
        case .clearDark:
            return "AppIcon-ClearDark"
        case .tintedLight:
            return "AppIcon-TintedLight"
        case .tintedDark:
            return "AppIcon-TintedDark"
        case .auto:
            let isDark = NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? "AppIcon-Dark" : "AppIcon-Default"
        }
    }

    public static func from(saved: String?) -> AppIconAppearanceMode {
        guard let saved = saved else { return .default }
        if let mode = AppIconAppearanceMode(rawValue: saved) {
            return mode
        }
        switch saved {
        case "Light": return .default
        case "Dark": return .dark
        case "Clear Light", "ClearLight": return .clearLight
        case "Clear Dark", "ClearDark": return .clearDark
        case "Tinted Light", "TintedLight": return .tintedLight
        case "Tinted Dark", "TintedDark", "Monochrome", "Mono": return .tintedDark
        default: return .default
        }
    }
}

public enum AppIconCache {
    private static var cache: [String: NSImage] = [:]
    private static let lock = NSLock()

    public static func clear() {
        lock.lock()
        cache.removeAll()
        lock.unlock()
    }

    public static func image(named name: String) -> NSImage? {
        lock.lock()
        if let existing = cache[name] {
            lock.unlock()
            return existing
        }
        lock.unlock()

        var url = Bundle.main.url(forResource: name, withExtension: "png")
            ?? Bundle.main.url(forResource: name, withExtension: "icns")
            ?? Bundle.main.url(forResource: "AppIcon-Default", withExtension: "png")
            ?? Bundle.main.url(forResource: "AppIcon", withExtension: "png")
            ?? Bundle.main.url(forResource: "AppIcon", withExtension: "icns")

        if url == nil {
            let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            let candidates = [
                cwd.appendingPathComponent("gui/Resources/\(name).png"),
                cwd.appendingPathComponent("nxnative/gui/Resources/\(name).png"),
                cwd.appendingPathComponent("Resources/\(name).png"),
                cwd.appendingPathComponent("gui/Icons/\(name).png"),
                cwd.appendingPathComponent("nxnative/gui/Icons/\(name).png"),
                cwd.appendingPathComponent("NxNative_Launcher.app/Contents/Resources/\(name).png"),
                cwd.appendingPathComponent("nxnative/NxNative_Launcher.app/Contents/Resources/\(name).png"),
                cwd.appendingPathComponent("gui/Resources/AppIcon-Default.png"),
                cwd.appendingPathComponent("nxnative/gui/Resources/AppIcon-Default.png"),
                cwd.appendingPathComponent("gui/Resources/AppIcon.png"),
                cwd.appendingPathComponent("nxnative/gui/Resources/AppIcon.png")
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
