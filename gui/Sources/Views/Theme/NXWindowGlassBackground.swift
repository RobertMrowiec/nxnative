import SwiftUI
import AppKit

public struct NXVisualEffectBackground: NSViewRepresentable {
    public let material: NSVisualEffectView.Material
    public let blendingMode: NSVisualEffectView.BlendingMode
    public let state: NSVisualEffectView.State

    public init(
        material: NSVisualEffectView.Material = .underWindowBackground,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .active
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

public struct WindowTransparencyConfigurator: NSViewRepresentable {
    public let isTransparent: Bool

    public init(isTransparent: Bool) {
        self.isTransparent = isTransparent
    }

    public func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            apply(to: view.window)
        }
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            apply(to: nsView.window)
        }
    }

    private func apply(to window: NSWindow?) {
        guard let window = window else { return }
        if isTransparent {
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
        } else {
            window.isOpaque = true
            window.backgroundColor = NSColor(red: 0x14 / 255.0, green: 0x14 / 255.0, blue: 0x18 / 255.0, alpha: 1.0)
        }
    }
}

public struct NXWindowGlassBackground: View {
    @ObservedObject public var viewModel: AppViewModel

    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            WindowTransparencyConfigurator(isTransparent: viewModel.isLiquidGlassEnabled)

            if viewModel.isLiquidGlassEnabled {
                let isLiquid = viewModel.liquidGlassIntensity > 0.4
                NXVisualEffectBackground(
                    material: isLiquid ? .underWindowBackground : .sidebar,
                    blendingMode: .behindWindow,
                    state: .active
                )
                
                Color.nxCanvas
                    .opacity(isLiquid ? 0.38 : 0.72)
            } else {
                Color.nxCanvas
            }
        }
        .animation(.easeInOut(duration: 0.30), value: viewModel.isLiquidGlassEnabled)
        .animation(.easeInOut(duration: 0.30), value: viewModel.liquidGlassIntensity)
    }
}
