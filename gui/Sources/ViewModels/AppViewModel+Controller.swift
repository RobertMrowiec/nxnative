import Foundation
import SwiftUI
import AppKit

extension AppViewModel {
    public func setupControllerNavigation() {
        GameControllerService.shared.onAction = { [weak self] action in
            self?.handleGamepadAction(action)
        }
    }
    
    public func handleGamepadAction(_ action: GamepadAction) {
        if isAnyModalPresented {
            if gameForSettingsSheet != nil {
                handleSettingsModalGamepadAction(action)
            } else if gameForPortModal != nil {
                handlePortModalGamepadAction(action)
            } else if isGameActionMenuPresented {
                switch action {
                case .navigateUp: handleLibraryNavigateUp()
                case .navigateDown: handleLibraryNavigateDown()
                case .confirm: handleConfirm()
                case .cancel: handleCancel()
                default: break
                }
            }
            return
        }
        
        let tabCount = isDeveloperMode ? 6 : 5
        switch action {
        case .tabPrevious:
            SoundEffectService.shared.play(.tabSwitch)
            selectedTab = (selectedTab - 1 + tabCount) % tabCount
        case .tabNext:
            SoundEffectService.shared.play(.tabSwitch)
            selectedTab = (selectedTab + 1) % tabCount
        case .navigateLeft: handleNavigateLeft()
        case .navigateRight: handleNavigateRight()
        case .navigateDown: handleNavigateDown()
        case .navigateUp: handleNavigateUp()
        case .confirm: handleConfirm()
        case .cancel: handleCancel()
        case .secondaryAction: handleSecondaryAction()
        case .contextAction: handleContextAction()
        case .menu:
            SoundEffectService.shared.play(.click)
            if selectedTab == 0, let game = currentFocusedGame {
                gameForSettingsSheet = game
            } else {
                selectedTab = 4 // Settings
            }
        case .options:
            handleOptionsAction()
        }
    }
    
    // MARK: - Navigation Handlers Across Tabs
    func handleNavigateLeft() {
        switch selectedTab {
        case 0:
            handleLibraryNavigateLeft()
        case 1:
            handleCompatibilityNavigateLeft()
        case 2:
            let profiles = InputProfileManager.shared.profiles
            if let idx = profiles.firstIndex(where: { $0.id == InputProfileManager.shared.activeProfileId }), idx > 0 {
                InputProfileManager.shared.activeProfileId = profiles[idx - 1].id
                SoundEffectService.shared.play(.focus)
            }
        case 3:
            let themes = LauncherHighlightTheme.allCases
            if let idx = themes.firstIndex(of: highlightTheme), idx > 0 {
                highlightTheme = themes[idx - 1]
                SoundEffectService.shared.play(.focus)
            }
        default: break
        }
    }
    
    func handleNavigateRight() {
        switch selectedTab {
        case 0:
            handleLibraryNavigateRight()
        case 1:
            handleCompatibilityNavigateRight()
        case 2:
            let profiles = InputProfileManager.shared.profiles
            if let idx = profiles.firstIndex(where: { $0.id == InputProfileManager.shared.activeProfileId }), idx < profiles.count - 1 {
                InputProfileManager.shared.activeProfileId = profiles[idx + 1].id
                SoundEffectService.shared.play(.focus)
            }
        case 3:
            let themes = LauncherHighlightTheme.allCases
            if let idx = themes.firstIndex(of: highlightTheme), idx < themes.count - 1 {
                highlightTheme = themes[idx + 1]
                SoundEffectService.shared.play(.focus)
            }
        default: break
        }
    }
    
    func handleNavigateUp() {
        switch selectedTab {
        case 0:
            handleLibraryNavigateUp()
        case 1:
            handleCompatibilityNavigateUp()
        case 4:
            refreshPrerequisites()
        default: break
        }
    }
    
    func handleNavigateDown() {
        switch selectedTab {
        case 0:
            handleLibraryNavigateDown()
        case 1:
            handleCompatibilityNavigateDown()
        default: break
        }
    }
    
