import Foundation
import AppKit

extension AppViewModel {
    /// Moves `dragged` to the position of `target` within the same platform shelf, updating focus and persisting the order.
    public func moveLibraryGame(_ dragged: PortedGame, onto target: PortedGame) {
        let draggedPath = dragged.url.standardized.path
        let targetPath = target.url.standardized.path
        guard draggedPath != targetPath, dragged.platform == target.platform,
              let from = libraryGames.firstIndex(where: { $0.url.standardized.path == draggedPath }),
              let to = libraryGames.firstIndex(where: { $0.url.standardized.path == targetPath }) else { return }

        let focusedPath = libraryGames.indices.contains(focusedGameIndex)
            ? libraryGames[focusedGameIndex].url.standardized.path
            : nil

        var games = libraryGames
        let moved = games.remove(at: from)
        games.insert(moved, at: to)
        libraryGames = games

        if let focusedPath, let idx = games.firstIndex(where: { $0.url.standardized.path == focusedPath }) {
            focusedGameIndex = idx
        }

        SoundEffectService.shared.play(.focus)
        LibraryOrder.save(games)
    }

    // MARK: - Library Directional Navigation (Two-Row Shelves)
    public func handleLibraryNavigateLeft() {
        guard !isGameActionMenuPresented && focusedGameIndex > 0 else { return }
        focusedGameIndex -= 1
        SoundEffectService.shared.play(.focus)
    }

    public func handleLibraryNavigateRight() {
        guard !isGameActionMenuPresented && focusedGameIndex < libraryGames.count - 1 else { return }
        focusedGameIndex += 1
        SoundEffectService.shared.play(.focus)
    }

    public func handleLibraryNavigateUp() {
        if isGameActionMenuPresented {
            if gameActionFocusedIndex > 0 {
                gameActionFocusedIndex -= 1
                SoundEffectService.shared.play(.focus)
            }
            return
        }
        let macs = macLibraryGames
        let ioses = iosLibraryGames
        if let cur = currentFocusedGame, let iosIdx = ioses.firstIndex(where: { $0.id == cur.id }), !macs.isEmpty {
            let targetMacIdx = min(iosIdx, macs.count - 1)
            if let newGameIdx = libraryGames.firstIndex(where: { $0.id == macs[targetMacIdx].id }) {
                focusedGameIndex = newGameIdx
                SoundEffectService.shared.play(.focus)
            }
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
        let macs = macLibraryGames
        let ioses = iosLibraryGames
        if let cur = currentFocusedGame, let macIdx = macs.firstIndex(where: { $0.id == cur.id }), !ioses.isEmpty {
            let targetIosIdx = min(macIdx, ioses.count - 1)
            if let newGameIdx = libraryGames.firstIndex(where: { $0.id == ioses[targetIosIdx].id }) {
                focusedGameIndex = newGameIdx
                SoundEffectService.shared.play(.focus)
            }
        }
    }
}
