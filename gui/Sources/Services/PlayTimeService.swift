import Foundation
import AppKit

public final class PlayTimeService: ObservableObject {
    public static let shared = PlayTimeService()
    
    private let userDefaultsKey = "nxnative_play_time_records"
    private let fileManager = FileManager.default
    
    @Published public private(set) var refreshId: UUID = UUID()
    private var inMemoryCache: [String: TimeInterval] = [:]
    
    private init() {
        if let stored = UserDefaults.standard.dictionary(forKey: userDefaultsKey) as? [String: Double] {
            self.inMemoryCache = stored
        }
    }
    
    // MARK: - Query Play Time
    public func totalPlayTime(for game: PortedGame) -> TimeInterval {
        let key = game.uniqueKey
        var total = inMemoryCache[key] ?? 0
        
        // 1. Check Ryujinx historical play time if titleId exists
        if let tid = game.titleId, !tid.isEmpty {
            if let ryujinxSec = readRyujinxPlayTime(titleId: tid), ryujinxSec > total {
                total = ryujinxSec
                inMemoryCache[key] = total
                persistLocalCache()
            }
        }
        
        // 2. Check iCloud play time if available
        if let cloudSec = readICloudPlayTime(for: game), cloudSec > total {
            total = cloudSec
            inMemoryCache[key] = total
            persistLocalCache()
        }
        
        return total
    }
    
    public func formattedPlayTime(for game: PortedGame) -> String {
        let seconds = totalPlayTime(for: game)
        return formatTimeInterval(seconds)
    }
    
    public func formatTimeInterval(_ seconds: TimeInterval) -> String {
        guard seconds >= 60 else {
            return "0 min"
        }
        
        let totalMinutes = Int(seconds / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(hours)h"
            }
        } else {
            return "\(minutes) min"
        }
    }
    
    // MARK: - Session Recording
    public func recordSession(for game: PortedGame, duration: TimeInterval) {
        guard duration > 5 else { return } // ignore accidental instant launches
        let key = game.uniqueKey
        let current = totalPlayTime(for: game)
        let updated = current + duration
        
        inMemoryCache[key] = updated
        persistLocalCache()
        
        // Asynchronously update iCloud playtime file if enabled
        writeICloudPlayTime(for: game, seconds: updated)
        
        DispatchQueue.main.async {
            self.refreshId = UUID()
            self.objectWillChange.send()
        }
    }
    
    private func persistLocalCache() {
        UserDefaults.standard.set(inMemoryCache, forKey: userDefaultsKey)
    }
    
    // MARK: - Ryujinx Import
    public func readRyujinxPlayTime(titleId: String) -> TimeInterval? {
        let tidLower = titleId.lowercased()
        let home = fileManager.homeDirectoryForCurrentUser
        let metadataURL = home
            .appendingPathComponent("Library/Application Support/Ryujinx/games", isDirectory: true)
            .appendingPathComponent(tidLower, isDirectory: true)
            .appendingPathComponent("gui/metadata.json")
        
        guard fileManager.fileExists(atPath: metadataURL.path),
              let data = try? Data(contentsOf: metadataURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let timespanStr = json["timespan_played"] as? String else {
            return nil
        }
        
        let seconds = Self.parseDotNetTimeSpan(timespanStr)
        return seconds > 0 ? seconds : nil
    }
    
    // MARK: - iCloud Integration
    public func readICloudPlayTime(for game: PortedGame) -> TimeInterval? {
        guard SaveSyncService.shared.isICloudDriveAvailable else { return nil }
        
        var candidateURLs: [URL] = []
        candidateURLs.append(SaveSyncService.shared.iCloudFolder(for: game).appendingPathComponent("playtime.json"))
        if let tid = game.titleId, !tid.isEmpty {
            candidateURLs.append(SaveSyncService.shared.iCloudRootURL.appendingPathComponent(tid.uppercased(), isDirectory: true).appendingPathComponent("playtime.json"))
        }
        
        for url in candidateURLs {
            if fileManager.fileExists(atPath: url.path),
               let data = try? Data(contentsOf: url),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let sec = json["totalSeconds"] as? Double {
                return sec
            }
        }
        return nil
    }
    
    public func writeICloudPlayTime(for game: PortedGame, seconds: TimeInterval) {
        guard SaveSyncService.shared.isICloudDriveAvailable else { return }
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let folder = SaveSyncService.shared.iCloudFolder(for: game)
            try? self.fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            
            let payload: [String: Any] = [
                "uniqueKey": game.uniqueKey,
                "titleId": game.titleId ?? "",
                "gameName": game.name,
                "totalSeconds": seconds,
                "lastUpdated": Date().timeIntervalSince1970
            ]
            
            if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]) {
                let fileURL = folder.appendingPathComponent("playtime.json")
                try? data.write(to: fileURL, options: .atomic)
                
                // Also duplicate under TITLE_ID directory if available
                if let tid = game.titleId, !tid.isEmpty {
                    let tidFolder = SaveSyncService.shared.iCloudRootURL.appendingPathComponent(tid.uppercased(), isDirectory: true)
                    try? self.fileManager.createDirectory(at: tidFolder, withIntermediateDirectories: true)
                    let tidFileURL = tidFolder.appendingPathComponent("playtime.json")
                    try? data.write(to: tidFileURL, options: .atomic)
                }
            }
        }
    }
    
    // MARK: - Helper TimeSpan Parser
    public static func parseDotNetTimeSpan(_ raw: String) -> TimeInterval {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        
        var days: Double = 0
        var timePart = trimmed
        
        // Handle "D.HH:MM:SS" or "D.HH:MM:SS.fff"
        if let dotIndex = timePart.firstIndex(of: ".") {
            let prefix = String(timePart[..<dotIndex])
            if let d = Double(prefix) {
                days = d
                timePart = String(timePart[timePart.index(after: dotIndex)...])
            }
        }
        
        // Strip fractional seconds if any
        if let fracDot = timePart.firstIndex(of: ".") {
            timePart = String(timePart[..<fracDot])
        }
        
        let components = timePart.split(separator: ":").compactMap { Double($0) }
        var seconds: Double = days * 86400
        if components.count == 3 {
            seconds += components[0] * 3600 + components[1] * 60 + components[2]
        } else if components.count == 2 {
            seconds += components[0] * 60 + components[1]
        }
        return seconds
    }
}
