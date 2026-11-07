import Foundation

public enum SettingsCategory: Int, CaseIterable, Identifiable {
    case general = 0
    case updates = 1
    case toolchain = 2
    case developer = 3

    public var id: Int { rawValue }

    public func title(viewModel: AppViewModel) -> String {
        switch self {
        case .general:
            return viewModel.tr("settings.cat_general")
        case .updates:
            return viewModel.tr("settings.cat_updates")
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
        case .updates:
            return "arrow.triangle.2.circlepath.circle.fill"
        case .toolchain:
            return "wrench.and.screwdriver.fill"
        case .developer:
            return "hammer.fill"
        }
    }
}
