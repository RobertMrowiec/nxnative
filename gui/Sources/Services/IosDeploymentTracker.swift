import Foundation
import SwiftUI

public final class IosDeploymentTracker: ObservableObject {
    public static let shared = IosDeploymentTracker()
    
    private let prefix = "NXNative_IosDeployment_"
    
    @Published public var updateRevision: Int = 0
    
    private init() {}
    
    public func storageKey(for key: String) -> String {
        return prefix + key
    }
    
    public func deploymentRecord(for game: PortedGame) -> IosDeploymentRecord? {
        // 1. Try Title ID (exact unique Switch identifier)
        if let tid = game.titleId, !tid.isEmpty {
            if let record = deploymentRecord(forKey: tid) { return record }
            if let record = deploymentRecord(forKey: tid.uppercased()) { return record }
            if let record = deploymentRecord(forKey: tid.lowercased()) { return record }
        }
        
        // 2. Try uniqueKey
        if let record = deploymentRecord(forKey: game.uniqueKey) {
            return record
        }
        
        // 3. Try bundle identifier
        if let bid = game.bundleId, !bid.isEmpty {
            if let record = deploymentRecord(forKey: bid) { return record }
        }
        
        // 4. Try URL file name
        let fileName = game.url.deletingPathExtension().lastPathComponent
        if let record = deploymentRecord(forKey: fileName) {
            return record
        }
        
        // 5. Try Game Display Name
        if let record = deploymentRecord(forKey: game.name) {
            return record
        }
        
        // 6. Try Normalized Game Name
        let norm = Self.normalizeName(game.name)
        if !norm.isEmpty, let record = deploymentRecord(forKey: norm) {
            return record
        }
        
        return nil
    }
    
    public func deploymentRecord(forKey key: String) -> IosDeploymentRecord? {
        guard !key.isEmpty else { return nil }
        let storeKey = prefix + key
        guard let data = UserDefaults.standard.data(forKey: storeKey) else {
            return nil
        }
        return try? JSONDecoder().decode(IosDeploymentRecord.self, from: data)
    }
    
    public func isGameDeployed(_ game: PortedGame) -> Bool {
        return deploymentRecord(for: game) != nil
    }
    
    public func recordDeployment(
        for game: PortedGame,
        firstDate: Date? = nil,
        lastDate: Date = Date(),
        deviceName: String? = nil,
        deviceId: String? = nil,
        validityDays: Int = 7
    ) {
        let existing = deploymentRecord(for: game)
        let fDate = firstDate ?? existing?.firstDeployedDate ?? lastDate
        let record = IosDeploymentRecord(
            firstDeployedDate: fDate,
            lastDeployedDate: lastDate,
            targetDeviceName: deviceName ?? existing?.targetDeviceName,
            targetDeviceId: deviceId ?? existing?.targetDeviceId,
            validityDays: validityDays
        )
        
        saveRecord(record, for: game)
    }
    