    func handleConfirm() {
        switch selectedTab {
        case 0:
            if isGameActionMenuPresented {
                SoundEffectService.shared.play(.click)
                executeFocusedGameAction()
            } else if activeGroupFilter == .all {
                let items = unifiedItems(for: libraryGames)
                if focusedUnifiedIndex == items.count {
                    SoundEffectService.shared.play(.click)
                    selectAdditionalGameFolder()
                } else if items.indices.contains(focusedUnifiedIndex) {
                    let item = items[focusedUnifiedIndex]
                    switch item {
                    case .ported(let game):
                        if game.platform == .macApp || game.platform == .nonSwitch {
                            launchGame(game)
                        } else {
                            SoundEffectService.shared.play(.click)
                            gameForSettingsSheet = game
                        }
                    case .unported(let unported):
                        SoundEffectService.shared.play(.click)
                        selectedGame = unported
                        gameForPortModal = unported
                    }
                }
            } else if activeLibraryShelf == .unportedSwitch, let unported = focusedUnportedGame {
                if isBuilding && (buildingGameId == unported.id || selectedGame?.id == unported.id) {
                    SoundEffectService.shared.play(.click)
                    cancelBuild()
                } else {
                    SoundEffectService.shared.play(.click)
                    selectedGame = unported
                    gameForPortModal = unported
                }
            } else if let game = currentFocusedGame {
                if game.platform == .macApp || game.platform == .nonSwitch {
                    launchGame(game)
                } else {
                    SoundEffectService.shared.play(.click)
                    gameForSettingsSheet = game
                }
            } else if let unported = unportedGames.first {
                SoundEffectService.shared.play(.click)
                selectedGame = unported
                gameForPortModal = unported
            }
        case 1:
            handleCompatibilityConfirm()
        case 2:
            SoundEffectService.shared.play(.click)
            var prof = InputProfileManager.shared.activeProfile
            prof.swapFaceButtons()
            InputProfileManager.shared.updateProfile(prof)
        case 4:
            SoundEffectService.shared.play(.click)
            if !prerequisites.allSatisfied { showInstallerSheet = true }
        default:
            SoundEffectService.shared.play(.click)
            break
        }
    }
    
    func handleCancel() {
        if gameForSettingsSheet != nil {
            gameForSettingsSheet = nil
            SoundEffectService.shared.play(.click)
            return
        }
        switch selectedTab {
        case 0:
            if isGameActionMenuPresented {
                SoundEffectService.shared.play(.click)
                withAnimation(.easeInOut(duration: 0.18)) { isGameActionMenuPresented = false }
            } else if activeLibraryShelf == .unportedSwitch, let unported = focusedUnportedGame,
                      isBuilding && (buildingGameId == unported.id || selectedGame?.id == unported.id) {
                SoundEffectService.shared.play(.click)
                cancelBuild()
            } else if isFocusOnDeck {
                isFocusOnDeck = false
                SoundEffectService.shared.play(.click)
            }
        case 1:
            handleCompatibilityCancel()
        default:
            break
        }
    }
    
    func handleSecondaryAction() {
        switch selectedTab {
        case 0:
            if let game = currentFocusedGame { launchGame(game) }
        case 1:
            handleCompatibilitySecondaryAction()
        case 3:
            SoundEffectService.shared.play(.click)
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                isLiquidGlassEnabled.toggle()
            }
        case 5:
            let allText = logs.map { "\($0.timestamp) [\($0.level.rawValue.uppercased())] \($0.message)" }.joined(separator: "\n")
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(allText, forType: .string)
        default:
            break
        }
    }
    
    func handleContextAction() {
        switch selectedTab {
        case 0:
            if let game = currentFocusedGame {
                SoundEffectService.shared.play(.click)
                let profile = GameDetailsProfile.inspect(for: game)
                revealSaveFolder(profile.saveDirectory)
            }
        case 3:
            SoundEffectService.shared.play(.click)
            withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
                liquidGlassIntensity = (liquidGlassIntensity >= 0.5) ? 0.0 : 1.0
                if !isLiquidGlassEnabled {
                    isLiquidGlassEnabled = true
                }
            }
        case 5:
            SoundEffectService.shared.play(.click)
            logs.removeAll()
        default:
            break
        }
    }
    
    func handleOptionsAction() {
        if gameForSettingsSheet != nil {
            if let g = gameForSettingsSheet { saveRuntimeConfig(activeSettingsConfig, for: g) }
            gameForSettingsSheet = nil
            SoundEffectService.shared.play(.click)
            return
        }
        if selectedTab == 0 && currentFocusedGame != nil {
            SoundEffectService.shared.play(.click)
            withAnimation(.easeInOut(duration: 0.18)) {
                isGameActionMenuPresented.toggle()
                if isGameActionMenuPresented { gameActionFocusedIndex = 0 }
            }
        }
    }
}
