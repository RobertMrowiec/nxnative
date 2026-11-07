import Foundation
import SwiftUI
import AppKit

extension AppViewModel {
    
    public var availableSettingsCategories: [SettingsCategory] {
        isDeveloperMode ? SettingsCategory.allCases : [.general, .updates, .toolchain]
    }
    
    private func maxFocusIndex(for category: SettingsCategory) -> Int {
        switch category {
        case .general:
            return 1
        case .updates:
            return 2
        case .toolchain:
            return 2
        case .developer:
            return 2
        }
    }
    
    public func handleSystemGamepadAction(_ action: GamepadAction) {
        switch action {
        case .navigateLeft:
            let cats = availableSettingsCategories
            if let idx = cats.firstIndex(of: activeSettingsCategory) {
                let prevIdx = (idx - 1 + cats.count) % cats.count
                SoundEffectService.shared.play(.tabSwitch)
                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                    activeSettingsCategory = cats[prevIdx]
                    settingsItemFocusIndex = 0
                }
            }
            
        case .navigateRight:
            let cats = availableSettingsCategories
            if let idx = cats.firstIndex(of: activeSettingsCategory) {
                let nextIdx = (idx + 1) % cats.count
                SoundEffectService.shared.play(.tabSwitch)
                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                    activeSettingsCategory = cats[nextIdx]
                    settingsItemFocusIndex = 0
                }
            }
            
        case .navigateUp:
            let maxCount = maxFocusIndex(for: activeSettingsCategory)
            if maxCount > 1 {
                SoundEffectService.shared.play(.focus)
                withAnimation(.easeInOut(duration: 0.15)) {
                    settingsItemFocusIndex = (settingsItemFocusIndex - 1 + maxCount) % maxCount
                }
            }
            
        case .navigateDown:
            let maxCount = maxFocusIndex(for: activeSettingsCategory)
            if maxCount > 1 {
                SoundEffectService.shared.play(.focus)
                withAnimation(.easeInOut(duration: 0.15)) {
                    settingsItemFocusIndex = (settingsItemFocusIndex + 1) % maxCount
                }
            }
            
        case .confirm:
            handleSystemConfirm()
            
        case .contextAction: // Y / △ -> Toggle Developer Mode
            SoundEffectService.shared.play(.click)
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                isDeveloperMode.toggle()
                if !isDeveloperMode && activeSettingsCategory == .developer {
                    activeSettingsCategory = .general
                    settingsItemFocusIndex = 0
                }
            }
            
        case .secondaryAction: // X / □ -> Quick Action / Updates
            SoundEffectService.shared.play(.click)
            if activeSettingsCategory == .toolchain {
                repairAllDependencies()
            } else {
                openUpdateCheckerAndAutoInstall()
            }
            
        default:
            break
        }
    }
    
    private func handleSystemConfirm() {
        SoundEffectService.shared.play(.click)
        
        switch activeSettingsCategory {
        case .general:
            selectGameFolder()
            
        case .updates:
            if settingsItemFocusIndex == 0 {
                checkForUpdates()
            } else {
                applyUpdate(autoRelaunch: true)
            }
            
        case .toolchain:
            if settingsItemFocusIndex == 0 {
                selectProdKeysFile()
            } else {
                if !prerequisites.allSatisfied {
                    installAllMissingDependencies()
                } else {
                    repairAllDependencies()
                }
            }
            
        case .developer:
            switch settingsItemFocusIndex {
            case 0: // Git Repository Sync
                openUpdateCheckerAndAutoInstall()
            case 1: // Diagnostics & Clean
                let logStrings = logs.map { "\($0.timestamp): \($0.message)" }
                _ = DiagnosticsService.shared.generateAndCopyReport(lastLogLines: logStrings)
            default:
                break
            }
        }
    }
}
