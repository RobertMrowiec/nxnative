import Foundation
import SwiftUI

extension AppViewModel {
    
    public func handleControlsGamepadAction(_ action: GamepadAction) {
        // If listening for button remapping, only Cancel (B) interrupts it
        if controlsListeningButton != nil {
            if action == .cancel {
                controlsListeningButton = nil
                GameControllerService.shared.onRawElementPressed = nil
                GameControllerService.shared.onAction = nil
                SoundEffectService.shared.play(.click)
            }
            return
        }
        
        let pm = InputProfileManager.shared
        let currentProfile = pm.activeProfile
        
        // Context Action (Y / Triangle) -> Quick Rumble Test anytime in Controls tab
        if action == .contextAction {
            GameControllerService.shared.testRumble(
                strength: currentProfile.rumbleStrength,
                floorBoost: currentProfile.rumbleFloorBoost
            )
            return
        }
        
        // Level 1: Outer Card Selection Mode
        if !isInsideControlsCard {
            let maxCards = 4
            switch action {
            case .navigateUp:
                SoundEffectService.shared.play(.focus)
                withAnimation(.easeInOut(duration: 0.16)) {
                    controlsCardIndex = (controlsCardIndex - 1 + maxCards) % maxCards
                }
            case .navigateDown:
                SoundEffectService.shared.play(.focus)
                withAnimation(.easeInOut(duration: 0.16)) {
                    controlsCardIndex = (controlsCardIndex + 1) % maxCards
                }
            case .confirm:
                SoundEffectService.shared.play(.click)
                withAnimation(.easeInOut(duration: 0.16)) {
                    isInsideControlsCard = true
                }
            default:
                break
            }
            return
        }
        
        // Level 2: Inside Card Mode
        if action == .cancel {
            SoundEffectService.shared.play(.click)
            withAnimation(.easeInOut(duration: 0.16)) {
                isInsideControlsCard = false
            }
            return
        }
        
        switch controlsCardIndex {
        case 0:
            handleControlsHeaderAction(action)
        case 1:
            handleControlsMappingAction(action)
        case 2:
            handleControlsDeadzoneAction(action)
        case 3:
            handleControlsHapticsAction(action)
        default:
            break
        }
    }
    
    // MARK: - Card 0: Header & Profile Toolbar
    private func handleControlsHeaderAction(_ action: GamepadAction) {
        let pm = InputProfileManager.shared
        switch action {
        case .navigateLeft:
            SoundEffectService.shared.play(.focus)
            controlsHeaderFocus = (controlsHeaderFocus - 1 + 4) % 4
        case .navigateRight:
            SoundEffectService.shared.play(.focus)
            controlsHeaderFocus = (controlsHeaderFocus + 1) % 4
        case .confirm:
            SoundEffectService.shared.play(.click)
            switch controlsHeaderFocus {
            case 0: // Player Picker Modal
                controlsPlayerModalFocus = pm.activePlayerIndex
                showControlsPlayerModal = true
            case 1: // Profile Picker Modal
                if let idx = pm.profiles.firstIndex(where: { $0.id == pm.activeProfileId }) {
                    controlsProfileModalFocus = idx
                }
                showControlsProfileModal = true
            case 2: // Duplicate Profile
                let copy = pm.duplicateProfile(pm.activeProfile)
                pm.setProfile(copy, forPlayer: pm.activePlayerIndex)
            case 3: // Reset Defaults
                let reset = ControllerProfile.nintendoDefault
                pm.updateProfile(reset)
                pm.setProfile(reset, forPlayer: pm.activePlayerIndex)
            default:
                break
            }
        default:
            break
        }
    }
    
    // MARK: - Card 1: Interactive Button Mapping
    private func handleControlsMappingAction(_ action: GamepadAction) {
        switch action {
        case .navigateUp:
            SoundEffectService.shared.play(.focus)
            if controlsMappingFocus <= 8 {
                controlsMappingFocus = max(0, controlsMappingFocus - 1)
            } else if controlsMappingFocus == 9 {
                controlsMappingFocus = 0
            } else {
                controlsMappingFocus = max(10, controlsMappingFocus - 1)
            }
        case .navigateDown:
            SoundEffectService.shared.play(.focus)
            if controlsMappingFocus <= 8 {
                controlsMappingFocus = min(8, controlsMappingFocus + 1)
            } else if controlsMappingFocus == 9 {
                controlsMappingFocus = 8
            } else {
                controlsMappingFocus = min(18, controlsMappingFocus + 1)
            }
        case .navigateLeft:
            SoundEffectService.shared.play(.focus)
            if controlsMappingFocus >= 10 {
                controlsMappingFocus = 9 // go to Center Swap
            } else if controlsMappingFocus == 9 {
                controlsMappingFocus = 4 // middle of left column
            }
        case .navigateRight:
            SoundEffectService.shared.play(.focus)
            if controlsMappingFocus <= 8 {
                controlsMappingFocus = 9 // go to Center Swap
            } else if controlsMappingFocus == 9 {
                controlsMappingFocus = 14 // middle of right column
            }
        case .confirm:
            SoundEffectService.shared.play(.click)
            if controlsMappingFocus == 9 {
                var prof = InputProfileManager.shared.activeProfile
                prof.swapFaceButtons()
                InputProfileManager.shared.updateProfile(prof)
            } else {
                startRemappingForFocusedButton()
            }
        default:
            break
        }
    }
    
    private func startRemappingForFocusedButton() {
        let leftButtons: [SwitchButton] = [.zl, .l, .minus, .capture, .leftStickClick, .dpadUp, .dpadLeft, .dpadDown, .dpadRight]
        let rightButtons: [SwitchButton] = [.zr, .r, .plus, .home, .x, .y, .a, .b, .rightStickClick]
        
        let targetBtn: SwitchButton
        if controlsMappingFocus <= 8 {
            targetBtn = leftButtons[controlsMappingFocus]
        } else if controlsMappingFocus >= 10 && controlsMappingFocus <= 18 {
            targetBtn = rightButtons[controlsMappingFocus - 10]
        } else {
            return
        }
        
        controlsListeningButton = targetBtn
        
        GameControllerService.shared.onRawElementPressed = { [weak self] elem in
            guard let self = self, let target = self.controlsListeningButton else { return }
            DispatchQueue.main.async {
                var prof = InputProfileManager.shared.activeProfile
                prof.gamepadBindings.removeValue(forKey: elem)
                prof.gamepadBindings[elem] = target
                InputProfileManager.shared.updateProfile(prof)
                self.controlsListeningButton = nil
                GameControllerService.shared.onRawElementPressed = nil
                GameControllerService.shared.onAction = nil
                SoundEffectService.shared.play(.click)
            }
        }
    }
}
