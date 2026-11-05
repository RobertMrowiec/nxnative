import Foundation
import AppKit

extension AppViewModel {
    /// Moves `dragged` to the position of `target` within the library, keeping focus attached to `dragged` and persisting manual order.
    public func moveLibraryGame(_ dragged: PortedGame, onto target: PortedGame) {
        let draggedPath = dragged.url.standardizedFileURL.path
        let targetPath = target.url.standardizedFileURL.path
        guard draggedPath != targetPath,
              let from = libraryGames.firstIndex(where: { $0.url.standardizedFileURL.path == draggedPath }),
              let to = libraryGames.firstIndex(where: { $0.url.standardizedFileURL.path == targetPath }) else { return }

        activateManualOrderMode()

        var games = libraryGames
        let moved = games.remove(at: from)
        games.insert(moved, at: to)
        libraryGames = games
        LibraryOrder.save(games)

        if dragged.platform == .macApp {
            if dragged.isSwitch2 {
                activeLibraryShelf = .switch2
                if let idx = switch2LibraryGames.firstIndex(where: { $0.url.standardizedFileURL.path == draggedPath }) {
                    focusedSwitch2Index = idx
                }
            } else {
                activeLibraryShelf = .mac
                if let idx = switch1LibraryGames.firstIndex(where: { $0.url.standardizedFileURL.path == draggedPath }) {
                    focusedMacIndex = idx
                }
            }
        } else if dragged.platform == .ios {
            activeLibraryShelf = .ios
            if let idx = iosLibraryGames.firstIndex(where: { $0.url.standardizedFileURL.path == draggedPath }) {
                focusedIosIndex = idx
            }
        } else {
            activeLibraryShelf = .nonSwitch
            if let idx = nonSwitchLibraryGames.firstIndex(where: { $0.url.standardizedFileURL.path == draggedPath }) {
                focusedNonSwitchIndex = idx
            }
        }

        let unified = unifiedItems(for: games)
        if let uIdx = unified.firstIndex(where: {
            if case .ported(let g) = $0 {
                return g.url.standardizedFileURL.path == draggedPath
            }
            return false
        }) {
            focusedUnifiedIndex = uIdx
        }
        syncFocusedGameIndex()
        SoundEffectService.shared.play(.focus)
    }

    public var focusedUnportedGame: SelectableGame? {
        guard !unportedGames.isEmpty else { return nil }
        let idx = max(0, min(focusedUnportedGameIndex, unportedGames.count - 1))
        return unportedGames[idx]
    }

    public func syncFocusedGameIndex() {
        if let current = currentFocusedGame {
            let currentPath = current.url.standardizedFileURL.path
            if let idx = libraryGames.firstIndex(where: { $0.id == current.id || $0.url.standardizedFileURL.path == currentPath }) {
                focusedGameIndex = idx
            }
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
        if !isBuilding {
            selectedGame = unporteds[idx]
        }
        SoundEffectService.shared.play(.focus)
    }
}