    public func recordDeployment(
        forGameUrl url: URL,
        titleId: String? = nil,
        bundleId: String? = nil,
        gameName: String? = nil,
        deviceName: String? = nil,
        deviceId: String? = nil,
        validityDays: Int = 7
    ) {
        let fileName = url.deletingPathExtension().lastPathComponent
        let existing = (titleId.flatMap { deploymentRecord(forKey: $0) }) ??
                       deploymentRecord(forKey: fileName) ??
                       (gameName.flatMap { deploymentRecord(forKey: $0) })
        let now = Date()
        let record = IosDeploymentRecord(
            firstDeployedDate: existing?.firstDeployedDate ?? now,
            lastDeployedDate: now,
            targetDeviceName: deviceName ?? existing?.targetDeviceName,
            targetDeviceId: deviceId ?? existing?.targetDeviceId,
            validityDays: validityDays
        )
        
        var keysToSave: [String] = [fileName]
        if let tid = titleId, !tid.isEmpty {
            keysToSave.append(tid)
            keysToSave.append(tid.uppercased())
            keysToSave.append(tid.lowercased())
        }
        if let bid = bundleId, !bid.isEmpty {
            keysToSave.append(bid)
        }
        if let gn = gameName, !gn.isEmpty {
            keysToSave.append(gn)
            keysToSave.append(Self.normalizeName(gn))
        }
        
        if let data = try? JSONEncoder().encode(record) {
            for k in Set(keysToSave) {
                UserDefaults.standard.set(data, forKey: prefix + k)
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.updateRevision &+= 1
        }
    }
    
    public func recordDeployment(
        forKey key: String,
        deviceName: String? = nil,
        deviceId: String? = nil,
        validityDays: Int = 7
    ) {
        let existing = deploymentRecord(forKey: key)
        let now = Date()
        let record = IosDeploymentRecord(
            firstDeployedDate: existing?.firstDeployedDate ?? now,
            lastDeployedDate: now,
            targetDeviceName: deviceName ?? existing?.targetDeviceName,
            targetDeviceId: deviceId ?? existing?.targetDeviceId,
            validityDays: validityDays
        )
        
        if let data = try? JSONEncoder().encode(record) {
            UserDefaults.standard.set(data, forKey: prefix + key)
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.updateRevision &+= 1
        }
    }
    
    private func saveRecord(_ record: IosDeploymentRecord, for game: PortedGame) {
        var keys: [String] = [game.uniqueKey, game.name, game.url.deletingPathExtension().lastPathComponent]
        if let tid = game.titleId, !tid.isEmpty {
            keys.append(tid)
            keys.append(tid.uppercased())
            keys.append(tid.lowercased())
        }
        if let bid = game.bundleId, !bid.isEmpty {
            keys.append(bid)
        }
        let norm = Self.normalizeName(game.name)
        if !norm.isEmpty {
            keys.append(norm)
        }
        
        if let data = try? JSONEncoder().encode(record) {
            for k in Set(keys) {
                UserDefaults.standard.set(data, forKey: prefix + k)
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.updateRevision &+= 1
        }
    }
    
    public func markAsDeployedToday(for game: PortedGame, deviceName: String? = nil) {
        recordDeployment(for: game, firstDate: nil, lastDate: Date(), deviceName: deviceName, deviceId: nil, validityDays: 7)
    }
    
    public func clearDeployment(for game: PortedGame) {
        var keys: [String] = [game.uniqueKey, game.name, game.url.deletingPathExtension().lastPathComponent]
        if let tid = game.titleId, !tid.isEmpty {
            keys.append(tid)
            keys.append(tid.uppercased())
            keys.append(tid.lowercased())
        }
        if let bid = game.bundleId, !bid.isEmpty {
            keys.append(bid)
        }
        let norm = Self.normalizeName(game.name)
        if !norm.isEmpty {
            keys.append(norm)
        }
        
        for k in Set(keys) {
            UserDefaults.standard.removeObject(forKey: prefix + k)
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.updateRevision &+= 1
        }
    }
    
    // MARK: - Auto-Sync with Connected Device Apps
    public func syncFromDeviceApps(
        apps: [[String: Any]],
        libraryGames: [PortedGame],
        deviceName: String,
        deviceId: String
    ) {
        var updatedAny = false
        
        for app in apps {
            guard let bid = app["bundleIdentifier"] as? String else { continue }
            let name = app["name"] as? String ?? ""
            let bidLower = bid.lowercased()
            let normAppName = Self.normalizeName(name)
            
            // Match with a game in the library
            let matchedGame = libraryGames.first { game in
                // 1. Match Title ID in bundleIdentifier (e.g. com.rennancr.nxnative.0100f43008c44000)
                if let tid = game.titleId?.lowercased(), !tid.isEmpty, bidLower.contains(tid) {
                    return true
                }
                // 2. Match exact bundle identifier
                if let gameBid = game.bundleId?.lowercased(), !gameBid.isEmpty, gameBid == bidLower {
                    return true
                }
                // 3. Match normalized app name
                let normGameName = Self.normalizeName(game.name)
                if !normAppName.isEmpty && !normGameName.isEmpty && (normAppName == normGameName || normAppName.contains(normGameName) || normGameName.contains(normAppName)) {
                    return true
                }
                return false
            }
            
            if let game = matchedGame {
                let existing = deploymentRecord(for: game)
                if existing == nil {
                    // Initialize record based on game's modification date
                    let modDate = min(Date(), game.modificationDate)
                    let record = IosDeploymentRecord(
                        firstDeployedDate: modDate,
                        lastDeployedDate: modDate,
                        targetDeviceName: deviceName,
                        targetDeviceId: deviceId,
                        validityDays: 7
                    )
                    saveRecord(record, for: game)
                    updatedAny = true
                } else if existing?.targetDeviceName == nil {
                    // Update device name if missing
                    var updated = existing!
                    updated.targetDeviceName = deviceName
                    updated.targetDeviceId = deviceId
                    saveRecord(updated, for: game)
                    updatedAny = true
                }
            }
        }
        
        if updatedAny {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.updateRevision &+= 1
            }
        }
    }
    
    public static func normalizeName(_ name: String) -> String {
        return name.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }
}
