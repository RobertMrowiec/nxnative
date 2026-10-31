import Foundation
import AppKit

public struct ParsedProvisioningProfile {
    public let fileURL: URL
    public let name: String
    public let uuid: String
    public let teamIdentifier: String
    public let applicationIdentifier: String
    public let provisionedDevices: [String]
    public let expirationDate: Date
    public let entitlements: [String: Any]

    public var isExpired: Bool {
        return expirationDate < Date()
    }

    public func provisions(deviceId: String) -> Bool {
        return provisionedDevices.contains(deviceId)
    }
}

// MARK: - Automated iOS Provisioning & Code Signing
extension DeviceDeploymentService {
    /// Scans standard Xcode and MobileDevice provisioning profile caches.
    internal func scanProvisioningProfiles() -> [ParsedProvisioningProfile] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let searchDirs = [
            "\(home)/Library/Developer/Xcode/UserData/Provisioning Profiles",
            "\(home)/Library/MobileDevice/Provisioning Profiles"
        ]

        var profiles: [ParsedProvisioningProfile] = []

        for dir in searchDirs {
            guard let items = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in items where item.hasSuffix(".mobileprovision") {
                let fileURL = URL(fileURLWithPath: dir).appendingPathComponent(item)
                if let parsed = parseProvisioningProfile(at: fileURL) {
                    profiles.append(parsed)
                }
            }
        }
        return profiles
    }

    /// Decodes a CMS-signed .mobileprovision file into a structured ParsedProvisioningProfile.
    internal func parseProvisioningProfile(at fileURL: URL) -> ParsedProvisioningProfile? {
        let proc = Process()
        let pipe = Pipe()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        proc.arguments = ["cms", "-D", "-i", fileURL.path]
        proc.standardOutput = pipe
        proc.standardError = Pipe()

        guard (try? proc.run()) != nil else { return nil }
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else { return nil }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }

        let name = (plist["Name"] as? String) ?? fileURL.deletingPathExtension().lastPathComponent
        let uuid = (plist["UUID"] as? String) ?? ""
        let teamIds = (plist["TeamIdentifier"] as? [String]) ?? []
        let teamId = teamIds.first ?? ""
        let devices = (plist["ProvisionedDevices"] as? [String]) ?? []
        let expDate = (plist["ExpirationDate"] as? Date) ?? Date.distantPast
        let entitlements = (plist["Entitlements"] as? [String: Any]) ?? [:]
        let appId = (entitlements["application-identifier"] as? String) ?? ""

        return ParsedProvisioningProfile(
            fileURL: fileURL,
            name: name,
            uuid: uuid,
            teamIdentifier: teamId,
            applicationIdentifier: appId,
            provisionedDevices: devices,
            expirationDate: expDate,
            entitlements: entitlements
        )
    }

    /// Finds an existing, valid provisioning profile that authorizes the target device.
    internal func findMatchingProfile(
        for device: ConnectedAppleDevice,
        teamId: String?,
        titleId: String?
    ) -> ParsedProvisioningProfile? {
        let profiles = scanProvisioningProfiles().filter { profile in
            !profile.isExpired && profile.provisions(deviceId: device.id)
        }

        // If teamId is specified, prioritize matching team
        let teamProfiles: [ParsedProvisioningProfile]
        if let tid = teamId, !tid.isEmpty {
            let matched = profiles.filter { $0.teamIdentifier == tid }
            teamProfiles = matched.isEmpty ? profiles : matched
        } else {
            teamProfiles = profiles
        }

        // Prefer one explicitly tailored to the titleId if available
        if let tid = titleId?.lowercased(), !tid.isEmpty {
            if let exact = teamProfiles.first(where: { $0.applicationIdentifier.lowercased().contains(tid) }) {
                return exact
            }
        }

        // Check for an unexpired wildcard profile (* or .* at the end)
        if let wildcard = teamProfiles.first(where: { $0.applicationIdentifier.hasSuffix("*") }) {
            return wildcard
        }

        // Never return an unrelated game's profile!
        // Returning another game's profile would cause iOS to treat this as an update to that other game and overwrite it.
        return nil
    }

    /// Triggers headless Xcode background provisioning with Apple Developer servers.
    internal func requestXcodeProvisioning(
        device: ConnectedAppleDevice,
        teamId: String,
        titleId: String,
        uniqueBundleId: String
    ) -> ParsedProvisioningProfile? {
        let fm = FileManager.default
        let detectorRoot = SystemDetector.shared.detectNxnativeDirectory().path
        let candidateProjects = [
            URL(fileURLWithPath: detectorRoot).appendingPathComponent("dm/ios/DmIOS.xcodeproj").path,
            "/Volumes/SSD FN501 PRO/Emulations/NativePort/nxnative/dm/ios/DmIOS.xcodeproj"
        ]

        guard let projectPath = candidateProjects.first(where: { fm.fileExists(atPath: $0) }) else {
            return nil
        }

        DispatchQueue.main.async {
            self.activeDeployment.statusMessage = L10n.t("settings_modal.auto_provisioning_status")
            self.activeDeployment.detailMessage = L10n.t("settings_modal.auto_provisioning_detail")
            self.activeDeployment.logLines.append("==> Requesting official iOS provisioning profile from Apple Developer for \(device.name)...")
            self.activeDeployment.logLines.append("==> Provisioning bundle identifier: \(uniqueBundleId)")
        }

        let proc = Process()
        let pipe = Pipe()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        proc.arguments = [
            "-project", projectPath,
            "-scheme", "DmIOS",
            "-destination", "id=\(device.id)",
            "DEVELOPMENT_TEAM=\(teamId)",
            "PRODUCT_BUNDLE_IDENTIFIER=\(uniqueBundleId)",
            "-allowProvisioningUpdates",
            "-allowProvisioningDeviceRegistration",
            "build"
        ]
        proc.standardOutput = pipe
        proc.standardError = pipe

        do {
            try proc.run()
            // Xcode communicates with Apple Developer servers and creates the profile within 3-5 seconds.
            // Monitor every second up to 25 seconds for the profile to appear in UserData.
            let startTime = Date()
            while proc.isRunning && Date().timeIntervalSince(startTime) < 25 {
                Thread.sleep(forTimeInterval: 1.0)
                if let found = self.findMatchingProfile(for: device, teamId: teamId, titleId: titleId) {
                    DispatchQueue.main.async {
                        self.activeDeployment.logLines.append("[OK] Provisioning profile generated and received: \(found.name)")
                    }
                    proc.terminate()
                    return found
                }
            }
            if proc.isRunning {
                proc.terminate()
            }
            proc.waitUntilExit()
        } catch {
            return nil
        }

        return findMatchingProfile(for: device, teamId: teamId, titleId: titleId)
    }

    /// Extracts the 16-hex character Nintendo Switch Title ID from the bundle or path.
    internal func extractTitleId(from appURL: URL) -> String? {
        if let bid = extractBundleIdentifier(from: appURL) {
            let tokens = bid.components(separatedBy: ".")
            for token in tokens {
                if token.count == 16 && token.allSatisfy({ $0.isHexDigit }) {
                    return token.uppercased()
                }
            }
        }

        let path = appURL.path
        let regex = try? NSRegularExpression(pattern: "(0100[0-9A-Fa-f]{12})", options: [])
        if let match = regex?.firstMatch(in: path, options: [], range: NSRange(location: 0, length: path.utf16.count)),
           let range = Range(match.range(at: 1), in: path) {
            return String(path[range]).uppercased()
        }
        return nil
    }

    /// Handles automated profile acquisition, bundle ID alignment, entitlements embedding, and code signing.
    internal func applyCodeSignatureAndProvisioning(
        targetAppURL: URL,
        device: ConnectedAppleDevice,
        team: DeveloperSigningTeam?
    ) {
        let chosenTeam = team ?? selectedSigningTeam
        let fm = FileManager.default
        let titleId = extractTitleId(from: targetAppURL) ?? "0100000000000000"

        // 1. Check custom user profile override
        var activeProfileURL: URL? = nil
        let customProfilePath = UserDefaults.standard.string(forKey: "NXNative_SavedCustomProvisioningProfilePath")
        if let provPath = customProfilePath, !provPath.isEmpty, fm.fileExists(atPath: provPath) {
            activeProfileURL = URL(fileURLWithPath: provPath)
            DispatchQueue.main.async {
                self.activeDeployment.logLines.append("==> Using custom provisioning profile: \(activeProfileURL!.lastPathComponent)")
            }
        }

        // 2. Search existing profile for this device & team
        let teamId = chosenTeam?.id ?? "5N354FBVNR"
        if activeProfileURL == nil {
            if let matched = findMatchingProfile(for: device, teamId: teamId, titleId: titleId) {
                activeProfileURL = matched.fileURL
                DispatchQueue.main.async {
                    self.activeDeployment.logLines.append("[OK] Matched existing provisioning profile for \(device.name): \(matched.name)")
                }
            }
        }

        // 3. Auto-generate profile via Xcode if missing
        if activeProfileURL == nil {
            let userName = NSUserName().lowercased().filter { $0.isLetter || $0.isNumber }
            let userPrefix = userName.isEmpty ? "developer" : userName
            let uniqueBundleId = "com.\(userPrefix).nxnative.\(titleId.lowercased())"

            if let generated = requestXcodeProvisioning(
                device: device,
                teamId: teamId,
                titleId: titleId,
                uniqueBundleId: uniqueBundleId
            ) {
                activeProfileURL = generated.fileURL
            }
        }

        // 4. Inject embedded.mobileprovision and align CFBundleIdentifier & Entitlements
        var tempEntitlementsURL: URL? = nil
        if let profileURL = activeProfileURL {
            let dest = targetAppURL.appendingPathComponent("embedded.mobileprovision")
            try? fm.removeItem(at: dest)
            try? fm.copyItem(at: profileURL, to: dest)

            if let parsed = parseProvisioningProfile(at: profileURL) {
                // Align bundle identifier in Info.plist to prevent iOS verification mismatch
                let appId = parsed.applicationIdentifier
                var alignedBundleId = appId
                if let dotIdx = appId.firstIndex(of: ".") {
                    alignedBundleId = String(appId[appId.index(after: dotIdx)...])
                }

                if !alignedBundleId.isEmpty && !alignedBundleId.contains("*") {
                    let infoPlistURL = targetAppURL.appendingPathComponent("Info.plist")
                    if var infoDict = try? PropertyListSerialization.propertyList(from: Data(contentsOf: infoPlistURL), options: .mutableContainers, format: nil) as? [String: Any] {
                        infoDict["CFBundleIdentifier"] = alignedBundleId
                        if let updatedData = try? PropertyListSerialization.data(fromPropertyList: infoDict, format: .xml, options: 0) {
                            try? updatedData.write(to: infoPlistURL)
                            DispatchQueue.main.async {
                                self.activeDeployment.logLines.append("==> Aligned bundle identifier: \(alignedBundleId)")
                            }
                        }
                    }
                }

                // Write extracted entitlements to a temporary plist
                if !parsed.entitlements.isEmpty {
                    let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("nxnative_entitlements_\(UUID().uuidString).plist")
                    if let entData = try? PropertyListSerialization.data(fromPropertyList: parsed.entitlements, format: .xml, options: 0) {
                        try? entData.write(to: tmpURL)
                        tempEntitlementsURL = tmpURL
                    }
                }
            }
        }

        // 5. Run codesign with entitlements
        let sign = Process()
        sign.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        var signArgs = ["--force", "--deep"]

        if let entURL = tempEntitlementsURL {
            signArgs.append(contentsOf: ["--entitlements", entURL.path])
        }

        let signingId = chosenTeam?.signingIdentity ?? (chosenTeam?.name.contains(":") == true ? chosenTeam?.name : nil)
        if let team = chosenTeam, team.hasCertificateInKeychain, let validIdentity = signingId {
            signArgs.append(contentsOf: ["--sign", validIdentity, targetAppURL.path])
            DispatchQueue.main.async {
                self.activeDeployment.logLines.append("==> Signing with development identity: \(validIdentity)")
            }
        } else if let team = chosenTeam, team.hasCertificateInKeychain {
            signArgs.append(contentsOf: ["--sign", team.name, targetAppURL.path])
            DispatchQueue.main.async {
                self.activeDeployment.logLines.append("==> Signing with identity: \(team.name)")
            }
        } else {
            signArgs.append(contentsOf: ["--sign", "-", targetAppURL.path])
            DispatchQueue.main.async {
                self.activeDeployment.logLines.append("==> Signing with ad-hoc identity...")
            }
        }

        sign.arguments = signArgs
        try? sign.run()
        sign.waitUntilExit()

        if let entURL = tempEntitlementsURL {
            try? fm.removeItem(at: entURL)
        }

        DispatchQueue.main.async {
            self.activeDeployment.logLines.append("[OK] Code signature applied successfully.")
        }
    }
}
