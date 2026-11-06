import SwiftUI
import AppKit

public struct SwitchConsoleLibraryView: View {
    @ObservedObject public var viewModel: AppViewModel
    public let games: [PortedGame]
    public let containerHeight: CGFloat
    @State internal var scrollWheelMonitor: Any? = nil
    @State private var hoveredTargetGamePath: String? = nil

    public init(viewModel: AppViewModel, games: [PortedGame], containerHeight: CGFloat = 720) {
        self.viewModel = viewModel
        self.games = games
        self.containerHeight = containerHeight
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

    internal var sortedUnportedGames: [SelectableGame] {
        var list = viewModel.unportedGames
        if viewModel.activeGroupFilter == .switch2 {
            list = list.filter { $0.isSwitch2 || $0.isNup }
        }
        let query = viewModel.librarySearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(query) ||
                ($0.titleId?.localizedCaseInsensitiveContains(query) == true)
            }
        }
        return list
    }

    public var body: some View {
        GeometryReader { geo in
            let availableHeight = geo.size.height
            let heroHeight: CGFloat = max(290, min(500, availableHeight * 0.46))

            VStack(alignment: .leading, spacing: 0) {
                heroSection(height: heroHeight)
                    .frame(maxWidth: .infinity, minHeight: heroHeight, maxHeight: heroHeight)
                    .clipped()

                LibraryFilterSortBarView(viewModel: viewModel)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
                    .padding(.bottom, 4)

                ScrollViewReader { verticalProxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        catalogContent
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(.bottom, 36)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .nxScrollEdgeEffect(edges: [.top, .bottom])
                    .onDrop(of: [.text, .plainText], isTargeted: nil) { _ in
                        guard viewModel.draggedGame != nil else { return false }
                        viewModel.draggedGame = nil
                        hoveredTargetGamePath = nil
                        return true
                    }
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
                        let items = viewModel.unifiedItems(for: games)
                        let targetId: String? = items.indices.contains(newIdx)
                            ? items[newIdx].stableId
                            : (newIdx == items.count ? "unified_card_add" : nil)
                        guard let scrollId = targetId else { return }
                        withAnimation(.easeInOut(duration: 0.20)) {
                            let isFirstRow = newIdx < max(1, viewModel.unifiedGridColumnsCount)
                            verticalProxy.scrollTo(scrollId, anchor: isFirstRow ? .top : .center)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        let (targetGame, targetUnported): (PortedGame?, SelectableGame?) = {
            if viewModel.activeGroupFilter == .all {
                let items = viewModel.unifiedItems(for: games)
                if items.indices.contains(viewModel.focusedUnifiedIndex) {
                    switch items[viewModel.focusedUnifiedIndex] {
                    case .ported(let g):
                        return (g, nil)
                    case .unported(let u):
                        return (nil, u)
                    }
                } else if let first = items.first {
                    switch first {
                    case .ported(let g):
                        return (g, nil)
                    case .unported(let u):
                        return (nil, u)
                    }
                }
            }
            if viewModel.activeLibraryShelf == .unportedSwitch || viewModel.activeGroupFilter == .switchFiles {
                if let u = viewModel.focusedUnportedGame ?? sortedUnportedGames.first {
                    return (nil, u)
                }
            }
            if let selected = viewModel.currentFocusedGame {
                return (selected, nil)
            }
            if let fallbackGame = games.first {
                return (fallbackGame, nil)
            }
            if let fallbackUnported = sortedUnportedGames.first {
                return (nil, fallbackUnported)
            }
            return (nil, nil)
        }()

        ConsoleHeroView(
            game: targetGame,
            unportedGame: targetUnported,
            viewModel: viewModel,
            height: height
        )
        .id("hero_stable_view")
    }

    // MARK: - Catalog Content
    @ViewBuilder
    private var catalogContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            if viewModel.activeGroupFilter == .all {
                UnifiedConsoleGridView(viewModel: viewModel, games: games)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
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

                    if viewModel.activeGroupFilter == .categories || viewModel.activeGroupFilter == .switchFiles || viewModel.activeGroupFilter == .switch2 {
                        unportedShelf
                            .id("shelf_unported")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
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
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
