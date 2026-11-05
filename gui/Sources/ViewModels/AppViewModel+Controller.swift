import Foundation
import SwiftUI
import AppKit

extension AppViewModel {
    public func setupControllerNavigation() {
        GameControllerService.shared.onAction = { [weak self] action in
            self?.handleGamepadAction(action)
        }
        GameControllerService.shared.onRightStickScroll = { [weak self] delta in
            self?.scrollActiveView(delta: delta)
        }
    }

    public func scrollActiveView(delta: CGFloat) {
        guard !isAnyModalPresented else { return }
        guard let window = NSApp.keyWindow, let contentView = window.contentView else { return }
        if let sv = findScrollableView(in: contentView) {
            let clipView = sv.contentView
            var origin = clipView.bounds.origin
            origin.y -= delta
            let maxHeight = max(0, (sv.documentView?.bounds.height ?? 0) - clipView.bounds.height)
            origin.y = max(0, min(origin.y, maxHeight))
            clipView.scroll(to: origin)
            sv.reflectScrolledClipView(clipView)
        }
    }

    private func findScrollableView(in view: NSView?) -> NSScrollView? {
        guard let root = view else { return nil }
        var queue: [NSView] = [root]
        while !queue.isEmpty {
            let current = queue.removeFirst()
            if let sv = current as? NSScrollView {
                if sv.hasVerticalScroller || (sv.documentView?.bounds.height ?? 0) > sv.bounds.height {
                    return sv
                }
            }
            queue.append(contentsOf: current.subviews)
        }
        return nil
    }
    
    public func handleGamepadAction(_ action: GamepadAction) {
        if isAnyModalPresented {
            if showControlsPlayerModal {
                handleControlsPlayerModalGamepadAction(action)
            } else if showControlsProfileModal {
                handleControlsProfileModalGamepadAction(action)
            } else if gameForSettingsSheet != nil {
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
        case .navigateLeft, .navigateRight, .navigateDown, .navigateUp, .confirm, .contextAction, .secondaryAction:
            if selectedTab == 2 {
                handleControlsGamepadAction(action)
            } else if selectedTab == 3 {
                handlePersonalizeGamepadAction(action)
            } else if selectedTab == 4 {
                handleSystemGamepadAction(action)
            } else {
                switch action {
                case .navigateLeft: handleNavigateLeft()
                case .navigateRight: handleNavigateRight()
                case .navigateDown: handleNavigateDown()
                case .navigateUp: handleNavigateUp()
                case .confirm: handleConfirm()
                case .contextAction: handleContextAction()
                case .secondaryAction: handleSecondaryAction()
                default: break
                }
            }
        case .cancel:
            if selectedTab == 2 && isInsideControlsCard {
                handleControlsGamepadAction(.cancel)
            } else if selectedTab == 3 && isInsidePersonalizeCard {
                handlePersonalizeGamepadAction(.cancel)
            } else {
                handleCancel()
            }
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
            if isFocusOnHeroBar {
                if heroActionFocusIndex > 0 {
                    heroActionFocusIndex -= 1
                    SoundEffectService.shared.play(.focus)
                }
            } else {
                handleLibraryNavigateLeft()
            }
        case 1:
            handleCompatibilityNavigateLeft()
        case 2:
            handleControlsGamepadAction(.navigateLeft)
        case 3:
            handlePersonalizeGamepadAction(.navigateLeft)
        case 4:
            handleSystemGamepadAction(.navigateLeft)
        default: break
        }
    }
    
    func handleNavigateRight() {
        switch selectedTab {
        case 0:
            if isFocusOnHeroBar {
                let maxIdx: Int
                if let g = currentFocusedGame {
                    maxIdx = g.platform == .macApp ? 1 : 3
                } else {
                    maxIdx = 1
                }
                if heroActionFocusIndex < maxIdx {
                    heroActionFocusIndex += 1
                    SoundEffectService.shared.play(.focus)
                }
            } else {
                handleLibraryNavigateRight()
            }
        case 1:
            handleCompatibilityNavigateRight()
        case 2:
            handleControlsGamepadAction(.navigateRight)
        case 3:
            handlePersonalizeGamepadAction(.navigateRight)
        case 4:
            handleSystemGamepadAction(.navigateRight)
        default: break
        }
    }
    
    func handleNavigateUp() {
        switch selectedTab {
        case 0:
            if isFocusOnHeroBar {
                return
            }
            handleLibraryNavigateUp()
        case 1:
            handleCompatibilityNavigateUp()
        case 2:
            handleControlsGamepadAction(.navigateUp)
        case 3:
            handlePersonalizeGamepadAction(.navigateUp)
        case 4:
            handleSystemGamepadAction(.navigateUp)
        default: break
        }
    }
    
    func handleNavigateDown() {
        switch selectedTab {
        case 0:
            if isFocusOnHeroBar {
                isFocusOnHeroBar = false
                SoundEffectService.shared.play(.focus)
            } else {
                handleLibraryNavigateDown()
            }
        case 1:
            handleCompatibilityNavigateDown()
        case 2:
            handleControlsGamepadAction(.navigateDown)
        case 3:
            handlePersonalizeGamepadAction(.navigateDown)
        case 4:
            handleSystemGamepadAction(.navigateDown)
        default: break
        }
    }
    
    func handleConfirm() {
        switch selectedTab {
        case 0:
            if isGameActionMenuPresented {
                SoundEffectService.shared.play(.click)
                executeFocusedGameAction()
            } else if isFocusOnHeroBar {
                SoundEffectService.shared.play(.click)
                executeFocusedHeroBarAction()
            } else {
                // Focus moves to Hero Bar! User clicks "Jogar" on Hero Bar to start game
                isFocusOnHeroBar = true
                heroActionFocusIndex = 0
                SoundEffectService.shared.play(.click)
            }
        case 1:
            handleCompatibilityConfirm()
        case 2:
            SoundEffectService.shared.play(.click)
            var prof = InputProfileManager.shared.activeProfile
            prof.swapFaceButtons()
            InputProfileManager.shared.updateProfile(prof)
        case 4:
            handleSystemGamepadAction(.confirm)
        default:
            SoundEffectService.shared.play(.click)
            break
        }
    }
}
