import Foundation

public enum TargetPlatform: String, CaseIterable, Identifiable {
    case macApp = "mac-app"
    case ios = "ios"
    case nonSwitch = "non-switch"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .macApp:
            return L10n.t("build.platform_mac")
        case .ios:
            return L10n.t("build.platform_ios")
        case .nonSwitch:
            return "Mac Native"
        }
    }
    
    public var iconName: String {
        switch self {
        case .macApp:
            return "macbook.gen2"
        case .ios:
            return "iphone.gen3"
        case .nonSwitch:
            return "gamecontroller.fill"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .macApp:
            return "Double-clickable native macOS app for Apple Silicon."
        case .ios:
            return "Sideloadable IPA package for iPhone 15 Pro and iPad."
        case .nonSwitch:
            return "Standard macOS game or custom external application."
        }
    }
}
