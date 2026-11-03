import Foundation

public enum SwitchGenerationFilter: String, CaseIterable, Identifiable, Hashable {
    case all = "All"
    case switch1 = "Switch 1"
    case switch2 = "Switch 2"

    public var id: String { rawValue }
}
