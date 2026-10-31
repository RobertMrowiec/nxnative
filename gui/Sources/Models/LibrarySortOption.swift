import Foundation

public enum LibrarySortOption: String, CaseIterable, Identifiable {
    case lastPlayed = "Último jogado"
    case name = "Nome"
    case ported = "Data de Port"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .lastPlayed: return "clock.arrow.circlepath"
        case .name: return "textformat.abc"
        case .ported: return "calendar.badge.clock"
        }
    }
    
    public var translationKey: String {
        switch self {
        case .lastPlayed: return "library.sort_last_played"
        case .name: return "library.sort_name"
        case .ported: return "library.sort_ported"
        }
    }
}
