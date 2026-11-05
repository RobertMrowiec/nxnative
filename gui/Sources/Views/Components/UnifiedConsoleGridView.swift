import SwiftUI
import AppKit

public struct UnifiedConsoleGridView: View {
    @ObservedObject public var viewModel: AppViewModel
    public let games: [PortedGame]
    @State private var hoveredTargetPath: String? = nil

    public init(viewModel: AppViewModel, games: [PortedGame]) {
        self.viewModel = viewModel
        self.games = games
    }

    private var items: [UnifiedLibraryItem] {
        viewModel.unifiedItems(for: games)
    }

    public var body: some View {
        let baseCardSize: CGFloat = 144 * CGFloat(viewModel.libraryCardScale)
        let cardSpacing: CGFloat = max(20, baseCardSize * 0.13)
        let verticalPadding: CGFloat = max(22, baseCardSize * 0.14)
        let columns = [GridItem(.adaptive(minimum: baseCardSize, maximum: baseCardSize * 1.35), spacing: cardSpacing)]

        LazyVGrid(columns: columns, spacing: cardSpacing) {
            ForEach(Array(items.enumerated()), id: \.element.stableId) { idx, item in
                let isFocused = viewModel.focusedUnifiedIndex == idx

                switch item {
                case .ported(let game):
                    let isDropTarget = hoveredTargetPath == game.url.standardized.path &&
                                       viewModel.draggedGame != nil &&
                                       viewModel.draggedGame?.url.standardized.path != game.url.standardized.path

                    SquareGameCardView(
                        game: game,
                        viewModel: viewModel,
                        isFocused: isFocused,
                        isDropTarget: isDropTarget,
                        baseSize: baseCardSize,
                        onSelect: {
                            guard !viewModel.isAnyModalPresented else { return }
                            viewModel.draggedGame = nil
                            hoveredTargetPath = nil
                            let targetPath = game.url.standardizedFileURL.path
                            let wasAlreadySelectedAndSynced =
                                isFocused &&
                                viewModel.activeLibraryShelf != .unportedSwitch &&
                                viewModel.currentFocusedGame?.url.standardizedFileURL.path == targetPath
                            viewModel.selectUnifiedItem(at: idx, items: items, playSound: !wasAlreadySelectedAndSynced)
                            if wasAlreadySelectedAndSynced {
                                viewModel.isFocusOnHeroBar = true
                                viewModel.heroActionFocusIndex = 0
                                SoundEffectService.shared.play(.click)
                            } else {
                                viewModel.isFocusOnHeroBar = false
                            }
                        }
                    )
                    .zIndex(isFocused ? 10 : (isDropTarget ? 8 : 1))
                    .id(item.stableId)
                    .onDrag {
                        viewModel.draggedGame = game
                        return NSItemProvider(object: game.url.standardized.path as NSString)
                    }
                    .onDrop(of: [.text, .plainText], delegate: GameReorderDropDelegate(
                        target: game,
                        viewModel: viewModel,
                        hoveredTargetGamePath: $hoveredTargetPath,
                        move: { dragged, target in
                            viewModel.moveUnifiedItem(
                                fromPath: dragged.url.standardized.path,
                                onto: target.url.standardized.path,
                                items: items
                            )
                        }
                    ))

                case .unported(let unported):
                    UnportedGameCardView(
                        game: unported,
                        viewModel: viewModel,
                        isFocused: isFocused,
                        baseSize: baseCardSize,
                        onSelect: {
                            guard !viewModel.isAnyModalPresented else { return }
                            viewModel.draggedGame = nil
                            hoveredTargetPath = nil
                            let wasAlreadySelectedAndSynced =
                                isFocused &&
                                viewModel.activeLibraryShelf == .unportedSwitch &&
                                viewModel.focusedUnportedGame?.id == unported.id
                            viewModel.selectUnifiedItem(at: idx, items: items, playSound: !wasAlreadySelectedAndSynced)
                            if wasAlreadySelectedAndSynced {
                                viewModel.isFocusOnHeroBar = true
                                viewModel.heroActionFocusIndex = 0
                                SoundEffectService.shared.play(.click)
                            } else {
                                viewModel.isFocusOnHeroBar = false
                            }
                        }
                    )
                    .zIndex(isFocused ? 10 : 1)
                    .id(item.stableId)
                }
            }

            AddGameCardView(viewModel: viewModel, baseSize: baseCardSize)
                .id("unified_card_add")
                .zIndex(viewModel.focusedUnifiedIndex == items.count ? 10 : 1)
        }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(key: UnifiedGridWidthKey.self, value: geo.size.width)
                }
            )
            .padding(.horizontal, 36)
            .padding(.vertical, verticalPadding)
            .onPreferenceChange(UnifiedGridWidthKey.self) { width in
                guard width > 0 else { return }
                let baseCardSize: CGFloat = 144 * CGFloat(viewModel.libraryCardScale)
                let cardSpacing: CGFloat = max(20, baseCardSize * 0.13)
                let colCount = max(1, Int((width + cardSpacing) / (baseCardSize + cardSpacing)))
                if viewModel.unifiedGridColumnsCount != colCount {
                    viewModel.unifiedGridColumnsCount = colCount
                }
            }
    }
}

private struct UnifiedGridWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
