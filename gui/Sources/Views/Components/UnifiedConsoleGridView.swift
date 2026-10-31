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
        let columns = [GridItem(.adaptive(minimum: baseCardSize, maximum: baseCardSize * 1.05), spacing: cardSpacing)]

        LazyVGrid(columns: columns, spacing: cardSpacing) {
            ForEach(items.indices, id: \.self) { idx in
                    let item = items[idx]
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
                                if isFocused {
                                    if game.platform == .macApp || game.platform == .nonSwitch {
                                        viewModel.launchGame(game)
                                    } else {
                                        SoundEffectService.shared.play(.click)
                                        viewModel.gameForSettingsSheet = game
                                    }
                                } else {
                                    viewModel.selectUnifiedItem(at: idx, items: items)
                                }
                            }
                        )
                        .zIndex(isFocused ? 10 : (isDropTarget ? 8 : 1))
                        .id("unified_card_\(idx)")
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
                                if isFocused {
                                    SoundEffectService.shared.play(.click)
                                    viewModel.selectedGame = unported
                                    viewModel.gameForPortModal = unported
                                } else {
                                    viewModel.selectUnifiedItem(at: idx, items: items)
                                }
                            }
                        )
                        .zIndex(isFocused ? 10 : 1)
                        .id("unified_card_\(idx)")
                    }
                }

                // MARK: - Last Item: Add Game / Folder (+) Card with Drag and Drop
                AddGameCardView(viewModel: viewModel, baseSize: baseCardSize)
                    .id("unified_card_\(items.count)")
                    .zIndex(viewModel.focusedUnifiedIndex == items.count ? 10 : 1)
            }
            .padding(.horizontal, 36)
            .padding(.vertical, verticalPadding)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(key: UnifiedGridWidthKey.self, value: geo.size.width)
                }
            )
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
