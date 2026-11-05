import Foundation
import AppKit

extension AppViewModel {
    // MARK: - Five-Row Shelf Directional Navigation
    public func handleLibraryNavigateLeft() {
        guard !isGameActionMenuPresented else { return }
        if activeGroupFilter == .all {
            handleUnifiedNavigateLeft(items: unifiedItems(for: libraryGames))
            return
        }
        switch activeLibraryShelf {
        case .mac:
            let macs = switch1LibraryGames
            guard !macs.isEmpty, focusedMacIndex > 0 else { return }
            focusedMacIndex -= 1
            syncFocusedGameIndex()
            SoundEffectService.shared.play(.focus)
        case .switch2:
            let s2 = switch2LibraryGames
            guard !s2.isEmpty, focusedSwitch2Index > 0 else { return }
            focusedSwitch2Index -= 1
            syncFocusedGameIndex()
            SoundEffectService.shared.play(.focus)
        case .ios:
            let ioses = iosLibraryGames
            guard !ioses.isEmpty, focusedIosIndex > 0 else { return }
            focusedIosIndex -= 1
            syncFocusedGameIndex()
            SoundEffectService.shared.play(.focus)
        case .nonSwitch:
            let nons = nonSwitchLibraryGames
            guard !nons.isEmpty, focusedNonSwitchIndex > 0 else { return }
            focusedNonSwitchIndex -= 1
            syncFocusedGameIndex()
            SoundEffectService.shared.play(.focus)
        case .unportedSwitch:
            let unporteds = unportedGames
            guard !unporteds.isEmpty, focusedUnportedGameIndex > 0 else { return }
            focusedUnportedGameIndex -= 1
            if !isBuilding { selectedGame = unporteds[focusedUnportedGameIndex] }
            SoundEffectService.shared.play(.focus)
        }
    }

    public func handleLibraryNavigateRight() {
        guard !isGameActionMenuPresented else { return }
        if activeGroupFilter == .all {
            handleUnifiedNavigateRight(items: unifiedItems(for: libraryGames))
            return
        }
        switch activeLibraryShelf {
        case .mac:
            let macs = switch1LibraryGames
            guard !macs.isEmpty, focusedMacIndex < macs.count - 1 else { return }
            focusedMacIndex += 1
            syncFocusedGameIndex()
            SoundEffectService.shared.play(.focus)
        case .switch2:
            let s2 = switch2LibraryGames
            guard !s2.isEmpty, focusedSwitch2Index < s2.count - 1 else { return }
            focusedSwitch2Index += 1
            syncFocusedGameIndex()
            SoundEffectService.shared.play(.focus)
        case .ios:
            let ioses = iosLibraryGames
            guard !ioses.isEmpty, focusedIosIndex < ioses.count - 1 else { return }
            focusedIosIndex += 1
            syncFocusedGameIndex()
            SoundEffectService.shared.play(.focus)
        case .nonSwitch:
            let nons = nonSwitchLibraryGames
            guard !nons.isEmpty, focusedNonSwitchIndex < nons.count - 1 else { return }
            focusedNonSwitchIndex += 1
            syncFocusedGameIndex()
            SoundEffectService.shared.play(.focus)
        case .unportedSwitch:
            let unporteds = unportedGames
            guard !unporteds.isEmpty, focusedUnportedGameIndex < unporteds.count - 1 else { return }
            focusedUnportedGameIndex += 1
            if !isBuilding { selectedGame = unporteds[focusedUnportedGameIndex] }
            SoundEffectService.shared.play(.focus)
        }
    }

