import Foundation

public enum SettingsCategory: Int, CaseIterable, Identifiable {
    case general = 0
    case toolchain = 1
    case developer = 2

    public var id: Int { rawValue }

    public func title(viewModel: AppViewModel) -> String {
        switch self {
        case .general:
            return viewModel.tr("settings.cat_general")
        case .toolchain:
            return viewModel.tr("settings.cat_toolchain")
        case .developer:
            return viewModel.tr("settings.cat_developer")
        }
    }

    public var iconName: String {
        switch self {
        case .general:
            return "folder.fill.badge.gearshape"
        case .toolchain:
            return "wrench.and.screwdriver.fill"
        case .developer:
            return "hammer.fill"
        }
    }
}
