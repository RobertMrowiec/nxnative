import Foundation
import AppKit
import SwiftUI

/// Live, authoritative viewport metrics synchronized 1:1 with the AppKit `NSWindow` content view.
@MainActor
public final class NXWindowViewport: ObservableObject {
    public static let shared = NXWindowViewport()

    @Published public private(set) var size: CGSize = CGSize(width: 1280, height: 800)
    @Published public private(set) var backingScaleFactor: CGFloat = NSScreen.main?.backingScaleFactor ?? 2.0

    private init() {}

    public func update(size newSize: CGSize, backingScaleFactor newScale: CGFloat) {
        guard newSize.width > 1, newSize.height > 1 else { return }
        let clampedSize = CGSize(
            width: max(NXMainWindowController.minContentSize.width, newSize.width),
            height: max(NXMainWindowController.minContentSize.height, newSize.height)
        )
        if abs(self.size.width - clampedSize.width) > 0.25 || abs(self.size.height - clampedSize.height) > 0.25 {
            self.size = clampedSize
        }
        if abs(self.backingScaleFactor - newScale) > 0.01 {
            self.backingScaleFactor = newScale
        }
    }
}

private struct NXHostedRootView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        MainView(viewModel: viewModel)
            .frame(
                minWidth: NXMainWindowController.minContentSize.width,
                maxWidth: .infinity,
                minHeight: NXMainWindowController.minContentSize.height,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .preferredColorScheme(.dark)
    }
}

/// Deterministic AppKit owner of the primary `NSWindow` and `NSHostingController`.
/// Eliminates `SwiftUI.WindowGroup`'s `intrinsicContentSize` clamping and restoration races
/// so Frame 0 and all live resizes always fill 100% of the window.
@MainActor
public final class NXMainWindowController: NSObject, NSWindowDelegate {
    public static weak var shared: NXMainWindowController?

    public static let autosaveName = "NXNativeMainWindow"
    public static let minContentSize = NSSize(width: 880, height: 620)
    public static let defaultContentSize = NSSize(width: 1280, height: 800)

    public let window: NSWindow
    private let hostingController: NSHostingController<NXHostedRootView>

    public init(viewModel: AppViewModel) {
        let initialContentRect = NSRect(origin: .zero, size: Self.defaultContentSize)
        let win = NSWindow(
            contentRect: initialContentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "NxNative Launcher"
        win.toolbarStyle = .unifiedCompact
        win.appearance = NSAppearance(named: .darkAqua)
        win.contentMinSize = Self.minContentSize
        win.collectionBehavior.insert(.fullScreenPrimary)
        win.tabbingMode = .disallowed
        win.isReleasedWhenClosed = false

        Self.applyWindowTransparency(to: win, isTransparent: viewModel.isLiquidGlassEnabled)

        let resolvedFrame = Self.resolveInitialWindowFrame(for: win)
        let initialContentSize = win.contentRect(forFrameRect: resolvedFrame).size

        // Publish exact content dimensions BEFORE mounting SwiftUI so Frame 0 renders at 100% window scale.
        NXWindowViewport.shared.update(
            size: initialContentSize,
            backingScaleFactor: win.backingScaleFactor
        )

        let hc = NSHostingController(rootView: NXHostedRootView(viewModel: viewModel))
        hc.sizingOptions = []
        hc.view.translatesAutoresizingMaskIntoConstraints = true
        hc.view.frame = NSRect(origin: .zero, size: initialContentSize)

        win.contentViewController = hc
        hc.view.autoresizingMask = [.width, .height]
        hc.view.postsFrameChangedNotifications = true
        hc.view.postsBoundsChangedNotifications = true

        win.contentMinSize = Self.minContentSize
        win.setFrame(resolvedFrame, display: false)
        win.setFrameAutosaveName(Self.autosaveName)
        win.saveFrame(usingName: Self.autosaveName)

        hc.view.wantsLayer = true
        hc.view.layer?.contentsScale = win.backingScaleFactor
        hc.view.needsLayout = true
        hc.view.layoutSubtreeIfNeeded()

        self.window = win
        self.hostingController = hc
        super.init()

        Self.shared = self
        win.delegate = self

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHostingViewFrameDidChange(_:)),
            name: NSView.frameDidChangeNotification,
            object: hc.view
        )

        MenuBarManager.shared.registerMainWindow(win)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public func presentMainWindow() {
        synchronizeViewportImmediately(forceLayout: true)
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)

        DispatchQueue.main.async { [weak self] in
            self?.synchronizeViewportImmediately(forceLayout: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.synchronizeViewportImmediately(forceLayout: true)
        }
    }

    public func synchronizeViewportImmediately(forceLayout: Bool = false) {
        guard !MenuBarManager.shared.isMinimizedToMenuBar else { return }

        let hostingView = hostingController.view
        let targetContentSize: NSSize
        if window.contentView === hostingView {
            if hostingView.bounds.origin != .zero {
                hostingView.setBoundsOrigin(.zero)
            }
            targetContentSize = hostingView.bounds.size
        } else if let container = window.contentView {
            if hostingView.frame != container.bounds {
                hostingView.frame = container.bounds
            }
            targetContentSize = container.bounds.size
        } else {
            targetContentSize = window.contentRect(forFrameRect: window.frame).size
        }

        guard targetContentSize.width > 1, targetContentSize.height > 1 else { return }

        if let layer = hostingView.layer, abs(layer.contentsScale - window.backingScaleFactor) > 0.01 {
            layer.contentsScale = window.backingScaleFactor
        }

        NXWindowViewport.shared.update(
            size: targetContentSize,
            backingScaleFactor: window.backingScaleFactor
        )

        if forceLayout {
            hostingView.needsLayout = true
            hostingView.layoutSubtreeIfNeeded()
        }
    }

