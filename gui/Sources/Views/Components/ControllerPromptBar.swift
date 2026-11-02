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
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .modifier(PromptBarDockModifier(useFloatingGlassDock: useFloatingGlassDock))
        }
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

    private func compactPadName(_ raw: String) -> String {
        let trimmed = raw.replacingOccurrences(of: "Wireless Controller", with: "")
            .replacingOccurrences(of: "Controller", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Pad" : trimmed
    }
    
    // MARK: - Controller Prompts
    @ViewBuilder
    private var controllerPromptsForCurrentContext: some View {
        let isPS = controllerService.activeBrand == .playstation
        let confirmBtn = isPS ? "✕" : "A"
        let cancelBtn = isPS ? "○" : "B"
        let xBtn = isPS ? "□" : "X"
        let yBtn = isPS ? "△" : "Y"
        let optionsBtn = controllerService.activeBrand == .xbox ? "⧉" : (isPS ? "OPT" : "−")
        
        if viewModel.gameForSettingsSheet != nil {
            controllerPill(glyph: confirmBtn, action: "Adjust", color: brandAColor)
            controllerPill(glyph: cancelBtn, action: "Done", color: brandBColor)
            dpadPill(glyph: "↑/↓", action: "Navigate")
            dpadPill(glyph: "←/→", action: "Change")
        } else {
            switch viewModel.selectedTab {
            case 0: // My Games
            if viewModel.isGameActionMenuPresented {
                controllerPill(glyph: confirmBtn, action: "Execute", color: brandAColor)
                controllerPill(glyph: cancelBtn, action: "Close", color: brandBColor)
                dpadPill(glyph: "↑/↓", action: "Navigate")
            } else if viewModel.isBuilding && viewModel.activeLibraryShelf == .unportedSwitch && (viewModel.buildingGameId == viewModel.focusedUnportedGame?.id || viewModel.selectedGame?.id == viewModel.focusedUnportedGame?.id) {
                controllerPill(glyph: cancelBtn, action: viewModel.tr("library.cancel_port"), color: Color.red)
                dpadPill(glyph: "←/→", action: "Browse")
            } else {
                let isIOS = viewModel.currentFocusedGame?.platform == .ios
                if isIOS {
                    controllerPill(glyph: confirmBtn, action: "Install / Options", color: brandAColor)
                } else {
                    playPromptPill(aGlyph: confirmBtn, xGlyph: xBtn)
                }
                optionsPill(glyph: optionsBtn, action: "Game Options")
                dpadPill(glyph: "←/→", action: "Browse")
                controllerPill(glyph: yBtn, action: "Saves", color: brandYColor)
            }
            
        case 1: // Compatibility
            if viewModel.compatibilityFocusArea == .filters {
                dpadPill(glyph: "←/→", action: "Filter")
                dpadPill(glyph: "↓", action: "Games")
                controllerPill(glyph: confirmBtn, action: "Select", color: brandAColor)
            } else {
                dpadPill(glyph: "↑/↓", action: "Browse")
                controllerPill(glyph: confirmBtn, action: "View Notes", color: brandAColor)
                controllerPill(glyph: cancelBtn, action: "Filters", color: brandBColor)
            }
            
        case 2: // Controls
            if viewModel.isInsideControlsCard {
                controllerPill(glyph: confirmBtn, action: "Select / Rebind", color: brandAColor)
                controllerPill(glyph: cancelBtn, action: "Back to Cards", color: brandBColor)
                dpadPill(glyph: "↑/↓/←/→", action: "Navigate")
                controllerPill(glyph: yBtn, action: "Test Rumble", color: brandYColor)
            } else {
                controllerPill(glyph: confirmBtn, action: "Enter Card", color: brandAColor)
                dpadPill(glyph: "↑/↓", action: "Select Card")
                controllerPill(glyph: yBtn, action: "Test Rumble", color: brandYColor)
            }
            
        case 3: // Personalize
            if viewModel.isInsidePersonalizeCard {
                controllerPill(glyph: confirmBtn, action: "Apply / Toggle", color: brandAColor)
                controllerPill(glyph: cancelBtn, action: "Back to Cards", color: brandBColor)
                dpadPill(glyph: "↑/↓/←/→", action: "Adjust")
            } else {
                controllerPill(glyph: confirmBtn, action: "Enter Card", color: brandAColor)
                dpadPill(glyph: "↑/↓", action: "Select Card")
                controllerPill(
                    glyph: xBtn,
                    action: viewModel.tr(viewModel.isLiquidGlassEnabled ? "personalization.liquid_glass_on" : "personalization.liquid_glass_off"),
                    color: brandXColor
                )
            }
            
        case 4: // Settings
            controllerPill(glyph: confirmBtn, action: "Select / Open", color: brandAColor)
            dpadPill(glyph: "↑/↓", action: "Navigate")
            controllerPill(glyph: xBtn, action: "Check Updates", color: brandXColor)
            controllerPill(glyph: yBtn, action: "Repair Tools", color: brandYColor)
            
        case 5: // Console / Logs
            controllerPill(glyph: xBtn, action: "Copy", color: brandXColor)
            controllerPill(glyph: yBtn, action: "Clear", color: brandBColor)
            
        default:
            EmptyView()
        }
        }
    }
    
    // MARK: - Keyboard Prompts (When no controller is connected)
    @ViewBuilder
    private var keyboardPromptsForCurrentContext: some View {
        if viewModel.gameForSettingsSheet != nil {
            keyboardKeyBadge(glyph: "↑/↓", action: "Navigate")
            keyboardKeyBadge(glyph: "←/→", action: "Change")
            keyboardKeyBadge(glyph: "↵ Enter", action: "Adjust")
            keyboardKeyBadge(glyph: "⎋ Esc", action: "Done")
        } else {
            switch viewModel.selectedTab {
            case 0: // My Games
            if viewModel.isGameActionMenuPresented {
                keyboardKeyBadge(glyph: "↑/↓", action: "Navigate")
                keyboardKeyBadge(glyph: "↵ Enter", action: "Execute")
                keyboardKeyBadge(glyph: "⎋ Esc", action: "Close")
            } else if viewModel.isBuilding && viewModel.activeLibraryShelf == .unportedSwitch && (viewModel.buildingGameId == viewModel.focusedUnportedGame?.id || viewModel.selectedGame?.id == viewModel.focusedUnportedGame?.id) {
                keyboardKeyBadge(glyph: "⎋ Esc", action: viewModel.tr("library.cancel_port"))
                keyboardKeyBadge(glyph: "← / →", action: "Browse")
            } else {
                let isIOS = viewModel.currentFocusedGame?.platform == .ios
                keyboardKeyBadge(glyph: "← / →", action: "Browse")
                keyboardKeyBadge(glyph: "↵ Enter", action: isIOS ? "Install / Options" : "Play")
                keyboardKeyBadge(glyph: "O", action: "Options")
                keyboardKeyBadge(glyph: ",", action: "Settings")
            }
            
        case 1: // Compatibility
            if viewModel.compatibilityFocusArea == .filters {
                keyboardKeyBadge(glyph: "← / →", action: "Filter")
                keyboardKeyBadge(glyph: "↓", action: "Browse Games")
            } else {
                keyboardKeyBadge(glyph: "↑/↓", action: "Browse")
                keyboardKeyBadge(glyph: "↵ Enter", action: "View Notes")
                keyboardKeyBadge(glyph: "⎋ Esc", action: "Filters")
            }
            keyboardKeyBadge(glyph: "R", action: "Refresh")
            
        case 2: // Controls
            keyboardKeyBadge(glyph: "Space", action: "Calibrate")
            
        case 3: // Personalize
            keyboardKeyBadge(glyph: "← / →", action: "Highlight Color")
            keyboardKeyBadge(
                glyph: "G",
                action: viewModel.tr(viewModel.isLiquidGlassEnabled ? "personalization.liquid_glass_on" : "personalization.liquid_glass_off")
            )
            keyboardKeyBadge(
                glyph: "M",
                action: viewModel.tr(viewModel.liquidGlassAppearance.titleLocalizationKey)
            )
            
        case 4: // Settings
            keyboardKeyBadge(glyph: "I", action: "Install Tools")
            keyboardKeyBadge(glyph: "U", action: "Check Updates")
            
        case 5: // Console
            keyboardKeyBadge(glyph: "C", action: "Copy Logs")
            keyboardKeyBadge(glyph: "K", action: "Clear")
            
        default:
            EmptyView()
        }
        }
    }
}

