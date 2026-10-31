import Foundation

public enum LibraryGroupFilter: String, CaseIterable, Identifiable {
    case categories = "Categorias"
    case all = "Todos"
    case mac = "Mac"
    case ios = "iPhone / iPad"
    case nonSwitch = "Non-Switch Games"
    case switchFiles = "Nintendo Switch Files"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .categories: return "rectangle.stack.fill"
        case .all: return "square.grid.2x2.fill"
        case .mac: return "laptopcomputer"
        case .ios: return "iphone.gen3"
        case .nonSwitch: return "gamecontroller.fill"
        case .switchFiles: return "shippingbox.fill"
        }
    }
    
    public var translationKey: String {
        switch self {
        case .categories: return "library.filter_categories"
        case .all: return "library.filter_all"
        case .mac: return "library.filter_mac"
        case .ios: return "library.filter_ios"
        case .nonSwitch: return "library.filter_non_switch"
        case .switchFiles: return "library.filter_switch_files"
        }
    }
}
