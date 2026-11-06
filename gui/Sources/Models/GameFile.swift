import Foundation

public enum GameFileType: String {
    case base = "Base Game"
    case update = "Update"
    case dlc = "DLC"
    case switch2Dump = "Switch 2 Dump"
    case unknown = "Switch File"
    
    public var iconName: String {
        switch self {
        case .base:
            return "gamecontroller.fill"
        case .update:
            return "arrow.triangle.2.circlepath.circle.fill"
        case .dlc:
            return "sparkles.rectangle.stack.fill"
        case .switch2Dump:
            return "sparkles.tv.fill"
        case .unknown:
            return "doc.fill"
        }
    }
}

public struct GameFileItem: Identifiable, Hashable {
    public let id = UUID()
    public let url: URL
    public let name: String
    public let sizeBytes: Int64
    public let type: GameFileType
    public let titleId: String?
    public let versionString: String?
    public let nupUpdateCount: Int
    public let nupDlcCount: Int
    
    public init(
        url: URL,
        name: String,
        sizeBytes: Int64,
        type: GameFileType,
        titleId: String?,
        versionString: String?,
        nupUpdateCount: Int = 0,
        nupDlcCount: Int = 0
    ) {
        self.url = url
        self.name = name
        self.sizeBytes = sizeBytes
        self.type = type
        self.titleId = titleId
        self.versionString = versionString
        self.nupUpdateCount = nupUpdateCount
        self.nupDlcCount = nupDlcCount
    }
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}
