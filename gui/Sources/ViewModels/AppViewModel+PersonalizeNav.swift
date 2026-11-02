import Foundation
import SwiftUI

extension AppViewModel {
    
    public func handlePersonalizeGamepadAction(_ action: GamepadAction) {
        // Quick Shortcuts
        if action == .secondaryAction { // X / Square -> Quick Toggle Liquid Glass
            SoundEffectService.shared.play(.click)
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                isLiquidGlassEnabled.toggle()
            }
            return
        }
        if action == .contextAction { // Y / Triangle -> Quick Cycle Appearance
            SoundEffectService.shared.play(.click)
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                liquidGlassAppearance = (liquidGlassAppearance == .liquid) ? .frosted : .liquid
            }
            return
        }
        
        // Level 1: Outer Card Selection Mode
        if !isInsidePersonalizeCard {
            switch action {
            case .navigateUp:
                SoundEffectService.shared.play(.focus)
                withAnimation(.easeInOut(duration: 0.16)) {
                    personalizeCardIndex = max(0, personalizeCardIndex - 1)
                }
            case .navigateDown:
                SoundEffectService.shared.play(.focus)
                withAnimation(.easeInOut(duration: 0.16)) {
                    personalizeCardIndex = min(4, personalizeCardIndex + 1)
                }
            case .confirm:
                SoundEffectService.shared.play(.click)
                handlePersonalizeOuterConfirm()
            default:
                break
            }
            return
        }
        
        // Level 2: Inside Card Mode
        if action == .cancel {
            SoundEffectService.shared.play(.click)
            withAnimation(.easeInOut(duration: 0.16)) {
                isInsidePersonalizeCard = false
            }
            return
        }
        
        switch personalizeCardIndex {
        case 1:
            handlePersonalizeLanguageAction(action)
        case 2:
            handlePersonalizeColorAndGlassAction(action)
        case 3:
            handlePersonalizeAppearanceAction(action)
        default:
            break
        }
    }
    
    private func handlePersonalizeOuterConfirm() {
        switch personalizeCardIndex {
        case 0: // Reset Defaults
            withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) {
                highlightTheme = .electricPurple
                iconAppearanceMode = .default
                SoundEffectService.shared.isSoundEnabled = true
                launcherLanguage = .system
                isLiquidGlassEnabled = true
                liquidGlassIntensity = 1.0
                liquidGlassAppearance = .liquid
            }
        case 4: // Sound Effects Toggle
            withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) {
                SoundEffectService.shared.isSoundEnabled.toggle()
            }
        default: // Cards 1, 2, 3: Enter Card
            withAnimation(.easeInOut(duration: 0.16)) {
                isInsidePersonalizeCard = true
            }
        }
    }
    
    // MARK: - Card 1: Launcher Language
    private func handlePersonalizeLanguageAction(_ action: GamepadAction) {
        let langs = AppLanguage.sortedForDisplay
        let count = langs.count
        switch action {
        case .navigateUp:
            SoundEffectService.shared.play(.focus)
            personalizeLangFocus = max(0, personalizeLangFocus - 3)
        case .navigateDown:
            SoundEffectService.shared.play(.focus)
            personalizeLangFocus = min(count - 1, personalizeLangFocus + 3)
        case .navigateLeft:
            SoundEffectService.shared.play(.focus)
            personalizeLangFocus = max(0, personalizeLangFocus - 1)
        case .navigateRight:
            SoundEffectService.shared.play(.focus)
            personalizeLangFocus = min(count - 1, personalizeLangFocus + 1)
        case .confirm:
            SoundEffectService.shared.play(.click)
            if personalizeLangFocus < count {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                    launcherLanguage = langs[personalizeLangFocus]
                }
            }
        default:
            break
        }
    }
    
    // MARK: - Card 2: Highlight Color & Liquid Glass
    private func handlePersonalizeColorAndGlassAction(_ action: GamepadAction) {
        let themes = LauncherHighlightTheme.allCases
        switch action {
        case .navigateUp:
            SoundEffectService.shared.play(.focus)
            if personalizeColorFocus >= 4 && personalizeColorFocus <= 7 {
                personalizeColorFocus -= 4
            } else if personalizeColorFocus == 8 {
                personalizeColorFocus = 4
            } else if personalizeColorFocus == 9 {
                personalizeColorFocus = 8
            }
        case .navigateDown:
            SoundEffectService.shared.play(.focus)
            if personalizeColorFocus <= 3 {
                personalizeColorFocus += 4
            } else if personalizeColorFocus <= 7 {
                personalizeColorFocus = 8
            } else if personalizeColorFocus == 8 {
                personalizeColorFocus = 9
            }
        case .navigateLeft:
            if personalizeColorFocus <= 7 {
                SoundEffectService.shared.play(.focus)
                personalizeColorFocus = max(0, personalizeColorFocus - 1)
            } else if personalizeColorFocus == 8 {
                SoundEffectService.shared.play(.click)
                liquidGlassIntensity = max(0.0, round((liquidGlassIntensity - 0.05) * 100) / 100)
            } else if personalizeColorFocus == 9 {
                SoundEffectService.shared.play(.click)
                isLiquidGlassEnabled.toggle()
            }
        case .navigateRight:
            if personalizeColorFocus <= 7 {
                SoundEffectService.shared.play(.focus)
                personalizeColorFocus = min(7, personalizeColorFocus + 1)
            } else if personalizeColorFocus == 8 {
                SoundEffectService.shared.play(.click)
                liquidGlassIntensity = min(1.0, round((liquidGlassIntensity + 0.05) * 100) / 100)
            } else if personalizeColorFocus == 9 {
                SoundEffectService.shared.play(.click)
                isLiquidGlassEnabled.toggle()
            }
        case .confirm:
            SoundEffectService.shared.play(.click)
            if personalizeColorFocus <= 7 {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                    highlightTheme = themes[personalizeColorFocus]
                }
            } else if personalizeColorFocus == 8 {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                    liquidGlassIntensity = (liquidGlassIntensity >= 0.5) ? 0.0 : 1.0
                }
            } else if personalizeColorFocus == 9 {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                    isLiquidGlassEnabled.toggle()
                }
            }
        default:
            break
        }
    }
    
    // MARK: - Card 3: System Appearance (App Icon & Menu Bar Icon)
    private func handlePersonalizeAppearanceAction(_ action: GamepadAction) {
        let iconModes = AppIconAppearanceMode.allCases
        let menuModes = MenuBarIconStyle.allCases
        
        switch action {
        case .navigateUp, .navigateDown:
            SoundEffectService.shared.play(.focus)
            // Toggle between Icon row (0) and Menu Bar row (1)
            // We use personalizeMenuBarFocus >= 0 to track section: 0 for icon, 1 for menubar
            if personalizeLangFocus == 0 {
                personalizeLangFocus = 1
            } else {
                personalizeLangFocus = 0
            }
        case .navigateLeft:
            SoundEffectService.shared.play(.focus)
            if personalizeLangFocus == 0 {
                personalizeIconFocus = (personalizeIconFocus - 1 + iconModes.count) % iconModes.count
            } else {
                personalizeMenuBarFocus = (personalizeMenuBarFocus - 1 + menuModes.count) % menuModes.count
            }
        case .navigateRight:
            SoundEffectService.shared.play(.focus)
            if personalizeLangFocus == 0 {
                personalizeIconFocus = (personalizeIconFocus + 1) % iconModes.count
            } else {
                personalizeMenuBarFocus = (personalizeMenuBarFocus + 1) % menuModes.count
            }
        case .confirm:
            SoundEffectService.shared.play(.click)
            if personalizeLangFocus == 0 {
                if personalizeIconFocus < iconModes.count {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                        iconAppearanceMode = iconModes[personalizeIconFocus]
                    }
                }
            } else {
                if personalizeMenuBarFocus < menuModes.count {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                        menuBarIconStyle = menuModes[personalizeMenuBarFocus]
                    }
                }
            }
        default:
            break
        }
    }
}
