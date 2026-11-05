import SwiftUI
import AppKit

extension SwitchConsoleLibraryView {
    // MARK: - Nintendo Switch ROMs (Unported Shelf)
    @ViewBuilder
    internal var unportedShelf: some View {
        let baseCardSize: CGFloat = 144 * CGFloat(viewModel.libraryCardScale)
        let verticalPadding: CGFloat = max(22, baseCardSize * 0.14)
        let cardSpacing: CGFloat = max(20, baseCardSize * 0.13)
        let items = sortedUnportedGames

        VStack(alignment: .leading, spacing: 6) {
            shelfHeader(
                title: "Nintendo Switch (Unported ROMs)",
                icon: "gamecontroller.fill",
                count: items.count,
                suffix: items.count == 1 ? "ROM" : "ROMs",
                color: NXTheme.secondary
            )

            ScrollViewReader { horizontalProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .center, spacing: cardSpacing) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { idx, game in
                            let isFocused = (viewModel.activeLibraryShelf == .unportedSwitch) &&
                                            (viewModel.focusedUnportedGameIndex == idx)

                            UnportedGameCardView(
                                game: game,
                                viewModel: viewModel,
                                isFocused: isFocused,
                                baseSize: baseCardSize,
                                onSelect: {
                                    guard !viewModel.isAnyModalPresented else { return }
                                    viewModel.draggedGame = nil
                                    let wasAlreadySelectedAndSynced =
                                        isFocused &&
                                        viewModel.focusedUnportedGame?.id == game.id
                                    if wasAlreadySelectedAndSynced {
                                        SoundEffectService.shared.play(.click)
                                        viewModel.selectedGame = game
                                        viewModel.gameForPortModal = game
                                    } else {
                                        viewModel.isFocusOnHeroBar = false
                                        viewModel.selectUnportedGame(at: idx)
                                    }
                                }
                            )
                            .zIndex(isFocused ? 10 : 1)
                            .id("unported_\(game.id)")
                        }

                        AddGameCardView(viewModel: viewModel, baseSize: baseCardSize)
                            .id("card_unported_add")
                    }
                    .padding(.horizontal, 36)
                    .padding(.vertical, verticalPadding)
                }
                .onChange(of: viewModel.focusedUnportedGameIndex) { newIdx in
                    guard viewModel.activeLibraryShelf == .unportedSwitch else { return }
                    let targetId = items.indices.contains(newIdx) ? "unported_\(items[newIdx].id)" : "card_unported_add"
                    withAnimation(.easeOut(duration: 0.16)) {
                        let anchor: UnitPoint = newIdx == 0 ? .leading : (newIdx >= items.count - 1 ? .trailing : .center)
                        horizontalProxy.scrollTo(targetId, anchor: anchor)
                    }
                }
            }
        }
    }

    internal func shelfHeader(title: String, icon: String, count: Int, suffix: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundColor(color)
            Text(title).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(NXTheme.textPrimary)
            Text("· \(count) \(suffix)").font(.system(size: 11, weight: .semibold)).foregroundColor(.white.opacity(0.85))
            Spacer()
        }
        .padding(.horizontal, 34)
    }

    /// Forwards vertical mouse-wheel scrolling over nested horizontal carousels or the pinned Hero section to the catalog's vertical NSScrollView.
    internal func installScrollWheelForwarder() {
        guard scrollWheelMonitor == nil else { return }
        scrollWheelMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            guard !viewModel.isAnyModalPresented, viewModel.selectedTab == 0,
                  !event.modifierFlags.contains(.shift),
                  abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX),
                  abs(event.scrollingDeltaY) > 0.01,
                  let window = event.window,
                  let hitView = window.contentView?.hitTest(event.locationInWindow) else {
                return event
            }

            var scrollViews: [NSScrollView] = []
            var cursor: NSView? = hitView
            while let current = cursor {
                if let sv = current as? NSScrollView { scrollViews.append(sv) }
                cursor = current.superview
            }

            if scrollViews.count >= 2 {
                scrollViews[1].scrollWheel(with: event)
                return nil
            } else if scrollViews.isEmpty {
                if let catalogSV = findVerticalScrollView(in: window.contentView) {
                    catalogSV.scrollWheel(with: event)
                    return nil
                }
            }
            return event
        }
    }

    internal func findVerticalScrollView(in view: NSView?) -> NSScrollView? {
        guard let root = view else { return nil }
        var queue: [NSView] = [root]
        while !queue.isEmpty {
            let current = queue.removeFirst()
            if let sv = current as? NSScrollView {
                if sv.hasVerticalScroller || (sv.documentView?.bounds.height ?? 0) > sv.bounds.height {
                    return sv
                }
            }
            queue.append(contentsOf: current.subviews)
        }
        return nil
    }

    internal func removeScrollWheelForwarder() {
        if let monitor = scrollWheelMonitor {
            NSEvent.removeMonitor(monitor)
            scrollWheelMonitor = nil
        }
    }
}
