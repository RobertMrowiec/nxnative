import Foundation
import AppKit

public enum MenuBarIconStyle: String, CaseIterable, Identifiable, Hashable, Codable {
    case matchAppIcon = "matchAppIcon" // Dynamically matches selected app icon (Default, Dark, Clear, Tinted)
    case symbol = "symbol"             // Minimalist white logo symbol without background
    case dark = "dark"                 // Dark squircle app icon
    case lightColor = "lightColor"     // Default light squircle app icon
    
    public var id: String { rawValue }
    
    public var isTemplate: Bool {
        switch self {
        case .symbol:
            return true
        case .matchAppIcon, .dark, .lightColor:
            return false
        }
    }
}
