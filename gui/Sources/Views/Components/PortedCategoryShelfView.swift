import SwiftUI
import AppKit

public struct PortedCategoryShelfView: View {
    @ObservedObject public var viewModel: AppViewModel
    public let title: String
    public let icon: String
    public let shelf: LibraryShelfFocus
    public let categoryColor: Color
    public let items: [PortedGame]
    @Binding public var hoveredTargetGamePath: String?

    public init(
        viewModel: AppViewModel,
        title: String,
        icon: String,
        shelf: LibraryShelfFocus,
        categoryColor: Color,
        items: [PortedGame],
        hoveredTargetGamePath: Binding<String?>
    ) {
        self.viewModel = viewModel
        self.title = title
        self.icon = icon
        self.shelf = shelf
        self.categoryColor = categoryColor
        self.items = items
        self._hoveredTargetGamePath = hoveredTargetGamePath
    }

    public var body: some View {
        let baseCardSize: CGFloat = 144 * CGFloat(viewModel.libraryCardScale)
        let verticalPadding: CGFloat = max(22, baseCardSize * 0.14)
        let cardSpacing: CGFloat = max(20, baseCardSize * 0.13)

        VStack(alignment: .leading, spacing: 6) {
            shelfHeader(title: title, icon: icon, count: items.count, suffix: items.count == 1 ? "game" : "games", color: categoryColor)

            ScrollViewReader { horizontalProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .center, spacing: cardSpacing) {
                        ForEach(items.indices, id: \.self) { idx in
                            let game = items[idx]
                            let isFocused = (viewModel.activeLibraryShelf == shelf) &&
                                            (shelf == .mac ? viewModel.focusedMacIndex == idx :
                                             (shelf == .ios ? viewModel.focusedIosIndex == idx : viewModel.focusedNonSwitchIndex == idx))
                            let isDropTarget = hoveredTargetGamePath == game.url.standardized.path &&
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
                                        if shelf == .mac {
                                            viewModel.selectMacGame(at: idx)
                                        } else if shelf == .ios {
                                            viewModel.selectIosGame(at: idx)
                                        } else {
                                            viewModel.selectNonSwitchGame(at: idx)
                                        }
                                    }
                                }
                            )
                            .zIndex(isFocused ? 10 : (isDropTarget ? 8 : 1))
                            .id("card_\(shelf.rawValue)_\(idx)")
                            .onDrag {
                                viewModel.draggedGame = game
                                return NSItemProvider(object: game.url.standardized.path as NSString)
                            }
                            .onDrop(of: [.text, .plainText], delegate: GameReorderDropDelegate(
                                target: game,
                                viewModel: viewModel,
                                hoveredTargetGamePath: $hoveredTargetGamePath,
                                move: { viewModel.moveLibraryGame($0, onto: $1) }
                            ))
                        }
                    }
                    .padding(.horizontal, 36)
                    .padding(.vertical, verticalPadding)
                }
                .onChange(of: shelf == .mac ? viewModel.focusedMacIndex : (shelf == .ios ? viewModel.focusedIosIndex : viewModel.focusedNonSwitchIndex)) { newIdx in
                    guard viewModel.activeLibraryShelf == shelf else { return }
                    withAnimation(.easeOut(duration: 0.16)) {
                        let anchor: UnitPoint = newIdx == 0 ? .leading : (newIdx >= items.count - 1 ? .trailing : .center)
                        horizontalProxy.scrollTo("card_\(shelf.rawValue)_\(newIdx)", anchor: anchor)
                    }
                }
            }
        }
    }

    private func shelfHeader(title: String, icon: String, count: Int, suffix: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundColor(color)
            Text(title).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(NXTheme.textPrimary)
            Text("· \(count) \(suffix)").font(.system(size: 11, weight: .semibold)).foregroundColor(.white.opacity(0.85))
            Spacer()
        }
        .padding(.horizontal, 34)
    }
}
