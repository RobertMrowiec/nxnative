import SwiftUI
import AppKit

public struct SwitchConsoleLibraryView: View {
    @ObservedObject public var viewModel: AppViewModel
    public let games: [PortedGame]
    @State private var scrollWheelMonitor: Any? = nil
    @State private var hoveredTargetGamePath: String? = nil

    public init(viewModel: AppViewModel, games: [PortedGame]) {
        self.viewModel = viewModel
        self.games = games
    }

    private var macGames: [PortedGame] {
        games.filter { $0.platform == .macApp && !$0.isSwitch2 }
    }

    private var switch2Games: [PortedGame] {
        games.filter { $0.platform == .macApp && $0.isSwitch2 }
    }

    private var iosGames: [PortedGame] {
        games.filter { $0.platform == .ios }
    }

    private var nonSwitchGames: [PortedGame] {
        games.filter { $0.platform == .nonSwitch }
    }

    private var sortedUnportedGames: [SelectableGame] {
        viewModel.unportedGames
    }

    public var body: some View {
        GeometryReader { geo in
            let availableHeight = geo.size.height
            let heroHeight: CGFloat = max(230, min(330, availableHeight * 0.40))

            VStack(alignment: .leading, spacing: 0) {
                // MARK: - 1. Pinned Hero Section (Always visible)
                heroSection(height: heroHeight)
                    .frame(height: heroHeight)
                    .clipped()

                // MARK: - 1.5 Pinned Filter and Sort Bar (Always accessible)
                LibraryFilterSortBarView(viewModel: viewModel)
                    .padding(.top, 2)
                    .padding(.bottom, 4)

                // MARK: - 2. Scrollable Games Catalog (Only this section scrolls)
                ScrollViewReader { verticalProxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        catalogContent
                            .padding(.bottom, 36)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .nxScrollEdgeEffect(edges: [.top, .bottom])
                    .onChange(of: viewModel.activeLibraryShelf) { newShelf in
                        guard viewModel.activeGroupFilter != .all else { return }
                        withAnimation(.easeInOut(duration: 0.20)) {
                            switch newShelf {
                            case .mac:
                                verticalProxy.scrollTo("shelf_mac", anchor: .top)
                            case .switch2:
                                verticalProxy.scrollTo("shelf_switch2", anchor: .center)
                            case .ios:
                                verticalProxy.scrollTo("shelf_ios", anchor: .center)
                            case .nonSwitch:
                                verticalProxy.scrollTo("shelf_non_switch", anchor: .center)
                            case .unportedSwitch:
                                verticalProxy.scrollTo("shelf_unported", anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: viewModel.focusedUnifiedIndex) { newIdx in
                        guard viewModel.activeGroupFilter == .all else { return }
                        withAnimation(.easeInOut(duration: 0.20)) {
                            let isFirstRow = newIdx < max(1, viewModel.unifiedGridColumnsCount)
                            verticalProxy.scrollTo("unified_card_\(newIdx)", anchor: isFirstRow ? .top : .center)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            installScrollWheelForwarder()
        }
        .onDisappear {
            removeScrollWheelForwarder()
        }
    }

    // MARK: - Hero Section Builder
    @ViewBuilder
    private func heroSection(height: CGFloat) -> some View {
        if viewModel.activeLibraryShelf == .unportedSwitch, let unported = viewModel.focusedUnportedGame {
            ConsoleHeroView(unportedGame: unported, viewModel: viewModel, height: height)
                .id("hero_unported_\(unported.id)")
        } else if let selected = viewModel.currentFocusedGame {
            ConsoleHeroView(game: selected, viewModel: viewModel, height: height)
                .id("hero_game_\(selected.id.uuidString)")
        } else if let fallback = games.first {
            ConsoleHeroView(game: fallback, viewModel: viewModel, height: height)
                .id("hero_fallback_\(fallback.id.uuidString)")
        }
    }

    // MARK: - Catalog Content
    @ViewBuilder
    private var catalogContent: some View {
        if viewModel.activeGroupFilter == .all {
            UnifiedConsoleGridView(viewModel: viewModel, games: games)
                .id("unified_grid")
        } else {
            VStack(alignment: .leading, spacing: 18) {
                if (viewModel.activeGroupFilter == .categories || viewModel.activeGroupFilter == .mac) && !macGames.isEmpty {
                    PortedCategoryShelfView(
                        viewModel: viewModel,
                        title: viewModel.tr("shelf.switch1_title"),
                        icon: "laptopcomputer",
                        shelf: .mac,
                        categoryColor: NXTheme.primary,
                        items: macGames,
                        hoveredTargetGamePath: $hoveredTargetGamePath
                    )
                    .id("shelf_mac")
                }

                if (viewModel.activeGroupFilter == .categories || viewModel.activeGroupFilter == .switch2) && !switch2Games.isEmpty {
                    PortedCategoryShelfView(
                        viewModel: viewModel,
                        title: viewModel.tr("shelf.switch2_title"),
                        icon: "sparkles.tv.fill",
                        shelf: .switch2,
                        categoryColor: Color(red: 0.95, green: 0.48, blue: 0.16),
                        items: switch2Games,
                        hoveredTargetGamePath: $hoveredTargetGamePath
                    )
                    .id("shelf_switch2")
                }

                if (viewModel.activeGroupFilter == .categories || viewModel.activeGroupFilter == .ios) && !iosGames.isEmpty {
                    PortedCategoryShelfView(
                        viewModel: viewModel,
                        title: viewModel.tr("shelf.ios_title"),
                        icon: "iphone.gen3",
                        shelf: .ios,
                        categoryColor: NXTheme.secondary,
                        items: iosGames,
                        hoveredTargetGamePath: $hoveredTargetGamePath
                    )
                    .id("shelf_ios")
                }

                if (viewModel.activeGroupFilter == .categories || viewModel.activeGroupFilter == .nonSwitch) && !nonSwitchGames.isEmpty {
                    PortedCategoryShelfView(
                        viewModel: viewModel,
                        title: viewModel.tr("shelf.non_switch_title"),
                        icon: "gamecontroller.fill",
                        shelf: .nonSwitch,
                        categoryColor: Color(red: 0.20, green: 0.82, blue: 0.60),
                        items: nonSwitchGames,
                        hoveredTargetGamePath: $hoveredTargetGamePath
                    )
                    .id("shelf_non_switch")
                }

                if viewModel.activeGroupFilter == .categories || viewModel.activeGroupFilter == .switchFiles {
                    unportedShelf
                        .id("shelf_unported")
                }
            }
        }

        if macGames.isEmpty && switch2Games.isEmpty && iosGames.isEmpty && nonSwitchGames.isEmpty && viewModel.unportedGames.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "gamecontroller")
                    .font(.system(size: 38))
                    .foregroundColor(NXTheme.textMuted)
                Text(viewModel.tr("console.no_games"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(NXTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 140)
        }
    }

    // MARK: - Shelf 3: Nintendo Switch ROMs (Unported)
    @ViewBuilder
    private var unportedShelf: some View {
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
                        ForEach(items.indices, id: \.self) { idx in
                            let game = items[idx]
                            let isFocused = (viewModel.activeLibraryShelf == .unportedSwitch) &&
                                            (viewModel.focusedUnportedGameIndex == idx)

                            UnportedGameCardView(
                                game: game,
                                viewModel: viewModel,
                                isFocused: isFocused,
                                baseSize: baseCardSize,
                                onSelect: {
                                    guard !viewModel.isAnyModalPresented else { return }
                                    if isFocused {
                                        SoundEffectService.shared.play(.click)
                                        viewModel.selectedGame = game
                                        viewModel.gameForPortModal = game
                                    } else {
                                        viewModel.selectUnportedGame(at: idx)
                                    }
                                }
                            )
                            .zIndex(isFocused ? 10 : 1)
                            .id("card_unported_\(idx)")
                        }

                        // Add Game Card (+)
                        AddGameCardView(viewModel: viewModel, baseSize: baseCardSize)
                            .id("card_unported_add")
                    }
                    .padding(.horizontal, 36)
                    .padding(.vertical, verticalPadding)
                }
                .onChange(of: viewModel.focusedUnportedGameIndex) { newIdx in
                    guard viewModel.activeLibraryShelf == .unportedSwitch else { return }
                    withAnimation(.easeOut(duration: 0.16)) {
                        let anchor: UnitPoint = newIdx == 0 ? .leading : (newIdx >= items.count - 1 ? .trailing : .center)
                        horizontalProxy.scrollTo("card_unported_\(newIdx)", anchor: anchor)
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

    /// Forwards vertical mouse-wheel scrolling over nested horizontal carousels or over the pinned Hero section to the catalog's vertical NSScrollView.
    private func installScrollWheelForwarder() {
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
                // If scrolling over the pinned Hero section or filter bar, forward scroll to the catalog's vertical NSScrollView
                if let catalogSV = findVerticalScrollView(in: window.contentView) {
                    catalogSV.scrollWheel(with: event)
                    return nil
                }
            }
            return event
        }
    }

    private func findVerticalScrollView(in view: NSView?) -> NSScrollView? {
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

    private func removeScrollWheelForwarder() {
        if let monitor = scrollWheelMonitor {
            NSEvent.removeMonitor(monitor)
            scrollWheelMonitor = nil
        }
    }
}