    public static func applyWindowTransparency(to window: NSWindow?, isTransparent: Bool) {
        guard let window = window else { return }
        if isTransparent {
            if window.isOpaque {
                window.isOpaque = false
            }
            if window.backgroundColor != .clear {
                window.backgroundColor = .clear
            }
            if !window.hasShadow {
                window.hasShadow = true
            }
        } else {
            let opaqueBg = NSColor(red: 0x14 / 255.0, green: 0x14 / 255.0, blue: 0x18 / 255.0, alpha: 1.0)
            if !window.isOpaque {
                window.isOpaque = true
            }
            if window.backgroundColor != opaqueBg {
                window.backgroundColor = opaqueBg
            }
        }
    }

    // MARK: - Initial & Migrated Frame Resolution

    private static func resolveInitialWindowFrame(for window: NSWindow) -> NSRect {
        let defaults = UserDefaults.standard
        let autosaveKey = "NSWindow Frame \(autosaveName)"
        var restored = false

        if let saved = defaults.string(forKey: autosaveKey), !saved.isEmpty {
            window.setFrame(from: saved)
            restored = true
        } else if let legacyFrameString = findLegacyWindowGroupFrame(in: defaults) {
            window.setFrame(from: legacyFrameString)
            restored = true
        }

        let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let minFrameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: minContentSize)).size

        if !restored {
            let defaultFrameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: defaultContentSize)).size
            let width = min(max(defaultFrameSize.width, minFrameSize.width), visibleFrame.width)
            let height = min(max(defaultFrameSize.height, minFrameSize.height), visibleFrame.height)
            let originX = visibleFrame.origin.x + floor((visibleFrame.width - width) * 0.5)
            let originY = visibleFrame.origin.y + floor((visibleFrame.height - height) * 0.5)
            return NSRect(x: originX, y: originY, width: width, height: height)
        }

        var frame = window.frame
        frame.size.width = min(max(frame.size.width, minFrameSize.width), visibleFrame.width)
        frame.size.height = min(max(frame.size.height, minFrameSize.height), visibleFrame.height)

        if frame.maxX > visibleFrame.maxX {
            frame.origin.x = visibleFrame.maxX - frame.size.width
        }
        if frame.minX < visibleFrame.minX {
            frame.origin.x = visibleFrame.minX
        }
        if frame.maxY > visibleFrame.maxY {
            frame.origin.y = visibleFrame.maxY - frame.size.height
        }
        if frame.minY < visibleFrame.minY {
            frame.origin.y = visibleFrame.minY
        }

        return frame
    }

    private static func findLegacyWindowGroupFrame(in defaults: UserDefaults) -> String? {
        let preferredLegacyKeys = [
            "NSWindow Frame SwiftUI.WindowGroup<SwiftUI.ModifiedContent<SwiftUI.ModifiedContent<NXNativeGUI.MainView, SwiftUI._FlexFrameLayout>, SwiftUI._PreferenceWritingModifier<SwiftUI.PreferredColorSchemeKey>>>-1-AppWindow-1",
            "NSWindow Frame SwiftUI.WindowGroup<SwiftUI.ModifiedContent<NXNativeGUI.MainView, SwiftUI._PreferenceWritingModifier<SwiftUI.PreferredColorSchemeKey>>>-1-AppWindow-1",
            "NSWindow Frame SwiftUI.WindowGroup<NXNativeGUI.MainView>-1-AppWindow-1"
        ]
        for key in preferredLegacyKeys {
            if let val = defaults.string(forKey: key), !val.trimmingCharacters(in: .whitespaces).isEmpty {
                return val
            }
        }

        let allEntries = defaults.dictionaryRepresentation()
        for (key, value) in allEntries where key.hasPrefix("NSWindow Frame SwiftUI.WindowGroup") {
            if let str = value as? String, !str.trimmingCharacters(in: .whitespaces).isEmpty {
                return str
            }
        }
        return nil
    }

    // MARK: - Notifications & NSWindowDelegate

    @objc private func handleHostingViewFrameDidChange(_ notification: Notification) {
        synchronizeViewportImmediately(forceLayout: false)
    }

    public func windowDidResize(_ notification: Notification) {
        synchronizeViewportImmediately(forceLayout: false)
    }

    public func windowDidEndLiveResize(_ notification: Notification) {
        synchronizeViewportImmediately(forceLayout: true)
    }

    public func windowDidEnterFullScreen(_ notification: Notification) {
        synchronizeViewportImmediately(forceLayout: true)
    }

    public func windowDidExitFullScreen(_ notification: Notification) {
        synchronizeViewportImmediately(forceLayout: true)
    }

    public func windowDidChangeBackingProperties(_ notification: Notification) {
        synchronizeViewportImmediately(forceLayout: true)
    }

    public func windowDidChangeScreen(_ notification: Notification) {
        synchronizeViewportImmediately(forceLayout: true)
    }

    public func windowDidBecomeKey(_ notification: Notification) {
        synchronizeViewportImmediately(forceLayout: false)
    }

    public func windowWillMiniaturize(_ notification: Notification) {
        MenuBarManager.shared.minimizeToMenuBar()
    }
}
