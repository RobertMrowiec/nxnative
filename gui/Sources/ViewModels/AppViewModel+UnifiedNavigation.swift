import Foundation
import AppKit

extension AppViewModel {
    public func selectUnifiedItem(at idx: Int, items: [UnifiedLibraryItem], playSound: Bool = true) {
        guard items.indices.contains(idx) else {
            focusedUnifiedIndex = max(0, min(idx, items.count))
            return
        }
        focusedUnifiedIndex = idx
        let item = items[idx]
        switch item {
        case .ported(let game):
            let targetPath = game.url.standardizedFileURL.path
            if game.platform == .macApp {
                if game.isSwitch2 {
                    activeLibraryShelf = .switch2
                    if let sIdx = switch2LibraryGames.firstIndex(where: { $0.url.standardizedFileURL.path == targetPath || $0.id == game.id }) {
                        focusedSwitch2Index = sIdx
                    }
                } else {
                    activeLibraryShelf = .mac
                    if let mIdx = switch1LibraryGames.firstIndex(where: { $0.url.standardizedFileURL.path == targetPath || $0.id == game.id }) {
                        focusedMacIndex = mIdx
                    }
                }
            } else if game.platform == .ios {
                activeLibraryShelf = .ios
                if let iIdx = iosLibraryGames.firstIndex(where: { $0.url.standardizedFileURL.path == targetPath || $0.id == game.id }) {
                    focusedIosIndex = iIdx
                }
            } else {
                activeLibraryShelf = .nonSwitch
                if let nIdx = nonSwitchLibraryGames.firstIndex(where: { $0.url.standardizedFileURL.path == targetPath || $0.id == game.id }) {
                    focusedNonSwitchIndex = nIdx
                }
            }
            syncFocusedGameIndex()
        case .unported(let unported):
            activeLibraryShelf = .unportedSwitch
            if !isBuilding {
                selectedGame = unported
            }
            if let uIdx = unportedGames.firstIndex(where: { $0.id == unported.id }) {
                focusedUnportedGameIndex = uIdx
            }
        }
        if playSound {
            SoundEffectService.shared.play(.focus)
        }
    }

