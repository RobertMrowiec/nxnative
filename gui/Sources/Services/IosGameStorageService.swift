import Foundation

// MARK: - iOS Hub Storage & iCloud Save Management Service

/// Indexes installed games inside the Hub container and coordinates external storage / iCloud saves.
public final class IosGameStorageService: ObservableObject {
    public static let shared = IosGameStorageService()

    @Published public var indexedGames: [NxHubGameItem] = []
    @Published public var selectedGame: NxHubGameItem? = nil
    @Published public var isScanning: Bool = false
    @Published public var saveSyncState: NxHubSaveSyncState = .idle
    @Published public var externalStorageURL: URL? = nil

    private let fileManager = FileManager.default

    private init() {
        self.loadExternalStorageBookmark()
    }

    /// Root container directory for all games stored inside the Hub.
    public var gamesDirectoryURL: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("Games")
    }

    /// Scans the Hub Documents directory for installed games.
    public func scanInstalledGames() {
        guard !isScanning else { return }
        isScanning = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var found: [NxHubGameItem] = []
            let dir = self.gamesDirectoryURL

            if self.fileManager.fileExists(atPath: dir.path),
               let items = try? self.fileManager.contentsOfDirectory(atPath: dir.path) {
                for item in items {
                    let gameDir = dir.appendingPathComponent(item)
                    let manifestURL = gameDir.appendingPathComponent("manifest.json")

                    if let data = try? Data(contentsOf: manifestURL),
                       let decoded = try? JSONDecoder().decode(NxHubGameItem.self, from: data) {
                        found.append(decoded)
                    } else if item.count == 16 {
                        // Fallback directory with title ID name
                        let fallback = NxHubGameItem(
                            titleId: item,
                            name: "Switch Game (\(item))",
                            displayVersion: "1.0.0"
                        )
                        found.append(fallback)
                    }
                }
            }

            DispatchQueue.main.async {
                self.indexedGames = found.sorted { $0.name < $1.name }
                if self.selectedGame == nil || !found.contains(where: { $0.titleId == self.selectedGame?.titleId }) {
                    self.selectedGame = found.first
                }
                self.isScanning = false
            }
        }
    }

    // MARK: - External Storage USB-C Mounting

    public func setExternalStorageURL(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        if let bookmark = try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(bookmark, forKey: "NXNative_HubExternalStorageBookmark")
            self.externalStorageURL = url
            self.scanInstalledGames()
        }
    }

    private func loadExternalStorageBookmark() {
        guard let bookmark = UserDefaults.standard.data(forKey: "NXNative_HubExternalStorageBookmark") else { return }
        var isStale = false
        if let resolved = try? URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale), !isStale {
            self.externalStorageURL = resolved
        }
    }

    // MARK: - iCloud Save Synchronization

    public func syncSavesWithICloud(for titleId: String, completion: @escaping (Bool) -> Void) {
        guard let containerURL = fileManager.url(forUbiquityContainerIdentifier: nil) else {
            completion(false)
            return
        }

        self.saveSyncState = .syncing

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let cloudSavesDir = containerURL.appendingPathComponent("Documents/Saves/\(titleId)")
            let localSavesDir = self.gamesDirectoryURL.appendingPathComponent("\(titleId)/save")

            try? self.fileManager.createDirectory(at: cloudSavesDir, withIntermediateDirectories: true)
            try? self.fileManager.createDirectory(at: localSavesDir, withIntermediateDirectories: true)

            // Safe bidirectional timestamp comparison
            let localDate = (try? self.fileManager.attributesOfItem(atPath: localSavesDir.path)[.modificationDate] as? Date) ?? .distantPast
            let cloudDate = (try? self.fileManager.attributesOfItem(atPath: cloudSavesDir.path)[.modificationDate] as? Date) ?? .distantPast

            if cloudDate > localDate {
                // Cloud is newer -> pull
                let files = (try? self.fileManager.contentsOfDirectory(atPath: cloudSavesDir.path)) ?? []
                for file in files {
                    let src = cloudSavesDir.appendingPathComponent(file)
                    let dst = localSavesDir.appendingPathComponent(file)
                    try? self.fileManager.removeItem(at: dst)
                    try? self.fileManager.copyItem(at: src, to: dst)
                }
            } else if localDate > cloudDate {
                // Local is newer -> push
                let files = (try? self.fileManager.contentsOfDirectory(atPath: localSavesDir.path)) ?? []
                for file in files {
                    let src = localSavesDir.appendingPathComponent(file)
                    let dst = cloudSavesDir.appendingPathComponent(file)
                    try? self.fileManager.removeItem(at: dst)
                    try? self.fileManager.copyItem(at: src, to: dst)
                }
            }

            DispatchQueue.main.async {
                self.saveSyncState = .idle
                completion(true)
            }
        }
    }
}
