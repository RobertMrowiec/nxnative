import Foundation
import SwiftUI
import AppKit

extension AppViewModel {
    // MARK: - Gamepad Settings Modal Navigation
    public func handleSettingsModalGamepadAction(_ action: GamepadAction) {
        guard let game = gameForSettingsSheet else { return }
        let totalFocusCount = 10
        
        switch action {
        case .navigateUp:
            SoundEffectService.shared.play(.focus)
            withAnimation(.easeInOut(duration: 0.15)) {
                settingsModalFocusIndex = (settingsModalFocusIndex - 1 + totalFocusCount) % totalFocusCount
            }
            
        case .navigateDown:
            SoundEffectService.shared.play(.focus)
            withAnimation(.easeInOut(duration: 0.15)) {
                settingsModalFocusIndex = (settingsModalFocusIndex + 1) % totalFocusCount
            }
            
        case .navigateLeft:
            SoundEffectService.shared.play(.click)
            withAnimation(.easeInOut(duration: 0.15)) {
                switch settingsModalFocusIndex {
                case 0:
                    activeSettingsConfig.enable60FPS.toggle()
                case 1:
                    activeSettingsConfig.enableGameMode.toggle()
                case 2:
                    activeSettingsConfig.enableMetalHUD.toggle()
                case 3:
                    activeSettingsConfig.isDockedMode = false
                case 4:
                    let current = activeSettingsConfig.renderScale
                    let updated = max(0.50, round((current - 0.05) * 100) / 100)
                    activeSettingsConfig.renderScale = updated
                case 5:
                    activeSettingsConfig.enableMetalFXUpscale.toggle()
                case 6:
                    cycleGameControllerProfile(step: -1)
                case 7:
                    settingsModalFocusIndex = 9
                case 8:
                    settingsModalFocusIndex = 7
                case 9:
                    settingsModalFocusIndex = 8
                default:
                    break
                }
            }
            
        case .navigateRight:
            SoundEffectService.shared.play(.click)
            withAnimation(.easeInOut(duration: 0.15)) {
                switch settingsModalFocusIndex {
                case 0:
                    activeSettingsConfig.enable60FPS.toggle()
                case 1:
                    activeSettingsConfig.enableGameMode.toggle()
                case 2:
                    activeSettingsConfig.enableMetalHUD.toggle()
                case 3:
                    activeSettingsConfig.isDockedMode = true
                case 4:
                    let current = activeSettingsConfig.renderScale
                    let updated = min(1.00, round((current + 0.05) * 100) / 100)
                    activeSettingsConfig.renderScale = updated
                case 5:
                    activeSettingsConfig.enableMetalFXUpscale.toggle()
                case 6:
                    cycleGameControllerProfile(step: 1)
                case 7:
                    settingsModalFocusIndex = 8
                case 8:
                    settingsModalFocusIndex = 9
                case 9:
                    settingsModalFocusIndex = 7
                default:
                    break
                }
            }
            
        case .confirm:
            SoundEffectService.shared.play(.click)
            withAnimation(.easeInOut(duration: 0.15)) {
                switch settingsModalFocusIndex {
                case 0:
                    activeSettingsConfig.enable60FPS.toggle()
                case 1:
                    activeSettingsConfig.enableGameMode.toggle()
                case 2:
                    activeSettingsConfig.enableMetalHUD.toggle()
                case 3:
                    activeSettingsConfig.isDockedMode.toggle()
                case 4:
                    if activeSettingsConfig.renderScale < 0.70 {
                        activeSettingsConfig.renderScale = 0.75
                    } else if activeSettingsConfig.renderScale < 0.95 {
                        activeSettingsConfig.renderScale = 1.00
                    } else {
                        activeSettingsConfig.renderScale = 0.50
                    }
                case 5:
                    activeSettingsConfig.enableMetalFXUpscale.toggle()
                case 6:
                    cycleGameControllerProfile(step: 1)
                case 7:
                    activeSettingsConfig = GameRuntimeConfig()
                case 8:
                    gameForSettingsSheet = nil
                case 9:
                    saveRuntimeConfig(activeSettingsConfig, for: game)
                    gameForSettingsSheet = nil
                default:
                    break
                }
            }
            
        case .secondaryAction, .options:
            SoundEffectService.shared.play(.click)
            saveRuntimeConfig(activeSettingsConfig, for: game)
            gameForSettingsSheet = nil
            
        case .cancel:
            SoundEffectService.shared.play(.click)
            gameForSettingsSheet = nil
            
        case .contextAction:
            SoundEffectService.shared.play(.click)
            activeSettingsConfig = GameRuntimeConfig()
            
        default:
            break
        }
    }

    private func cycleGameControllerProfile(step: Int) {
        let profiles = InputProfileManager.shared.profiles
        let options: [String?] = [nil] + profiles.map { $0.id.uuidString }
        guard !options.isEmpty else { return }
        let currentIdx = options.firstIndex(where: { $0 == activeSettingsConfig.controllerProfileId }) ?? 0
        let nextIdx = (currentIdx + step + options.count) % options.count
        activeSettingsConfig.controllerProfileId = options[nextIdx]
    }
}
