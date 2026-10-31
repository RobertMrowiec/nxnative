import Foundation

public enum LibrarySortOption: String, CaseIterable, Identifiable {
    case lastPlayed = "Último jogado"
    case name = "Nome"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .lastPlayed: return "clock.arrow.circlepath"
        case .name: return "textformat.abc"
        }
    }
    
    public var translationKey: String {
        switch self {
        case .lastPlayed: return "library.sort_last_played"
        case .name: return "library.sort_name"
        }
    }
}
