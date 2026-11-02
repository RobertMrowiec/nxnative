import SwiftUI

public struct PromptBarDockModifier: ViewModifier {
    public let useFloatingGlassDock: Bool
    
    public init(useFloatingGlassDock: Bool) {
        self.useFloatingGlassDock = useFloatingGlassDock
    }
    
    public func body(content: Content) -> some View {
        if useFloatingGlassDock {
            content.nxGlassBar(in: Capsule())
        } else {
            content
                .background(
                    ZStack {
                        NXTheme.canvasObsidian.opacity(0.85)
                        Rectangle().fill(.ultraThinMaterial)
                    }
                )
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(NXTheme.borderSubtle),
                    alignment: .top
                )
        }
    }
}
