import Foundation
import SwiftUI
import AppKit

extension AppViewModel {
    
    // Focus Indices for Settings / System Tab (selectedTab == 4):
    // 0: Developer Mode Toggle
    // 1: Primary Action (Install All Tools / Check Updates)
    // 2: Open Games Directory Card
    // 3: Select Prod.keys File
    // 4: Repair Tools Action
    // 5: Git Repository Updates (Dev Mode)
    // 6: Storage & Diagnostics Clean (Dev Mode)
    // 7: Patches Verification & Application (Dev Mode)
    public static let settingsTotalFocusCount = 8
    
    public func handleSystemGamepadAction(_ action: GamepadAction) {
        let maxCount = isDeveloperMode ? Self.settingsTotalFocusCount : 5
        
        switch action {
        case .navigateUp:
            SoundEffectService.shared.play(.focus)
            withAnimation(.easeInOut(duration: 0.15)) {
                settingsFocusIndex = (settingsFocusIndex - 1 + maxCount) % maxCount
            }
            
        case .navigateDown:
            SoundEffectService.shared.play(.focus)
            withAnimation(.easeInOut(duration: 0.15)) {
                settingsFocusIndex = (settingsFocusIndex + 1) % maxCount
            }
            
        case .navigateLeft, .navigateRight:
            handleSystemAdjust()
            
        case .confirm:
            handleSystemConfirm()
            
        case .contextAction: // Y / △ -> Repair Tools
            SoundEffectService.shared.play(.click)
            repairAllDependencies()
            
        case .secondaryAction: // X / □ -> Check Updates
            SoundEffectService.shared.play(.click)
            openUpdateCheckerAndAutoInstall()
            
        default:
            break
        }
    }
    
    private func handleSystemAdjust() {
        switch settingsFocusIndex {
        case 0: // Toggle Developer Mode
            SoundEffectService.shared.play(.click)
            isDeveloperMode.toggle()
        default:
            break
        }
    }
    
    private func handleSystemConfirm() {
        switch settingsFocusIndex {
        case 0: // Developer Mode Toggle
            SoundEffectService.shared.play(.click)
            isDeveloperMode.toggle()
            
        case 1: // Primary Tool Action
            SoundEffectService.shared.play(.click)
            if !prerequisites.allSatisfied {
                showInstallerSheet = true
            } else {
                openUpdateCheckerAndAutoInstall()
            }
            
        case 2: // Open Games Directory
            SoundEffectService.shared.play(.click)
            selectGameFolder()
            
        case 3: // Select Prod.keys File
            SoundEffectService.shared.play(.click)
            selectProdKeysFile()
            
        case 4: // Repair Tools
            SoundEffectService.shared.play(.click)
            repairAllDependencies()
            
        case 5: // Git Repository Card
            SoundEffectService.shared.play(.click)
            openUpdateCheckerAndAutoInstall()
            
        case 6: // Diagnostics
            SoundEffectService.shared.play(.click)
            let logStrings = logs.map { "\($0.timestamp): \($0.message)" }
            _ = DiagnosticsService.shared.generateAndCopyReport(lastLogLines: logStrings)
            
        case 7: // Patches Verification & Application
            SoundEffectService.shared.play(.click)
            applyEnginePatches()
            
        default:
            break
        }
    }
}
