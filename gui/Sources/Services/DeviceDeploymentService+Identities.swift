import Foundation
import AppKit

// MARK: - iOS Code Signing Identities & Xcode Teams Discovery
extension DeviceDeploymentService {
    internal func fetchSigningIdentities() -> [DeveloperSigningTeam] {
        var keychainOutput = ""
        let secProc = Process()
        let secPipe = Pipe()
        secProc.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        secProc.arguments = ["find-identity", "-p", "codesigning", "-v"]
        secProc.standardOutput = secPipe
        secProc.standardError = Pipe()

        let secSema = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .utility).async {
            if (try? secProc.run()) != nil {
                secProc.waitUntilExit()
            }
            secSema.signal()
        }
        if secSema.wait(timeout: .now() + 2.0) == .timedOut {
            secProc.terminate()
        } else {
            let data = secPipe.fileHandleForReading.readDataToEndOfFile()
            keychainOutput = String(decoding: data, as: UTF8.self)
        }

        var teams: [DeveloperSigningTeam] = []
        var seenTeamIDs = Set<String>()

        // 1. Read teams configured in Xcode accounts (~/Library/Preferences/com.apple.dt.Xcode.plist)
        let defProc = Process()
        let defPipe = Pipe()
        defProc.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        defProc.arguments = ["export", "com.apple.dt.Xcode", "-"]
        defProc.standardOutput = defPipe
        defProc.standardError = Pipe()

        let defSema = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .utility).async {
            if (try? defProc.run()) != nil {
                defProc.waitUntilExit()
            }
            defSema.signal()
        }
        if defSema.wait(timeout: .now() + 2.0) == .timedOut {
            defProc.terminate()
        } else {
            let data = defPipe.fileHandleForReading.readDataToEndOfFile()
            if let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
               let teamsDict = plist["IDEProvisioningTeamByIdentifier"] as? [String: Any] {
                for (_, list) in teamsDict {
                    guard let arr = list as? [[String: Any]] else { continue }
                    for item in arr {
                        guard let tid = item["teamID"] as? String, !tid.isEmpty else { continue }
                        if seenTeamIDs.contains(tid) { continue }
                        seenTeamIDs.insert(tid)
                        let tname = (item["teamName"] as? String) ?? tid
                        let ttype = item["teamType"] as? String
                        let isFree = (item["isFreeProvisioningTeam"] as? Bool) ?? (item["isFreeProvisioningTeam"] as? Int == 1)
                        let hasCert = keychainOutput.contains(tid) || keychainOutput.contains(tname)
                        teams.append(DeveloperSigningTeam(
                            id: tid,
                            name: tname,
                            teamType: ttype,
                            isFreeProvisioningTeam: isFree,
                            hasCertificateInKeychain: hasCert
                        ))
                    }
                }
            }
        }

        // 2. Parse all valid Keychain signing identities
        var validCertNames: [String] = []
        for line in keychainOutput.components(separatedBy: .newlines) {
            if line.contains("Apple Development:") || line.contains("iPhone Developer:") || line.contains("Apple Distribution:") || line.contains("iPhone Distribution:") || line.contains("iOS Development:") {
                let parts = line.components(separatedBy: "\"")
                if parts.count >= 2 {
                    validCertNames.append(parts[1])
                }
            }
        }

        // Link valid certificates to Xcode teams if applicable
        for i in 0..<teams.count {
            let tid = teams[i].id
            let tname = teams[i].name
            if let matchingCert = validCertNames.first(where: { $0.contains(tid) || $0.contains(tname) }) {
                teams[i] = DeveloperSigningTeam(
                    id: teams[i].id,
                    name: teams[i].name,
                    teamType: teams[i].teamType,
                    isFreeProvisioningTeam: teams[i].isFreeProvisioningTeam,
                    hasCertificateInKeychain: true,
                    signingIdentity: matchingCert
                )
            } else if let firstDev = validCertNames.first(where: { $0.contains("Development") || $0.contains("Developer") }) {
                teams[i] = DeveloperSigningTeam(
                    id: teams[i].id,
                    name: teams[i].name,
                    teamType: teams[i].teamType,
                    isFreeProvisioningTeam: teams[i].isFreeProvisioningTeam,
                    hasCertificateInKeychain: true,
                    signingIdentity: firstDev
                )
            }
        }

        // 3. Also incorporate any Keychain signing identities that weren't captured by Xcode team IDs
        for certName in validCertNames {
            let isAlreadyIncluded = teams.contains { t in
                t.signingIdentity == certName || certName.contains(t.id) || certName.contains(t.name)
            }
            if !isAlreadyIncluded {
                teams.append(DeveloperSigningTeam(
                    id: certName,
                    name: certName,
                    teamType: "Keychain",
                    isFreeProvisioningTeam: false,
                    hasCertificateInKeychain: true,
                    signingIdentity: certName
                ))
            }
        }

        return teams
    }
}
