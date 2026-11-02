import Foundation
import AppKit

extension AppViewModel {
    /// Moves `dragged` to the position of `target` within the library, updating focus and persisting the order.
    public func moveLibraryGame(_ dragged: PortedGame, onto target: PortedGame) {
        let draggedPath = dragged.url.standardized.path
        let targetPath = target.url.standardized.path
        guard draggedPath != targetPath,
              let from = libraryGames.firstIndex(where: { $0.url.standardized.path == draggedPath }),
              let to = libraryGames.firstIndex(where: { $0.url.standardized.path == targetPath }) else { return }

        var games = libraryGames
        let moved = games.remove(at: from)
        games.insert(moved, at: to)
        libraryGames = games

        if let idx = switch1LibraryGames.firstIndex(where: { $0.url.standardized.path == draggedPath }) {
            focusedMacIndex = idx
        }
        if let idx = switch2LibraryGames.firstIndex(where: { $0.url.standardized.path == draggedPath }) {
            focusedSwitch2Index = idx
        }
        if let idx = iosLibraryGames.firstIndex(where: { $0.url.standardized.path == draggedPath }) {
            focusedIosIndex = idx
        }
        if let idx = nonSwitchLibraryGames.firstIndex(where: { $0.url.standardized.path == draggedPath }) {
            focusedNonSwitchIndex = idx
        }
        syncFocusedGameIndex()

        SoundEffectService.shared.play(.focus)
        LibraryOrder.save(games)
    }

    // MARK: - Library Directional Navigation (Five-Row Shelves: Switch 1, Switch 2, iOS, Non-Switch, Switch Unported)
    public var focusedUnportedGame: SelectableGame? {
        guard !unportedGames.isEmpty else { return nil }
        let idx = max(0, min(focusedUnportedGameIndex, unportedGames.count - 1))
        return unportedGames[idx]
    }

    public func syncFocusedGameIndex() {
        if let current = currentFocusedGame,
           let idx = libraryGames.firstIndex(where: { $0.id == current.id }) {
            focusedGameIndex = idx
        }
    }

    public func selectMacGame(at idx: Int) {
        let macs = switch1LibraryGames
        guard macs.indices.contains(idx) else { return }
        activeLibraryShelf = .mac
        focusedMacIndex = idx
        syncFocusedGameIndex()
        SoundEffectService.shared.play(.focus)
    }

    public func selectSwitch2Game(at idx: Int) {
        let s2 = switch2LibraryGames
        guard s2.indices.contains(idx) else { return }
        activeLibraryShelf = .switch2
        focusedSwitch2Index = idx
        syncFocusedGameIndex()
        SoundEffectService.shared.play(.focus)
    }

    public func selectIosGame(at idx: Int) {
        let ioses = iosLibraryGames
        guard ioses.indices.contains(idx) else { return }
        activeLibraryShelf = .ios
        focusedIosIndex = idx
        syncFocusedGameIndex()
        SoundEffectService.shared.play(.focus)
    }

    public func selectNonSwitchGame(at idx: Int) {
        let nons = nonSwitchLibraryGames
        guard nons.indices.contains(idx) else { return }
        activeLibraryShelf = .nonSwitch
        focusedNonSwitchIndex = idx
        syncFocusedGameIndex()
        SoundEffectService.shared.play(.focus)
    }

    public func selectUnportedGame(at idx: Int) {
        let unporteds = unportedGames
        guard unporteds.indices.contains(idx) else { return }
        activeLibraryShelf = .unportedSwitch
        focusedUnportedGameIndex = idx
        SoundEffectService.shared.play(.focus)
    }

