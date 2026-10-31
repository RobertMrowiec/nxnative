import Foundation
import SwiftUI

extension AppViewModel {
    public func validPortModalIndices() -> [Int] {
        var indices = [0, 1] // Platform Mac / iOS
        if platform == .ios {
            indices.append(contentsOf: [2, 3]) // Deploy Now / Later
        }
        indices.append(4) // Advanced toggle
        if isPortAdvancedExpanded {
            indices.append(contentsOf: [5, 6, 7, 8, 9]) // RomFS and toggles
        }
        indices.append(contentsOf: [10, 11]) // Cancel / Start Port
        return indices
    }

    public func handlePortModalGamepadAction(_ action: GamepadAction) {
        guard gameForPortModal != nil else { return }
        switch action {
        case .navigateUp:
            navigatePortModalFocus(direction: -1)
        case .navigateDown:
            navigatePortModalFocus(direction: 1)
        case .navigateLeft:
            handlePortModalLeft()
        case .navigateRight:
            handlePortModalRight()
        case .confirm:
            handlePortModalConfirm()
        case .cancel:
            SoundEffectService.shared.play(.click)
            gameForPortModal = nil
        default:
            break
        }
    }

    public func handlePortModalKeyboardKey(_ key: String) {
        guard gameForPortModal != nil else { return }
        switch key {
        case "up":
            navigatePortModalFocus(direction: -1)
        case "down":
            navigatePortModalFocus(direction: 1)
        case "left":
            handlePortModalLeft()
        case "right":
            handlePortModalRight()
        case "return", "space":
            handlePortModalConfirm()
        case "escape":
            SoundEffectService.shared.play(.click)
            gameForPortModal = nil
        default:
            break
        }
    }

    private func navigatePortModalFocus(direction: Int) {
        let valid = validPortModalIndices()
        guard !valid.isEmpty else { return }
        SoundEffectService.shared.play(.focus)
        
        if let currentPos = valid.firstIndex(of: portModalFocusIndex) {
            let nextPos = (currentPos + direction + valid.count) % valid.count
            portModalFocusIndex = valid[nextPos]
        } else {
            portModalFocusIndex = valid.first ?? 0
        }
    }

    private func handlePortModalLeft() {
        SoundEffectService.shared.play(.click)
        withAnimation(.easeInOut(duration: 0.15)) {
            switch portModalFocusIndex {
            case 1:
                platform = .macApp
                portModalFocusIndex = 0
            case 3:
                autoDeployToDeviceOnFinish = true
                portModalFocusIndex = 2
            case 5:
                autoRomfsSplitLimitGB = max(2.0, autoRomfsSplitLimitGB - 1.0)
            case 11:
                portModalFocusIndex = 10
            default:
                break
            }
        }
    }

    private func handlePortModalRight() {
        SoundEffectService.shared.play(.click)
        withAnimation(.easeInOut(duration: 0.15)) {
            switch portModalFocusIndex {
            case 0:
                platform = .ios
                portModalFocusIndex = 1
            case 2:
                autoDeployToDeviceOnFinish = false
                portModalFocusIndex = 3
            case 5:
                autoRomfsSplitLimitGB = min(16.0, autoRomfsSplitLimitGB + 1.0)
            case 10:
                portModalFocusIndex = 11
            default:
                break
            }
        }
    }

    private func handlePortModalConfirm() {
        SoundEffectService.shared.play(.click)
        withAnimation(.easeInOut(duration: 0.15)) {
            switch portModalFocusIndex {
            case 0:
                platform = .macApp
            case 1:
                platform = .ios
            case 2:
                autoDeployToDeviceOnFinish = true
            case 3:
                autoDeployToDeviceOnFinish = false
            case 4:
                isPortAdvancedExpanded.toggle()
            case 5:
                if autoRomfsSplitLimitGB >= 16.0 {
                    autoRomfsSplitLimitGB = 2.0
                } else {
                    autoRomfsSplitLimitGB += 1.0
                }
            case 6:
                showFps.toggle()
            case 7:
                keepExtracted.toggle()
            case 8:
                allowOtherMetal.toggle()
            case 9:
                surveyOnly.toggle()
            case 10:
                gameForPortModal = nil
            case 11:
                if canStartBuild {
                    let targetGame = gameForPortModal
                    gameForPortModal = nil
                    if let targetGame = targetGame {
                        selectedGame = targetGame
                    }
                    startBuild()
                }
            default:
                break
            }
        }
    }
}
