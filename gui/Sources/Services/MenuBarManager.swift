import Foundation
import AppKit
import SwiftUI

@MainActor
public final class MenuBarManager: NSObject, ObservableObject, NSMenuDelegate {
    public static let shared = MenuBarManager()

    nonisolated static let stateLock = NSLock()
    nonisolated(unsafe) private static var _isMinimizedRaw: Bool = false
    public nonisolated static var isMinimized: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _isMinimizedRaw
    }

    internal var statusItem: NSStatusItem?
    internal weak var mainWindow: NSWindow?
    internal weak var viewModel: AppViewModel?

    @Published public private(set) var isMinimizedToMenuBar: Bool = false

    private override init() {
        super.init()
    }

    public func configure(with viewModel: AppViewModel) {
        self.viewModel = viewModel
        setupStatusItem()
        observeWindows()
        setupNotificationObservers()
    }

    public var currentIconStyle: MenuBarIconStyle {
        get {
            if let vm = viewModel {
                return vm.menuBarIconStyle
            }
            if let saved = UserDefaults.standard.string(forKey: AppViewModel.StorageKeys.savedMenuBarIconStyle),
               let style = MenuBarIconStyle(rawValue: saved) {
                return style
            }
            return .matchAppIcon
        }
        set {
            if let vm = viewModel {
                vm.menuBarIconStyle = newValue
            } else {
                UserDefaults.standard.set(newValue.rawValue, forKey: AppViewModel.StorageKeys.savedMenuBarIconStyle)
                updateMenuBarIcon(style: newValue)
            }
        }
    }

    public func updateMenuBarIcon(style: MenuBarIconStyle? = nil) {
        let activeStyle = style ?? currentIconStyle
        if let button = statusItem?.button {
            button.image = createMenuBarIcon(style: activeStyle)
            button.imagePosition = .imageOnly
        }
    }

    private func setupStatusItem() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = createMenuBarIcon(style: currentIconStyle)
            button.imagePosition = .imageOnly
            button.toolTip = "NxNative Launcher"
        }

        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        self.statusItem = item
    }

    private func observeWindows() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            if let win = NSApplication.shared.windows.first(where: { $0.canBecomeMain && $0.isVisible }) {
                self.registerMainWindow(win)
            }
        }
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            Task { @MainActor [weak self] in
                guard let self = self, let win = notif.object as? NSWindow else { return }
                if win.canBecomeMain && !(win is NSPanel) {
                    self.registerMainWindow(win)
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSWindow.willMiniaturizeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            Task { @MainActor [weak self] in
                guard let self = self, let win = notif.object as? NSWindow else { return }
                if win === self.mainWindow || self.mainWindow == nil {
                    self.minimizeToMenuBar()
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.isMinimizedToMenuBar || !(self.viewModel?.isBuilding ?? false) {
                    MemoryOptimizer.shared.scheduleIdleOptimization(viewModel: self.viewModel, delay: 5.0)
                }
            }
        }
    }

    public func registerMainWindow(_ window: NSWindow) {
        guard self.mainWindow !== window else { return }
        self.mainWindow = window
        // Never assign `window.delegate = self` on a SwiftUI WindowGroup NSWindow:
        // doing so replaces SwiftUI.AppKitWindowController and drops resize/restoration
        // layout invalidations on launch. Minimization is intercepted safely via the
        // traffic-light button action below and NSWindow.willMiniaturizeNotification.
        if let miniBtn = window.standardWindowButton(.miniaturizeButton) {
            miniBtn.target = self
            miniBtn.action = #selector(handleMiniaturizeButtonClick)
        }
    }

    @objc private func handleMiniaturizeButtonClick() {
        minimizeToMenuBar()
    }

    // MARK: - Menu Bar Actions
    public func minimizeToMenuBar() {
        guard !isMinimizedToMenuBar else { return }
        isMinimizedToMenuBar = true
        Self.stateLock.lock()
        Self._isMinimizedRaw = true
        Self.stateLock.unlock()

        if let win = mainWindow ?? NSApplication.shared.windows.first(where: { $0.canBecomeMain }) {
            self.mainWindow = win
            win.orderOut(nil)
        }

        NSApplication.shared.setActivationPolicy(.accessory)
        MemoryOptimizer.shared.optimizeForBackground(viewModel: viewModel)
    }

    public func restoreMainWindow() {
        isMinimizedToMenuBar = false
        Self.stateLock.lock()
        Self._isMinimizedRaw = false
        Self.stateLock.unlock()

        NSApplication.shared.setActivationPolicy(.regular)
        viewModel?.updateDockIcon()

        let win = mainWindow ?? NSApplication.shared.windows.first(where: { $0.canBecomeMain })
        win?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    public func toggleMainWindow() {
        if isMinimizedToMenuBar || !(mainWindow?.isVisible ?? false) {
            restoreMainWindow()
        } else {
            minimizeToMenuBar()
        }
    }

    // MARK: - NSMenuDelegate
    public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let (statusTitle, statusImageName): (String, String) = {
            if let vm = viewModel, vm.isBuilding {
                let pct = Int(vm.progressFraction * 100)
                let gameTitle = vm.appName.isEmpty ? (vm.selectedGame?.name ?? "Game") : vm.appName
                return (L10n.t("menubar.status_building", gameTitle, pct), "gearshape.arrow.triangle.2.circlepath")
            } else if let vm = viewModel, let activeGame = vm.runningGameTitle {
                return (L10n.t("menubar.status_playing", activeGame), "play.circle.fill")
            }
            return (L10n.t("menubar.status_idle"), "leaf.fill")
        }()

        let statusItem = makeMenuItem(statusTitle, symbol: statusImageName)
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        menu.addItem(.separator())

        menu.addItem(makeMenuItem(L10n.t("menubar.open"), symbol: "arrow.up.forward.app.fill", action: #selector(handleOpenLauncher), key: "o"))
        if !isMinimizedToMenuBar && (mainWindow?.isVisible ?? false) {
            menu.addItem(makeMenuItem(L10n.t("menubar.minimize"), symbol: "menubar.arrow.up.rectangle", action: #selector(handleMinimizeToMenuBar), key: "m"))
        }
        menu.addItem(.separator())

        let quickPlayMenu = NSMenu()
        let macGames = viewModel?.macLibraryGames ?? []
        if macGames.isEmpty {
            let empty = NSMenuItem(title: L10n.t("menubar.no_games"), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            quickPlayMenu.addItem(empty)
        } else {
            for (idx, game) in macGames.prefix(8).enumerated() {
                let gameItem = makeMenuItem(game.name, symbol: "gamecontroller", action: #selector(handleQuickPlay(_:)), key: idx < 9 ? "\(idx + 1)" : "")
                gameItem.representedObject = game
                quickPlayMenu.addItem(gameItem)
            }
        }
        let quickPlayParent = makeMenuItem(L10n.t("menubar.quick_play"), symbol: "play.fill")
        quickPlayParent.submenu = quickPlayMenu
        menu.addItem(quickPlayParent)
        menu.addItem(.separator())

        let iconStyleMenu = NSMenu()
        let styles: [(MenuBarIconStyle, String)] = [
            (.matchAppIcon, L10n.t("menubar.icon_style_match")),
            (.symbol, L10n.t("menubar.icon_style_symbol")),
            (.dark, L10n.t("menubar.icon_style_dark")),
            (.lightColor, L10n.t("menubar.icon_style_light_color"))
        ]
        for (style, title) in styles {
            let item = NSMenuItem(title: title, action: #selector(handleSelectIconStyle(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = style.rawValue
            item.state = (currentIconStyle == style) ? .on : .off
            item.image = createMenuBarIcon(style: style)
            iconStyleMenu.addItem(item)
        }
        let iconStyleParent = makeMenuItem(L10n.t("menubar.icon_style"), symbol: "app.badge")
        iconStyleParent.submenu = iconStyleMenu
        menu.addItem(iconStyleParent)
        menu.addItem(.separator())

        menu.addItem(makeMenuItem(L10n.t("menubar.free_memory"), symbol: "memorychip", action: #selector(handleFreeMemory)))
        menu.addItem(.separator())
        menu.addItem(makeMenuItem(L10n.t("menubar.quit"), symbol: "power", action: #selector(handleQuit), key: "q"))
    }

    private func makeMenuItem(_ title: String, symbol: String, action: Selector? = nil, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        if action != nil { item.target = self }
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        return item
    }

    @objc private func handleSelectIconStyle(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let style = MenuBarIconStyle(rawValue: raw) else { return }
        SoundEffectService.shared.play(.click)
        self.currentIconStyle = style
    }

    @objc private func handleOpenLauncher() { restoreMainWindow() }
    @objc private func handleMinimizeToMenuBar() { minimizeToMenuBar() }

    @objc private func handleQuickPlay(_ sender: NSMenuItem) {
        guard let game = sender.representedObject as? PortedGame, let vm = viewModel else { return }
        vm.launchGame(game)
    }

    @objc private func handleFreeMemory() { MemoryOptimizer.shared.optimizeForBackground(viewModel: viewModel) }
    @objc private func handleQuit() { NSApplication.shared.terminate(nil) }
}
