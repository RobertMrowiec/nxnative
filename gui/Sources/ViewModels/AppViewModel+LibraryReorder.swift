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
}