    public func handleLibraryNavigateUp() {
        if isGameActionMenuPresented {
            if gameActionFocusedIndex > 0 {
                gameActionFocusedIndex -= 1
                SoundEffectService.shared.play(.focus)
            }
            return
        }
        if activeGroupFilter == .all {
            handleUnifiedNavigateUp(columns: max(1, unifiedGridColumnsCount), items: unifiedItems(for: libraryGames))
            return
        }

        let s1 = switch1LibraryGames
        let s2 = switch2LibraryGames
        let ioses = iosLibraryGames
        let nons = nonSwitchLibraryGames

        switch activeLibraryShelf {
        case .unportedSwitch:
            if !nons.isEmpty {
                activeLibraryShelf = .nonSwitch
                focusedNonSwitchIndex = min(focusedUnportedGameIndex, nons.count - 1)
            } else if !ioses.isEmpty {
                activeLibraryShelf = .ios
                focusedIosIndex = min(focusedUnportedGameIndex, ioses.count - 1)
            } else if !s2.isEmpty {
                activeLibraryShelf = .switch2
                focusedSwitch2Index = min(focusedUnportedGameIndex, s2.count - 1)
            } else if !s1.isEmpty {
                activeLibraryShelf = .mac
                focusedMacIndex = min(focusedUnportedGameIndex, s1.count - 1)
            } else { return }
            syncFocusedGameIndex()
            SoundEffectService.shared.play(.focus)
        case .nonSwitch:
            if !ioses.isEmpty {
                activeLibraryShelf = .ios
                focusedIosIndex = min(focusedNonSwitchIndex, ioses.count - 1)
            } else if !s2.isEmpty {
                activeLibraryShelf = .switch2
                focusedSwitch2Index = min(focusedNonSwitchIndex, s2.count - 1)
            } else if !s1.isEmpty {
                activeLibraryShelf = .mac
                focusedMacIndex = min(focusedNonSwitchIndex, s1.count - 1)
            } else { return }
            syncFocusedGameIndex()
            SoundEffectService.shared.play(.focus)
        case .ios:
            if !s2.isEmpty {
                activeLibraryShelf = .switch2
                focusedSwitch2Index = min(focusedIosIndex, s2.count - 1)
            } else if !s1.isEmpty {
                activeLibraryShelf = .mac
                focusedMacIndex = min(focusedIosIndex, s1.count - 1)
            } else { return }
            syncFocusedGameIndex()
            SoundEffectService.shared.play(.focus)
        case .switch2:
            guard !s1.isEmpty else { return }
            activeLibraryShelf = .mac
            focusedMacIndex = min(focusedSwitch2Index, s1.count - 1)
            syncFocusedGameIndex()
            SoundEffectService.shared.play(.focus)
        case .mac:
            break
        }
    }

    public func handleLibraryNavigateDown() {
        if isGameActionMenuPresented {
            if gameActionFocusedIndex < 6 {
                gameActionFocusedIndex += 1
                SoundEffectService.shared.play(.focus)
            }
            return
        }
        if activeGroupFilter == .all {
            handleUnifiedNavigateDown(columns: max(1, unifiedGridColumnsCount), items: unifiedItems(for: libraryGames))
            return
        }

        let s2 = switch2LibraryGames
        let ioses = iosLibraryGames
        let nons = nonSwitchLibraryGames
        let unporteds = unportedGames

        switch activeLibraryShelf {
        case .mac:
            if !s2.isEmpty {
                activeLibraryShelf = .switch2
                focusedSwitch2Index = min(focusedMacIndex, s2.count - 1)
                syncFocusedGameIndex()
            } else if !ioses.isEmpty {
                activeLibraryShelf = .ios
                focusedIosIndex = min(focusedMacIndex, ioses.count - 1)
                syncFocusedGameIndex()
            } else if !nons.isEmpty {
                activeLibraryShelf = .nonSwitch
                focusedNonSwitchIndex = min(focusedMacIndex, nons.count - 1)
                syncFocusedGameIndex()
            } else if !unporteds.isEmpty {
                activeLibraryShelf = .unportedSwitch
                focusedUnportedGameIndex = min(focusedMacIndex, unporteds.count - 1)
                if !isBuilding { selectedGame = unporteds[focusedUnportedGameIndex] }
            } else { return }
            SoundEffectService.shared.play(.focus)
        case .switch2:
            if !ioses.isEmpty {
                activeLibraryShelf = .ios
                focusedIosIndex = min(focusedSwitch2Index, ioses.count - 1)
                syncFocusedGameIndex()
            } else if !nons.isEmpty {
                activeLibraryShelf = .nonSwitch
                focusedNonSwitchIndex = min(focusedSwitch2Index, nons.count - 1)
                syncFocusedGameIndex()
            } else if !unporteds.isEmpty {
                activeLibraryShelf = .unportedSwitch
                focusedUnportedGameIndex = min(focusedSwitch2Index, unporteds.count - 1)
                if !isBuilding { selectedGame = unporteds[focusedUnportedGameIndex] }
            } else { return }
            SoundEffectService.shared.play(.focus)
        case .ios:
            if !nons.isEmpty {
                activeLibraryShelf = .nonSwitch
                focusedNonSwitchIndex = min(focusedIosIndex, nons.count - 1)
                syncFocusedGameIndex()
            } else if !unporteds.isEmpty {
                activeLibraryShelf = .unportedSwitch
                focusedUnportedGameIndex = min(focusedIosIndex, unporteds.count - 1)
                if !isBuilding { selectedGame = unporteds[focusedUnportedGameIndex] }
            } else { return }
            SoundEffectService.shared.play(.focus)
        case .nonSwitch:
            guard !unporteds.isEmpty else { return }
            activeLibraryShelf = .unportedSwitch
            focusedUnportedGameIndex = min(focusedNonSwitchIndex, unporteds.count - 1)
            if !isBuilding { selectedGame = unporteds[focusedUnportedGameIndex] }
            SoundEffectService.shared.play(.focus)
        case .unportedSwitch:
            break
        }
    }
}
