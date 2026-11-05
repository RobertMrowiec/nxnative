import Foundation

public enum UnifiedLibraryItem: Identifiable, Hashable {
    case ported(PortedGame)
    case unported(SelectableGame)
    
    public var id: String {
        switch self {
        case .ported(let g): return "p_\(g.id.uuidString)"
        case .unported(let u): return "u_\(u.id)"
        }
    }
    
    public var name: String {
        switch self {
        case .ported(let g): return g.name
        case .unported(let u): return u.name
        }
    }
    
    public var path: String {
        switch self {
        case .ported(let g): return g.url.standardized.path
        case .unported(let u): return u.baseFile?.url.standardized.path ?? u.id
        }
    }

    /// Scan-stable identity for SwiftUI `ForEach` and `ScrollViewReader` so drag-reordering moves views instead of mutating slot state.
    public var stableId: String {
        switch self {
        case .ported(let g): return "ported_\(g.stableId)"
        case .unported(let u): return "unported_\(u.id)"
        }
    }
}
