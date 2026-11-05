import SwiftUI

public struct ControllerPromptBar: View {
    @ObservedObject var controllerService = GameControllerService.shared
    @ObservedObject public var viewModel: AppViewModel
    @Environment(\.nxLiquidGlass) private var glassEnv
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    private var useFloatingGlassDock: Bool {
        glassEnv.isSupportedAndEnabled && !reduceTransparency
    }
    
    public var body: some View {
        NXGlassContainer(spacing: 10) {
            HStack(spacing: 16) {
                // Connected status badge (Gamepad or Keyboard)
                statusBadge
                
                Spacer()
                
                // Dynamic context-sensitive Action button prompts
                if controllerService.isGamepadConnected {
                    HStack(spacing: 14) {
                        controllerPromptsForCurrentContext
                        
                        // Shoulder bumper prompt for Tabs
                        shoulderTabsPromptView
                    }
                    .transaction { $0.animation = nil }
                } else {
                    // Keyboard shortcuts when no gamepad is connected
                    HStack(spacing: 12) {
                        keyboardPromptsForCurrentContext
                        
                        keyboardKeyBadge(glyph: "1-7", action: viewModel.tr("controls.tabs"))
                    }
                    .transaction { $0.animation = nil }
                }
                
                // Card size slider attached to the bottom bar as the first option from right to left
                if viewModel.selectedTab == 0 {
                    cardScaleSliderView
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .modifier(PromptBarDockModifier(useFloatingGlassDock: useFloatingGlassDock))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, useFloatingGlassDock ? 14 : 0)
        .padding(.bottom, useFloatingGlassDock ? 8 : 0)
        .padding(.top, useFloatingGlassDock ? 2 : 0)
    }
    
    // MARK: - Status Badge
    private var statusBadge: some View {
        HStack(spacing: 8) {
            if controllerService.isGamepadConnected {
                let controllers = controllerService.connectedControllers
                if controllers.count > 1 {
                    HStack(spacing: 8) {
                        ForEach(controllers, id: \.playerIndex) { ctrl in
                            HStack(spacing: 4) {
                                Image(systemName: "gamecontroller.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(red: 0.13, green: 0.77, blue: 0.37))
                                Text("P\(ctrl.playerIndex + 1): \(compactPadName(ctrl.name))")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundColor(NXTheme.textPrimary)
                                    .lineLimit(1)
                            }
                            if ctrl.playerIndex < controllers.count - 1 {
                                Text("•")
                                    .font(.system(size: 8))
                                    .foregroundColor(.white.opacity(0.3))
                            }
                        }
                    }
                } else {
                    HStack(spacing: 5) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(red: 0.13, green: 0.77, blue: 0.37))
                        Text("P1: \(compactPadName(controllerService.activeControllerName))")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(NXTheme.textPrimary)
                            .lineLimit(1)
                    }
                }
            } else {
                HStack(spacing: 5) {
                    Image(systemName: "keyboard.fill")
                        .font(.system(size: 11))
                        .foregroundColor(NXTheme.secondary)
                    Text(viewModel.tr("controls.keyboard_controls"))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(NXTheme.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(
                    controllerService.isGamepadConnected
                        ? NXTheme.primary.opacity(0.24)
                        : Color.white.opacity(useFloatingGlassDock ? 0.08 : 0.05)
                )
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    controllerService.isGamepadConnected
                        ? NXTheme.secondary.opacity(0.45)
                        : Color.white.opacity(0.14),
                    lineWidth: 0.8
                )
        )
    }

    // MARK: - Card Scale Slider View (My Games Tab)
    private var cardScaleSliderView: some View {
        HStack(spacing: 6) {
            Image(systemName: "minus.magnifyingglass")
                .font(.system(size: 9.5, weight: .bold))
                .foregroundColor(.white.opacity(0.85))
            
            NXLiquidGlassSlider(
                value: $viewModel.libraryCardScale,
                in: 0.70...1.50,
                step: 0.05,
                accentColor: NXTheme.primary
            )
            .frame(width: 86)
            
            Image(systemName: "plus.magnifyingglass")
                .font(.system(size: 9.5, weight: .bold))
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .nxGlassBar(
            in: Capsule(),
            fallbackFill: NXTheme.glassSurfaceElevated.opacity(0.75),
            fallbackStroke: NXTheme.borderSubtle
        )
    }

    private func compactPadName(_ raw: String) -> String {
        let trimmed = raw.replacingOccurrences(of: "Wireless Controller", with: "")
            .replacingOccurrences(of: "Controller", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Pad" : trimmed
    }
}