    public func handleLibraryNavigateLeft() {
        guard !isGameActionMenuPresented else { return }
        if activeGroupFilter == .all {
            handleUnifiedNavigateLeft(items: unifiedItems(for: libraryGames))
            return
        }
        switch activeLibraryShelf {
        case .mac:
            let macs = switch1LibraryGames
            guard !macs.isEmpty else { return }
            if focusedMacIndex > 0 {
                focusedMacIndex -= 1
                syncFocusedGameIndex()
                SoundEffectService.shared.play(.focus)
            }
        case .switch2:
            let s2 = switch2LibraryGames
            guard !s2.isEmpty else { return }
            if focusedSwitch2Index > 0 {
                focusedSwitch2Index -= 1
                syncFocusedGameIndex()
                SoundEffectService.shared.play(.focus)
            }
        case .ios:
            let ioses = iosLibraryGames
            guard !ioses.isEmpty else { return }
            if focusedIosIndex > 0 {
                focusedIosIndex -= 1
                syncFocusedGameIndex()
                SoundEffectService.shared.play(.focus)
            }
        case .nonSwitch:
            let nons = nonSwitchLibraryGames
            guard !nons.isEmpty else { return }
            if focusedNonSwitchIndex > 0 {
                focusedNonSwitchIndex -= 1
                syncFocusedGameIndex()
                SoundEffectService.shared.play(.focus)
            }
        case .unportedSwitch:
            let unporteds = unportedGames
            guard !unporteds.isEmpty else { return }
            if focusedUnportedGameIndex > 0 {
                focusedUnportedGameIndex -= 1
                SoundEffectService.shared.play(.focus)
            }
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
            guard !macs.isEmpty else { return }
            if focusedMacIndex < macs.count - 1 {
                focusedMacIndex += 1
                syncFocusedGameIndex()
                SoundEffectService.shared.play(.focus)
            }
        case .switch2:
            let s2 = switch2LibraryGames
            guard !s2.isEmpty else { return }
            if focusedSwitch2Index < s2.count - 1 {
                focusedSwitch2Index += 1
                syncFocusedGameIndex()
                SoundEffectService.shared.play(.focus)
            }
        case .ios:
            let ioses = iosLibraryGames
            guard !ioses.isEmpty else { return }
            if focusedIosIndex < ioses.count - 1 {
                focusedIosIndex += 1
                syncFocusedGameIndex()
                SoundEffectService.shared.play(.focus)
            }
        case .nonSwitch:
            let nons = nonSwitchLibraryGames
            guard !nons.isEmpty else { return }
            if focusedNonSwitchIndex < nons.count - 1 {
                focusedNonSwitchIndex += 1
                syncFocusedGameIndex()
                SoundEffectService.shared.play(.focus)
            }
        case .unportedSwitch:
            let unporteds = unportedGames
            guard !unporteds.isEmpty else { return }
            if focusedUnportedGameIndex < unporteds.count - 1 {
                focusedUnportedGameIndex += 1
                SoundEffectService.shared.play(.focus)
            }
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
                syncFocusedGameIndex()
                SoundEffectService.shared.play(.focus)
            } else if !ioses.isEmpty {
                activeLibraryShelf = .ios
                focusedIosIndex = min(focusedUnportedGameIndex, ioses.count - 1)
                syncFocusedGameIndex()
                SoundEffectService.shared.play(.focus)
            } else if !s2.isEmpty {
                activeLibraryShelf = .switch2
                focusedSwitch2Index = min(focusedUnportedGameIndex, s2.count - 1)
                syncFocusedGameIndex()
                SoundEffectService.shared.play(.focus)
            } else if !s1.isEmpty {
                activeLibraryShelf = .mac
                focusedMacIndex = min(focusedUnportedGameIndex, s1.count - 1)
                syncFocusedGameIndex()
                SoundEffectService.shared.play(.focus)
            }
        case .nonSwitch:
            if !ioses.isEmpty {
                activeLibraryShelf = .ios
                focusedIosIndex = min(focusedNonSwitchIndex, ioses.count - 1)
                syncFocusedGameIndex()
                SoundEffectService.shared.play(.focus)
            } else if !s2.isEmpty {
                activeLibraryShelf = .switch2
                focusedSwitch2Index = min(focusedNonSwitchIndex, s2.count - 1)
                syncFocusedGameIndex()
                SoundEffectService.shared.play(.focus)
            } else if !s1.isEmpty {
                activeLibraryShelf = .mac
                focusedMacIndex = min(focusedNonSwitchIndex, s1.count - 1)
                syncFocusedGameIndex()
                SoundEffectService.shared.play(.focus)
            }
        case .ios:
            if !s2.isEmpty {
                activeLibraryShelf = .switch2
                focusedSwitch2Index = min(focusedIosIndex, s2.count - 1)
                syncFocusedGameIndex()
                SoundEffectService.shared.play(.focus)
            } else if !s1.isEmpty {
                activeLibraryShelf = .mac
                focusedMacIndex = min(focusedIosIndex, s1.count - 1)
                syncFocusedGameIndex()
                SoundEffectService.shared.play(.focus)
            }
        case .switch2:
            if !s1.isEmpty {
                activeLibraryShelf = .mac
                focusedMacIndex = min(focusedSwitch2Index, s1.count - 1)
                syncFocusedGameIndex()
                SoundEffectService.shared.play(.focus)
            }
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
                SoundEffectService.shared.play(.focus)
            } else if !ioses.isEmpty {
                activeLibraryShelf = .ios
                focusedIosIndex = min(focusedMacIndex, ioses.count - 1)
                syncFocusedGameIndex()
                SoundEffectService.shared.play(.focus)
            } else if !nons.isEmpty {
                activeLibraryShelf = .nonSwitch
                focusedNonSwitchIndex = min(focusedMacIndex, nons.count - 1)
                syncFocusedGameIndex()
                SoundEffectService.shared.play(.focus)
            } else if !unporteds.isEmpty {
                activeLibraryShelf = .unportedSwitch
                focusedUnportedGameIndex = min(focusedMacIndex, unporteds.count - 1)
                SoundEffectService.shared.play(.focus)
            }
        case .switch2:
            if !ioses.isEmpty {
                activeLibraryShelf = .ios
                focusedIosIndex = min(focusedSwitch2Index, ioses.count - 1)
                syncFocusedGameIndex()
                SoundEffectService.shared.play(.focus)
            } else if !nons.isEmpty {
                activeLibraryShelf = .nonSwitch
                focusedNonSwitchIndex = min(focusedSwitch2Index, nons.count - 1)
                syncFocusedGameIndex()
                SoundEffectService.shared.play(.focus)
            } else if !unporteds.isEmpty {
                activeLibraryShelf = .unportedSwitch
                focusedUnportedGameIndex = min(focusedSwitch2Index, unporteds.count - 1)
                SoundEffectService.shared.play(.focus)
            }
        case .ios:
            if !nons.isEmpty {
                activeLibraryShelf = .nonSwitch
                focusedNonSwitchIndex = min(focusedIosIndex, nons.count - 1)
                syncFocusedGameIndex()
                SoundEffectService.shared.play(.focus)
            } else if !unporteds.isEmpty {
                activeLibraryShelf = .unportedSwitch
                focusedUnportedGameIndex = min(focusedIosIndex, unporteds.count - 1)
                SoundEffectService.shared.play(.focus)
            }
        case .nonSwitch:
            if !unporteds.isEmpty {
                activeLibraryShelf = .unportedSwitch
                focusedUnportedGameIndex = min(focusedNonSwitchIndex, unporteds.count - 1)
                SoundEffectService.shared.play(.focus)
            }
        case .unportedSwitch:
            break
        }
    }
}
