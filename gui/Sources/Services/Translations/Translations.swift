import Foundation

public enum Translations {
    public static func dictionary(for language: AppLanguage) -> [String: String] {
        switch language {
        case .system:
            let resolved = AppLanguage.resolve()
            return dictionary(for: resolved)
        case .en:
            return english.merging(controllerProfileEn) { _, new in new }
        case .ptBR:
            return portuguese.merging(controllerProfilePtBR) { _, new in new }
        case .ptPT:
            return portuguesePortugal.merging(controllerProfilePtPT) { _, new in new }
        case .es:
            return spanish
        case .ja:
            return japanese
        case .fr:
            return french
        case .de:
            return german
        case .it:
            return italian
        case .zhHans:
            return chineseSimplified
        case .zhHant:
            return chineseTraditional
        case .ko:
            return korean
        case .pl:
            return polish
        case .ru:
            return russian
        case .sv:
            return swedish
        }
    }

    private static let controllerProfileEn: [String: String] = [
        "settings_modal.controller_profile_title": "Controller Profile",
        "settings_modal.controller_profile_desc": "Choose a specific controller profile to always use for this game, or follow the global active profile.",
        "settings_modal.controller_profile_global": "Global Default (%@)"
    ]

    private static let controllerProfilePtBR: [String: String] = [
        "settings_modal.controller_profile_title": "Perfil de Controle",
        "settings_modal.controller_profile_desc": "Escolha qual perfil de controle criado utilizar sempre neste jogo em específico, ou siga o perfil global ativo.",
        "settings_modal.controller_profile_global": "Padrão Global (%@)"
    ]

    private static let controllerProfilePtPT: [String: String] = [
        "settings_modal.controller_profile_title": "Perfil de Comando",
        "settings_modal.controller_profile_desc": "Escolhe qual perfil de comando criado utilizar sempre neste jogo em específico, ou segue o perfil global ativo.",
        "settings_modal.controller_profile_global": "Padrão Global (%@)"
    ]
}
