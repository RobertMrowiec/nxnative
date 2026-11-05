import Foundation

public struct MetalToolchainInfo: Equatable {
    public let rawVersion: String
    public let shortVersion: String
    public let isAvailable: Bool
    public let isVerified: Bool
    
    public init(rawVersion: String, shortVersion: String, isAvailable: Bool, isVerified: Bool) {
        self.rawVersion = rawVersion
        self.shortVersion = shortVersion
        self.isAvailable = isAvailable
        self.isVerified = isVerified
    }
}

extension SystemDetector {
    /// Detects the active Xcode Metal compiler version and checks if it matches dmsh_chain.lock.
    public func detectMetalToolchain(nxnativePath: String) -> MetalToolchainInfo {
        let res = runQuickCommandWithTimeout("/usr/bin/xcrun", args: ["-sdk", "macosx", "metal", "--version"], timeoutSeconds: 2.0)
        guard res.success && !res.output.isEmpty else {
            return MetalToolchainInfo(rawVersion: "", shortVersion: "Metal Not Found", isAvailable: false, isVerified: false)
        }
        
        let firstLine = res.output.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !firstLine.isEmpty else {
            return MetalToolchainInfo(rawVersion: "", shortVersion: "Metal Not Found", isAvailable: false, isVerified: false)
        }
        
        // Extract clean short version: e.g. "Apple metal version 32023.922 (metalfe-32023.922.4)" -> "Metal v32023.922"
        let shortVersion: String
        if let verRange = firstLine.range(of: "version ") {
            let afterVer = firstLine[verRange.upperBound...]
            let verTokens = afterVer.split(separator: " ")
            if let verNum = verTokens.first {
                shortVersion = "Metal v\(verNum)"
            } else {
                shortVersion = "Metal (Detected)"
            }
        } else {
            shortVersion = "Metal (Detected)"
        }
        
        // Verify against dmsh_chain.lock if available
        var isVerified = false
        if !nxnativePath.isEmpty {
            let lockURL = URL(fileURLWithPath: nxnativePath).appendingPathComponent("dm/gfx/tools/dmsh_chain.lock")
            if let lockContent = try? String(contentsOf: lockURL, encoding: .utf8) {
                for line in lockContent.components(separatedBy: .newlines) {
                    if line.starts(with: "metal_macosx") {
                        let parts = line.split(separator: "\t", maxSplits: 1)
                        if parts.count == 2 {
                            let wantVer = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                            if firstLine == wantVer || firstLine.contains(wantVer) {
                                isVerified = true
                            }
                        }
                    }
                }
            }
        }
        
        return MetalToolchainInfo(rawVersion: firstLine, shortVersion: shortVersion, isAvailable: true, isVerified: isVerified)
    }
}
