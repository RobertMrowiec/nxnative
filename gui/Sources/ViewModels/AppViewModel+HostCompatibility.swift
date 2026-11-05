import Foundation

extension AppViewModel {
    /// Minimum host requirements of the Metal 4 backend (nxnative README: macOS 26.6+).
    static let requiredMacOSMajor = 26
    static let recommendedSDK = [26, 6]

    private static func parseVersion(_ s: String) -> [Int] {
        s.split(separator: ".").compactMap { Int($0) }
    }

    private static func isVersion(_ a: [Int], lessThan b: [Int]) -> Bool {
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x < y }
        }
        return false
    }

    public func detectSDKVersion() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var res = SystemDetector.shared.runQuickCommandWithTimeout("/usr/bin/xcrun", args: ["--sdk", "macosx", "--show-sdk-version"], timeoutSeconds: 6.0)
            if !res.success {
                let dev = "/Applications/Xcode.app/Contents/Developer"
                if FileManager.default.fileExists(atPath: dev) {
                    res = SystemDetector.shared.runQuickCommandWithTimeout("/usr/bin/env", args: ["DEVELOPER_DIR=\(dev)", "/usr/bin/xcrun", "--sdk", "macosx", "--show-sdk-version"], timeoutSeconds: 6.0)
                }
            }
            let ver = res.success ? res.output.trimmingCharacters(in: .whitespacesAndNewlines) : ""
            DispatchQueue.main.async { self?.macSDKVersion = ver.isEmpty ? nil : ver }
        }
    }

    /// Hard blocker: the Metal 4 backend cannot run on macOS < 26 regardless of --allow-other-metal.
    public var hostBlockingIssue: String? {
        let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        guard major < Self.requiredMacOSMajor else { return nil }
        return "Porting requires macOS 26 (Tahoe) or later and Xcode 26+: the engine uses Metal 4, which does not exist on macOS \(major). The --allow-other-metal option cannot work around this."
    }

    /// Non-blocking advisories shown in the port modal.
    public var hostAdvisories: [String] {
        var items: [String] = []
        if let sdk = macSDKVersion, Self.isVersion(Self.parseVersion(sdk), lessThan: Self.recommendedSDK) {
            items.append("Your macOS SDK is \(sdk), but the Mac host targets macOS 26.6. The final \"Mac app\" stage (pack_app.py) may fail. Update Xcode / macOS to 26.6 or later.")
        }
        let out = appOutputDirectory.path
        let home = NSHomeDirectory()
        if out.contains("/Library/Mobile Documents") || out.hasPrefix(home + "/Desktop") || out.hasPrefix(home + "/Documents") {
            items.append("The output folder is inside Desktop/Documents (iCloud-synced). Finder attributes can make code signing fail. Choose a folder outside iCloud.")
        }
        return items
    }
}