    /// Reconciles unified grid focus, shelf focus, and Hero selection after library scans, port completions, or filter changes.
    public func reconcileLibraryFocusState(preferredPortedURL: URL? = nil) {
        if focusedGameIndex >= libraryGames.count {
            focusedGameIndex = max(0, libraryGames.count - 1)
        }
        focusedMacIndex = max(0, min(focusedMacIndex, max(0, switch1LibraryGames.count - 1)))
        focusedSwitch2Index = max(0, min(focusedSwitch2Index, max(0, switch2LibraryGames.count - 1)))
        focusedIosIndex = max(0, min(focusedIosIndex, max(0, iosLibraryGames.count - 1)))
        focusedNonSwitchIndex = max(0, min(focusedNonSwitchIndex, max(0, nonSwitchLibraryGames.count - 1)))
        focusedUnportedGameIndex = max(0, min(focusedUnportedGameIndex, max(0, unportedGames.count - 1)))

        if !isBuilding, let sel = selectedGame, isGameAlreadyPorted(sel) {
            selectedGame = unportedGames.first
        }

        let visibleGames: [PortedGame] = {
            let trimmed = librarySearchText.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { return libraryGames }
            return libraryGames.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
        }()
        let unified = unifiedItems(for: visibleGames)

        if let targetURL = preferredPortedURL {
            let targetStdPath = targetURL.standardizedFileURL.path
            let matchedGame = libraryGames.first(where: { $0.url.standardizedFileURL.path == targetStdPath })
                ?? libraryGames.first(where: {
                    $0.platform == self.platform &&
                    !self.appName.isEmpty &&
                    $0.name.caseInsensitiveCompare(self.appName) == .orderedSame
                })

            if let portedGame = matchedGame {
                let portedPath = portedGame.url.standardizedFileURL.path
                isFocusOnHeroBar = false
                heroActionFocusIndex = 0
                draggedGame = nil

                if portedGame.platform == .macApp {
                    if portedGame.isSwitch2 {
                        activeLibraryShelf = .switch2
                        if let sIdx = switch2LibraryGames.firstIndex(where: { $0.url.standardizedFileURL.path == portedPath }) {
                            focusedSwitch2Index = sIdx
                        }
                    } else {
                        activeLibraryShelf = .mac
                        if let mIdx = switch1LibraryGames.firstIndex(where: { $0.url.standardizedFileURL.path == portedPath }) {
                            focusedMacIndex = mIdx
                        }
                    }
                } else if portedGame.platform == .ios {
                    activeLibraryShelf = .ios
                    if let iIdx = iosLibraryGames.firstIndex(where: { $0.url.standardizedFileURL.path == portedPath }) {
                        focusedIosIndex = iIdx
                    }
                } else {
                    activeLibraryShelf = .nonSwitch
                    if let nIdx = nonSwitchLibraryGames.firstIndex(where: { $0.url.standardizedFileURL.path == portedPath }) {
                        focusedNonSwitchIndex = nIdx
                    }
                }

                if let uIdx = unified.firstIndex(where: {
                    if case .ported(let g) = $0 {
                        return g.url.standardizedFileURL.path == portedPath
                    }
                    return false
                }) {
                    focusedUnifiedIndex = uIdx
                }
                syncFocusedGameIndex()
                return
            }
        }

        if activeGroupFilter == .all {
            if unified.isEmpty {
                focusedUnifiedIndex = 0
            } else {
                let clamped = max(0, min(focusedUnifiedIndex, unified.count - 1))
                selectUnifiedItem(at: clamped, items: unified, playSound: false)
            }
        } else {
            switch activeGroupFilter {
            case .mac:
                activeLibraryShelf = .mac
            case .switch2:
                activeLibraryShelf = .switch2
            case .ios:
                activeLibraryShelf = .ios
            case .nonSwitch:
                activeLibraryShelf = .nonSwitch
            case .switchFiles:
                activeLibraryShelf = .unportedSwitch
            case .categories, .all:
                let isCurrentShelfEmpty: Bool = {
                    switch activeLibraryShelf {
                    case .mac: return switch1LibraryGames.isEmpty
                    case .switch2: return switch2LibraryGames.isEmpty
                    case .ios: return iosLibraryGames.isEmpty
                    case .nonSwitch: return nonSwitchLibraryGames.isEmpty
                    case .unportedSwitch: return unportedGames.isEmpty
                    }
                }()
                if isCurrentShelfEmpty {
                    if !switch1LibraryGames.isEmpty {
                        activeLibraryShelf = .mac
                    } else if !switch2LibraryGames.isEmpty {
                        activeLibraryShelf = .switch2
                    } else if !iosLibraryGames.isEmpty {
                        activeLibraryShelf = .ios
                    } else if !nonSwitchLibraryGames.isEmpty {
                        activeLibraryShelf = .nonSwitch
                    } else if !unportedGames.isEmpty {
                        activeLibraryShelf = .unportedSwitch
                    }
                }
            }

            if activeLibraryShelf == .unportedSwitch, let u = focusedUnportedGame {
                if let uIdx = unified.firstIndex(where: { if case .unported(let item) = $0 { return item.id == u.id }; return false }) {
                    focusedUnifiedIndex = uIdx
                }
            } else if let g = currentFocusedGame {
                let gPath = g.url.standardizedFileURL.path
                if let uIdx = unified.firstIndex(where: { if case .ported(let item) = $0 { return item.url.standardizedFileURL.path == gPath }; return false }) {
                    focusedUnifiedIndex = uIdx
                }
            }
            syncFocusedGameIndex()
        }
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

        activateManualOrderMode()

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

        selectUnifiedItem(at: to, items: newItems, playSound: false)
        objectWillChange.send()
        SoundEffectService.shared.play(.focus)
    }
}
