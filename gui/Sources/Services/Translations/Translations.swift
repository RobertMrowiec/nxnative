import Foundation

public enum Translations {
    public static func dictionary(for language: AppLanguage) -> [String: String] {
        switch language {
        case .system:
            let resolved = AppLanguage.resolve()
            return dictionary(for: resolved)
        case .en:
            return baseEnglish
        case .ptBR:
            return baseEnglish
                .merging(portuguese) { _, new in new }
                .merging(controllerProfilePtBR) { _, new in new }
                .merging(wizardGamerPtBR) { _, new in new }
                .merging(portugueseAdditions) { _, new in new }
        case .ptPT:
            return baseEnglish
                .merging(portuguesePortugal) { _, new in new }
                .merging(controllerProfilePtPT) { _, new in new }
                .merging(wizardGamerPtBR) { _, new in new }
                .merging(portuguesePortugalAdditions) { _, new in new }
        case .es:
            return baseEnglish
                .merging(spanish) { _, new in new }
                .merging(spanishAdditions) { _, new in new }
        case .de:
            return baseEnglish
                .merging(german) { _, new in new }
                .merging(germanAdditions) { _, new in new }
        case .fr:
            return baseEnglish
                .merging(french) { _, new in new }
                .merging(frenchAdditions) { _, new in new }
        case .it:
            return baseEnglish
                .merging(italian) { _, new in new }
                .merging(italianAdditions) { _, new in new }
        case .ja:
            return baseEnglish
                .merging(japanese) { _, new in new }
                .merging(japaneseAdditions) { _, new in new }
        case .ko:
            return baseEnglish
                .merging(korean) { _, new in new }
                .merging(koreanAdditions) { _, new in new }
        case .pl:
            return baseEnglish
                .merging(polish) { _, new in new }
                .merging(polishAdditions) { _, new in new }
        case .ru:
            return baseEnglish
                .merging(russian) { _, new in new }
                .merging(russianAdditions) { _, new in new }
        case .sv:
            return baseEnglish
                .merging(swedish) { _, new in new }
                .merging(swedishAdditions) { _, new in new }
        case .zhHans:
            return baseEnglish
                .merging(chineseSimplified) { _, new in new }
                .merging(chineseSimplifiedAdditions) { _, new in new }
        case .zhHant:
            return baseEnglish
                .merging(chineseTraditional) { _, new in new }
                .merging(chineseTraditionalAdditions) { _, new in new }
        }
    }

    private static var baseEnglish: [String: String] {
        english
            .merging(controllerProfileEn) { _, new in new }
            .merging(wizardGamerEn) { _, new in new }
            .merging(englishAdditions) { _, new in new }
    }

    private static let wizardGamerEn: [String: String] = [
        "build.step_1_gamer": "Select Game",
        "build.step_2_gamer": "Where to Play",
        "build.step_3_gamer": "Ready to Play",
        "build.dropzone_gamer_title": "Drop your Switch game here",
        "build.dropzone_gamer_sub": "Supports .nsp, .xci, .zip files or folders",
        "build.platform_mac_title": "Mac (This Computer)",
        "build.platform_mac_desc": "Play directly on your Mac with controller or keyboard, high resolution, and up to 60 FPS.",
        "build.platform_ios_title": "iPhone & iPad",
        "build.platform_ios_desc": "Creates a package ready to install on your mobile device via AirDrop, AltStore, or TrollStore.",
        "build.celebration_title": "Game Ported Successfully!",
        "build.celebration_desc": "Your game is ready. Connect your controller and have fun!",
        "build.play_now": "Play Now",
        "build.show_in_finder": "Show in Finder",
        "build.view_in_library": "View in Library",
        "build.port_another": "Port Another Game",
        "build.dev_mode_title": "Developer Mode",
        "build.dev_mode_desc": "Enable advanced compilation options, live terminal drawer, and detailed system diagnostics.",
        "build.show_tech_logs": "Show technical details",
        "build.hide_tech_logs": "Hide technical details",
        "build.env_ready_pill": "Environment Ready",
        "build.game_ready_badge": "Ready for your Mac",
        "build.storage_clear_badge": "%@ available",
        "build.back_to_select": "Back to Selection",
        "build.port_game_now": "Port Game Now"
    ]

    private static let wizardGamerPtBR: [String: String] = [
        "build.step_1_gamer": "Escolher Jogo",
        "build.step_2_gamer": "Onde Jogar",
        "build.step_3_gamer": "Pronto para Jogar",
        "build.dropzone_gamer_title": "Arraste seu jogo do Switch aqui",
        "build.dropzone_gamer_sub": "Compatível com arquivos .nsp, .xci, .zip ou pastas",
        "build.platform_mac_title": "Mac (Este Computador)",
        "build.platform_mac_desc": "Jogue diretamente no seu Mac com controle ou teclado, alta resolução e até 60 FPS.",
        "build.platform_ios_title": "iPhone e iPad",
        "build.platform_ios_desc": "Cria o pacote pronto para instalar no seu aparelho via AirDrop, AltStore ou TrollStore.",
        "build.celebration_title": "Jogo Portado com Sucesso!",
        "build.celebration_desc": "Seu jogo já está pronto para rodar. Conecte seu controle e aproveite!",
        "build.play_now": "Jogar Agora",
        "build.show_in_finder": "Mostrar no Finder",
        "build.view_in_library": "Ver na Biblioteca",
        "build.port_another": "Portar Outro Jogo",
        "build.dev_mode_title": "Modo Desenvolvedor",
        "build.dev_mode_desc": "Habilita opções avançadas de compilação, terminal ao vivo e diagnósticos detalhados.",
        "build.show_tech_logs": "Ver detalhes técnicos",
        "build.hide_tech_logs": "Ocultar detalhes técnicos",
        "build.env_ready_pill": "Ambiente Pronto",
        "build.game_ready_badge": "Pronto para o seu Mac",
        "build.storage_clear_badge": "%@ disponíveis",
        "build.back_to_select": "Voltar à Seleção",
        "build.port_game_now": "Portar Jogo Agora"
    ]

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
