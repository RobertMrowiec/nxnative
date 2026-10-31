import Foundation
import SwiftUI
import AppKit

extension AppViewModel {
    
    // MARK: - Global Keyboard Navigation Handler
    public func handleKeyboardKey(_ key: String) {
        // Modal Navigation: traps all keyboard navigation while any modal is opened
        if isAnyModalPresented {
            if gameForPortModal != nil {
                handlePortModalKeyboardKey(key)
            } else if isGameActionMenuPresented {
                switch key {
                case "up": handleLibraryNavigateUp()
                case "down": handleLibraryNavigateDown()
                case "return", "space": handleConfirm()
                case "escape": handleCancel()
                default: break
                }
            } else if showDeleteConfirm || showRemoveConfirm || showTrashConfirm || showUninstallConfirm {
                if key == "escape" {
                    showDeleteConfirm = false
                    showRemoveConfirm = false
                    showTrashConfirm = false
                    showUninstallConfirm = false
                }
            }
            return
        }

        // Navigation hotkeys guard: ensure hotkeys are enabled and no text input is active
        guard isNavigationHotkeysEnabled else { return }
        
        let tabCount = isDeveloperMode ? 6 : 5
        // Tab switching: Direct number keys
        if let num = Int(key), (1...tabCount).contains(num) {
            SoundEffectService.shared.play(.tabSwitch)
            selectedTab = num - 1
            return
        }
        
        // Tab cycling: Tab key, [ and ]
        if key == "tab" || key == "]" {
            SoundEffectService.shared.play(.tabSwitch)
            selectedTab = (selectedTab + 1) % tabCount
            return
        }
        if key == "shifttab" || key == "[" {
            SoundEffectService.shared.play(.tabSwitch)
            selectedTab = (selectedTab - 1 + tabCount) % tabCount
            return
        }
        
        switch key {
        case "left":
            handleNavigateLeft()
        case "right":
            handleNavigateRight()
        case "up":
            handleNavigateUp()
        case "down":
            handleNavigateDown()
        case "pageup":
            if selectedTab == 1 {
                handleCompatibilityPageUp()
            }
        case "pagedown":
            if selectedTab == 1 {
                handleCompatibilityPageDown()
            }
        case "home":
            if selectedTab == 1 {
                handleCompatibilityHome()
            }
        case "end":
            if selectedTab == 1 {
                handleCompatibilityEnd()
            }
        case "return":
            handleConfirm()
        case "escape":
            handleCancel()
        case "o":
            handleOptionsAction()
        case ",":
            if selectedTab == 0, let g = currentFocusedGame {
                SoundEffectService.shared.play(.click)
                gameForSettingsSheet = g
            }
        case "r":
            if selectedTab == 1 {
                loadCompatibleGames(forceRefresh: true)
            }
        case "c":
            if selectedTab == 5 {
                handleSecondaryAction()
            }
        case "k":
            if selectedTab == 5 {
                handleContextAction()
            }
        case "i":
            if selectedTab == 4 {
                showInstallerSheet = true
            }
        case "u":
            if selectedTab == 4 {
                checkForUpdates()
            }
        case "space":
            if selectedTab == 2 {
                var prof = InputProfileManager.shared.activeProfile
                prof.swapFaceButtons()
                InputProfileManager.shared.updateProfile(prof)
            }
        case "g":
            if selectedTab == 3 {
                handleSecondaryAction()
            }
        case "m":
            if selectedTab == 3 {
                handleContextAction()
            }
        default:
            break
        }
    }
}
