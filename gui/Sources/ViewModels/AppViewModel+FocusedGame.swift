import Foundation
import SwiftUI
import AppKit

extension AppViewModel {
    public var currentFocusedGame: PortedGame? {
        if activeGroupFilter == .all {
            let items = unifiedItems(for: libraryGames)
            if items.indices.contains(focusedUnifiedIndex) {
                if case .ported(let game) = items[focusedUnifiedIndex] {
                    return game
                }
            }
        }
        
        switch activeLibraryShelf {
        case .mac:
            let macs = switch1LibraryGames
            if !macs.isEmpty {
                let clamped = max(0, min(focusedMacIndex, macs.count - 1))
                return macs[clamped]
            }
            return switch2LibraryGames.first ?? iosLibraryGames.first
        case .switch2:
            let s2 = switch2LibraryGames
            if !s2.isEmpty {
                let clamped = max(0, min(focusedSwitch2Index, s2.count - 1))
                return s2[clamped]
            }
            return switch1LibraryGames.first ?? iosLibraryGames.first
        case .ios:
            let ioses = iosLibraryGames
            if !ioses.isEmpty {
                let clamped = max(0, min(focusedIosIndex, ioses.count - 1))
                return ioses[clamped]
            }
            return switch1LibraryGames.first ?? switch2LibraryGames.first
        case .nonSwitch:
            let nons = nonSwitchLibraryGames
            if !nons.isEmpty {
                let clamped = max(0, min(focusedNonSwitchIndex, nons.count - 1))
                return nons[clamped]
            }
            return switch1LibraryGames.first ?? switch2LibraryGames.first
        case .unportedSwitch:
            return nil
        }
    }

    public func executeFocusedGameAction() {
        guard let game = currentFocusedGame else { return }
        isGameActionMenuPresented = false
        switch gameActionFocusedIndex {
        case 0:
            if game.isPlayableLocally {
                launchGame(game)
            } else {
                gameForSettingsSheet = game
            }
        case 1:
            gameForSettingsSheet = game
        case 2:
            if game.platform == .ios {
                DeviceDeploymentService.shared.shareViaAirDrop(fileURL: game.url)
            } else {
                revealInFinder(url: game.url)
            }
        case 3:
            let profile = GameDetailsProfile.inspect(for: game)
            revealSaveFolder(profile.saveDirectory)
        case 4:
            if game.platform == .ios {
                revealInFinder(url: game.url)
            } else {
                let cover = GameCoverService.shared.coverImage(for: game)
                SaveSyncService.shared.revealCloudGameFolder(for: game, cover: cover)
            }
        case 5:
            gameToRemove = game
            showRemoveConfirm = true
        case 6:
            gameToTrash = game
            showTrashConfirm = true
        default:
            break
        }
    }
}
