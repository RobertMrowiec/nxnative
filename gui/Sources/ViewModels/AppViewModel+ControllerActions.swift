import Foundation
import SwiftUI
import AppKit

extension AppViewModel {
    public func executeFocusedHeroBarAction() {
        if let g = currentFocusedGame {
            switch heroActionFocusIndex {
            case 0:
                if g.isPlayableLocally {
                    launchGame(g)
                } else {
                    gameForSettingsSheet = g
                }
            case 1:
                gameForSettingsSheet = g
            case 2:
                gameForSettingsSheet = g
            case 3:
                NSWorkspace.shared.activateFileViewerSelecting([g.url])
            default:
                break
            }
        } else if let u = focusedUnportedGame ?? unportedGames.first {
            switch heroActionFocusIndex {
            case 0:
                selectedGame = u
                gameForPortModal = u
            case 1:
                if let base = u.baseFile {
                    NSWorkspace.shared.activateFileViewerSelecting([base.url])
                }
            default:
                break
            }
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
            if isFocusOnHeroBar {
                isFocusOnHeroBar = false
                SoundEffectService.shared.play(.click)
                return
            }
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
        DispatchQueue.main.async {
            if let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible }) {
                window.toggleFullScreen(nil)
                SoundEffectService.shared.play(.click)
            }
        }
    }
}
