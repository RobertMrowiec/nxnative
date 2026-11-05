import SwiftUI

public struct MainView: View {
    @ObservedObject public var viewModel: AppViewModel
    @ObservedObject private var menuBarManager = MenuBarManager.shared
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var windowWidth: CGFloat = 1180
    @State private var windowHeight: CGFloat = 760
    @State internal var animatedTabPill: Int = 0
    @Namespace internal var navTabNamespace
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    internal var tabs: [(tag: Int, title: String, icon: String)] {
        var items: [(tag: Int, title: String, icon: String)] = [
            (0, viewModel.tr("nav.my_games"), "gamecontroller.fill"),
            (1, viewModel.tr("nav.compatibility"), "books.vertical.fill"),
            (2, viewModel.tr("nav.controls"), "arcade.stick.console.fill"),
            (3, viewModel.tr("nav.personalize"), "paintpalette.fill"),
            (4, viewModel.tr("nav.settings"), "gearshape.fill")
        ]
        if viewModel.isDeveloperMode {
            items.append((5, viewModel.tr("nav.console"), "terminal.fill"))
        }
        return items
    }
    
    internal var isCompactNav: Bool {
        windowWidth < 1100
    }
    
    internal var useFloatingGlassBars: Bool {
        if #available(macOS 26.0, *) {
            return viewModel.isLiquidGlassEnabled && !reduceTransparency
        }
        return false
    }
    
    public var body: some View {
        Group {
            if menuBarManager.isMinimizedToMenuBar {
                Color.clear
                    .frame(width: 1, height: 1)
            } else {
                GeometryReader { windowGeo in
                    let winWidth = max(880, windowGeo.size.width)
                    let winHeight = max(620, windowGeo.size.height)

                    ZStack {
                        NXWindowGlassBackground(viewModel: viewModel)
                            .ignoresSafeArea()

                        atmosphericGlows(in: CGSize(width: winWidth, height: winHeight))

                        VStack(spacing: 0) {
                            ZStack(alignment: .top) {
                                selectedTabContent(containerHeight: max(560, winHeight - 48))
                                    .padding(.top, viewModel.selectedTab == 0 ? 0 : 58)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .clipped()

                                navigationHeader
                                    .frame(maxWidth: .infinity)
                                    .zIndex(10)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                            ControllerPromptBar(viewModel: viewModel)
                                .frame(maxWidth: .infinity)
                                .zIndex(10)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .id(viewModel.launcherLanguage)
                    }
                    .frame(width: winWidth, height: winHeight)
                    .onAppear {
                        self.windowWidth = winWidth
                        self.windowHeight = winHeight
                        self.animatedTabPill = viewModel.selectedTab
                    }
                    .onChange(of: winWidth) { newW in
                        self.windowWidth = newW
                    }
                    .onChange(of: winHeight) { newH in
                        self.windowHeight = newH
                    }
                    .onChange(of: viewModel.selectedTab) { newTab in
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.76, blendDuration: 0.10)) {
                            self.animatedTabPill = newTab
                        }
                    }
                }
            }
        }
        .frame(minWidth: 880, maxWidth: .infinity, minHeight: 620, maxHeight: .infinity)
        .environment(\.nxLiquidGlass, viewModel.liquidGlassEnvironment)
        .preferredColorScheme(.dark)
        .background(
            KeyboardNavBridge(viewModel: viewModel) { key in
                viewModel.handleKeyboardKey(key)
            }
        )
        .sheet(isPresented: $viewModel.showAboutSheet) {
            AboutLauncherView(viewModel: viewModel)
                .environment(\.nxLiquidGlass, viewModel.liquidGlassEnvironment)
        }
        .sheet(isPresented: $viewModel.showUpdateSheet) {
            LauncherUpdateSheet(viewModel: viewModel)
                .environment(\.nxLiquidGlass, viewModel.liquidGlassEnvironment)
        }
        .sheet(isPresented: $viewModel.showControlsGuideSheet) {
            UniversalControlsGuideView(viewModel: viewModel)
                .environment(\.nxLiquidGlass, viewModel.liquidGlassEnvironment)
        }
        .onChange(of: viewModel.selectedTab) { _ in
            DispatchQueue.main.async {
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
        }
    }
    
    @ViewBuilder
    private func atmosphericGlows(in size: CGSize) -> some View {
        let env = viewModel.liquidGlassEnvironment
        let primaryOpacity: Double = {
            if !viewModel.isLiquidGlassEnabled { return 0.14 }
            return env.mix(frosted: 0.17, liquid: 0.26)
        }()
        let secondaryOpacity: Double = {
            if !viewModel.isLiquidGlassEnabled { return 0.06 }
            return env.mix(frosted: 0.09, liquid: 0.16)
        }()
        let tertiaryOpacity: Double = {
            if !viewModel.isLiquidGlassEnabled { return 0.07 }
            return env.mix(frosted: 0.07, liquid: 0.12)
        }()
        
        ZStack {
            Circle()
                .fill(NXTheme.primary.opacity(primaryOpacity))
                .frame(width: 480, height: 480)
                .blur(radius: 95)
                .position(x: 120, y: 50)
            
            Circle()
                .fill(NXTheme.secondary.opacity(secondaryOpacity))
                .frame(width: 420, height: 420)
                .blur(radius: 110)
                .position(x: size.width * 0.52, y: 90)
            
            Circle()
                .fill(NXTheme.tertiary.opacity(tertiaryOpacity))
                .frame(width: 420, height: 420)
                .blur(radius: 105)
                .position(x: size.width - 80, y: size.height - 60)
        }
        .animation(.easeInOut(duration: 0.35), value: viewModel.highlightTheme)
        .animation(.easeInOut(duration: 0.30), value: viewModel.isLiquidGlassEnabled)
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
    
    @ViewBuilder
    private func selectedTabContent(containerHeight: CGFloat) -> some View {
        let libraryContainerHeight = containerHeight
        switch viewModel.selectedTab {
        case 0:
            LibraryView(viewModel: viewModel, containerHeight: libraryContainerHeight)
        case 1:
            CompatibilityView(viewModel: viewModel)
        case 2:
            ControlsView(viewModel: viewModel)
        case 3:
            PersonalizationView(viewModel: viewModel)
        case 4:
            SystemView(viewModel: viewModel)
        case 5:
            if viewModel.isDeveloperMode {
                LogsView(viewModel: viewModel)
            } else {
                LibraryView(viewModel: viewModel, containerHeight: libraryContainerHeight)
            }
        default:
            LibraryView(viewModel: viewModel, containerHeight: libraryContainerHeight)
        }
    }
}
