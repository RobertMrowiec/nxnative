import Foundation

// MARK: - NxNative Hub Contracts & Storage Models

/// Specifies how an iOS game deployment is packaged and targeted.
public enum NxDeploymentTargetMode: String, CaseIterable, Codable, Identifiable {
    case standalone = "standalone"
    case consoleHub = "consoleHub"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .standalone, .consoleHub:
            return "NxN Launcher"
        }
    }

    public var subtitle: String {
        return "Todos os jogos dentro de um único launcher com ícone dark oficial."
    }
}

/// Represents an external or internal storage source for game RomFS data on iOS.
public enum NxHubStorageLocation: Codable, Equatable {
    case internalContainer
    case externalDrive(bookmarkData: Data, pathDisplay: String)

    public var isExternal: Bool {
        if case .externalDrive = self { return true }
        return false
    }
}

/// Launch and runtime options for games running inside the NxNative iOS Hub.
public struct NxHubGameSettings: Codable, Equatable {
    public var fpsTarget: Int
    public var dockedMode: Bool
    public var metalFxUpscaling: Bool
    public var renderScale: Double
    public var language: String
    public var memoryLimitIncreased: Bool

    public init(
        fpsTarget: Int = 60,
        dockedMode: Bool = false,
        metalFxUpscaling: Bool = true,
        renderScale: Double = 1.0,
        language: String = "en",
        memoryLimitIncreased: Bool = true
    ) {
        self.fpsTarget = fpsTarget
        self.dockedMode = dockedMode
        self.metalFxUpscaling = metalFxUpscaling
        self.renderScale = renderScale
        self.language = language
        self.memoryLimitIncreased = memoryLimitIncreased
    }
}

/// Metadata for a game registered inside the NxNative iOS Hub container.
public struct NxHubGameItem: Identifiable, Codable, Equatable {
    public let titleId: String
    public let name: String
    public let displayVersion: String
    public let romfsSize: Int64
    public let hasPatch: Bool
    public let hasDLC: Bool
    public let isSwitch2: Bool
    public var storageLocation: NxHubStorageLocation
    public var launchSettings: NxHubGameSettings
    public var lastPlayedDate: Date?
    public var hasSave: Bool
    public var saveLastModified: Date?
    public var iconBase64: String?

    public var id: String { titleId }

    public init(
        titleId: String,
        name: String,
        displayVersion: String = "1.0.0",
        romfsSize: Int64 = 0,
        hasPatch: Bool = false,
        hasDLC: Bool = false,
        isSwitch2: Bool = false,
        storageLocation: NxHubStorageLocation = .internalContainer,
        launchSettings: NxHubGameSettings = NxHubGameSettings(),
        lastPlayedDate: Date? = nil,
        hasSave: Bool = false,
        saveLastModified: Date? = nil,
        iconBase64: String? = nil
    ) {
        self.titleId = titleId
        self.name = name
        self.displayVersion = displayVersion
        self.romfsSize = romfsSize
        self.hasPatch = hasPatch
        self.hasDLC = hasDLC
        self.isSwitch2 = isSwitch2
        self.storageLocation = storageLocation
        self.launchSettings = launchSettings
        self.lastPlayedDate = lastPlayedDate
        self.hasSave = hasSave
        self.saveLastModified = saveLastModified
        self.iconBase64 = iconBase64
    }
}

/// Master library index stored inside Documents/hub_library.json on the iOS Hub container.
public struct NxHubLibraryManifest: Codable, Equatable {
    public var version: Int
    public var lastUpdated: Date
    public var activeGameTitleId: String?
    public var games: [NxHubGameItem]

    public init(
        version: Int = 1,
        lastUpdated: Date = Date(),
        activeGameTitleId: String? = nil,
        games: [NxHubGameItem] = []
    ) {
        self.version = version
        self.lastUpdated = lastUpdated
        self.activeGameTitleId = activeGameTitleId
        self.games = games
    }
}

/// State tracking for cloud save synchronization between Mac and iOS Hub.
public enum NxHubSaveSyncState: String, Codable, Equatable {
    case idle = "Up to Date"
    case syncing = "Syncing with iCloud..."
    case localNewer = "Mac Save Newer"
    case remoteNewer = "iOS Save Newer"
    case conflict = "Save Conflict Detected"
}
