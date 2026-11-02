import Foundation
import AppKit

extension AppViewModel {
    public func selectUnifiedItem(at idx: Int, items: [UnifiedLibraryItem]) {
        guard items.indices.contains(idx) else {
            focusedUnifiedIndex = idx
            return
        }
        focusedUnifiedIndex = idx
        let item = items[idx]
        switch item {
        case .ported(let game):
            if game.platform == .macApp {
                if game.isSwitch2 {
                    activeLibraryShelf = .switch2
                    if let sIdx = switch2LibraryGames.firstIndex(where: { $0.id == game.id }) {
                        focusedSwitch2Index = sIdx
                    }
                } else {
                    activeLibraryShelf = .mac
                    if let mIdx = switch1LibraryGames.firstIndex(where: { $0.id == game.id }) {
                        focusedMacIndex = mIdx
                    }
                }
            } else if game.platform == .ios {
                activeLibraryShelf = .ios
                if let iIdx = iosLibraryGames.firstIndex(where: { $0.id == game.id }) {
                    focusedIosIndex = iIdx
                }
            } else {
                activeLibraryShelf = .nonSwitch
                if let nIdx = nonSwitchLibraryGames.firstIndex(where: { $0.id == game.id }) {
                    focusedNonSwitchIndex = nIdx
                }
            }
            syncFocusedGameIndex()
        case .unported(let unported):
            activeLibraryShelf = .unportedSwitch
            selectedGame = unported
            if let uIdx = unportedGames.firstIndex(where: { $0.id == unported.id }) {
                focusedUnportedGameIndex = uIdx
            }
        }
        SoundEffectService.shared.play(.focus)
    }

    public func handleUnifiedNavigateLeft(items: [UnifiedLibraryItem]) {
        guard !items.isEmpty else { return }
        let target = max(0, focusedUnifiedIndex - 1)
        if target != focusedUnifiedIndex {
            selectUnifiedItem(at: target, items: items)
        }
    }

    public func handleUnifiedNavigateRight(items: [UnifiedLibraryItem]) {
        guard !items.isEmpty else { return }
        let totalCount = items.count + 1 // +1 for the Add Game card at end
        let target = min(totalCount - 1, focusedUnifiedIndex + 1)
        if target != focusedUnifiedIndex {
            selectUnifiedItem(at: target, items: items)
        }
    }

    public func handleUnifiedNavigateUp(columns: Int, items: [UnifiedLibraryItem]) {
        guard !items.isEmpty, columns > 0 else { return }
        let target = max(0, focusedUnifiedIndex - columns)
        if target != focusedUnifiedIndex {
            selectUnifiedItem(at: target, items: items)
        }
    }

    public func handleUnifiedNavigateDown(columns: Int, items: [UnifiedLibraryItem]) {
        guard !items.isEmpty, columns > 0 else { return }
        let totalCount = items.count + 1 // +1 for the Add Game card at end
        let target = min(totalCount - 1, focusedUnifiedIndex + columns)
        if target != focusedUnifiedIndex {
            selectUnifiedItem(at: target, items: items)
        }
    }

    public func moveUnifiedItem(fromPath: String, onto targetPath: String, items: [UnifiedLibraryItem]) {
        guard fromPath != targetPath,
              let from = items.firstIndex(where: { $0.path == fromPath }),
              let to = items.firstIndex(where: { $0.path == targetPath }) else { return }
        
        var newItems = items
        let moved = newItems.remove(at: from)
        newItems.insert(moved, at: to)
        LibraryOrder.saveUnified(newItems)
        
        if let fromPorted = libraryGames.firstIndex(where: { $0.url.standardized.path == fromPath }),
           let toPorted = libraryGames.firstIndex(where: { $0.url.standardized.path == targetPath }) {
            var games = libraryGames
            let movedGame = games.remove(at: fromPorted)
            games.insert(movedGame, at: toPorted)
            libraryGames = games
            LibraryOrder.save(games)
        }
        
        SoundEffectService.shared.play(.focus)
    }
}
