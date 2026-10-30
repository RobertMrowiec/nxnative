import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Subviews and Card Helpers for GameSettingsSheetView
extension GameSettingsSheetView {
    
    func controllerProfileSection(rowIndex: Int) -> some View {
        let isRowFocused = viewModel.settingsModalFocusIndex == rowIndex
        let selectedId = viewModel.activeSettingsConfig.controllerProfileId
        let selectedProfile = selectedId.flatMap { idStr in
            UUID(uuidString: idStr).flatMap { uuid in
                profileManager.profiles.first(where: { $0.id == uuid })
            }
        }
        let globalLabel = String(format: viewModel.tr("settings_modal.controller_profile_global"), profileManager.activeProfile.name)
        let currentLabel = selectedProfile?.name ?? globalLabel

        return settingCard(
            rowIndex: rowIndex,
            title: viewModel.tr("settings_modal.controller_profile_title"),
            icon: "gamecontroller.fill",
            iconColor: Color(red: 0.58, green: 0.42, blue: 1.0)
        ) {
            HStack(alignment: .center, spacing: 12) {
                Text(viewModel.tr("settings_modal.controller_profile_desc"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isRowFocused ? .white : .white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer(minLength: 12)
                
                Menu {
                    Button(action: {
                        SoundEffectService.shared.play(.click)
                        viewModel.activeSettingsConfig.controllerProfileId = nil
                    }) {
                        if selectedProfile == nil {
                            Label(globalLabel, systemImage: "checkmark")
                        } else {
                            Text(globalLabel)
                        }
                    }
                    Divider()
                    ForEach(profileManager.profiles) { prof in
                        Button(action: {
                            SoundEffectService.shared.play(.click)
                            viewModel.activeSettingsConfig.controllerProfileId = prof.id.uuidString
                        }) {
                            if selectedProfile?.id == prof.id {
                                Label(prof.name, systemImage: "checkmark")
                            } else {
                                Text(prof.name)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)

                        Text(currentLabel)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .contentShape(Capsule())
                    .nxGlassInteractive(
                        in: Capsule(),
                        fallbackFill: NXTheme.glassSurfaceElevated
                    )
                }
                .menuStyle(.button)
                .buttonStyle(NXPressableButtonStyle())
                .menuIndicator(.hidden)
                .fixedSize()
                .nxNoFocusRing()
            }
        }
    }
    
    func footerBar(onDismiss: @escaping () -> Void) -> some View {
        let footerContent = VStack(spacing: 10) {
            NXGlassContainer(spacing: 10) {
                HStack(spacing: 12) {
                    Button(viewModel.tr("personalization.reset_defaults")) {
                        viewModel.activeSettingsConfig = GameRuntimeConfig()
                    }
                    .buttonStyle(NXSecondaryButtonStyle())
                    .controlSize(.regular)
                    .overlay(
                        Capsule()
                            .stroke(viewModel.settingsModalFocusIndex == 7 ? NXTheme.secondary : Color.clear, lineWidth: 2)
                    )
                    
                    Spacer()
                    
                    Button(viewModel.tr("common.cancel")) {
                        viewModel.gameForSettingsSheet = nil
                        onDismiss()
                    }
                    .buttonStyle(NXSecondaryButtonStyle())
                    .controlSize(.regular)
                    .overlay(
                        Capsule()
                            .stroke(viewModel.settingsModalFocusIndex == 8 ? NXTheme.secondary : Color.clear, lineWidth: 2)
                    )
                    
                    Button(viewModel.tr("common.save")) {
                        viewModel.saveRuntimeConfig(viewModel.activeSettingsConfig, for: game)
                        viewModel.gameForSettingsSheet = nil
                        onDismiss()
                    }
                    .buttonStyle(NXPrimaryButtonStyle())
                    .controlSize(.regular)
                    .overlay(
                        Capsule()
                            .stroke(viewModel.settingsModalFocusIndex == 9 ? Color.white : Color.clear, lineWidth: 2)
                    )
                    .shadow(color: viewModel.settingsModalFocusIndex == 9 ? NXTheme.primary.opacity(0.8) : Color.clear, radius: 8)
                }
            }
            
            // Controller navigation hints strip
            HStack(spacing: 12) {
                hintBadge(glyph: "↑/↓", text: viewModel.tr("controls.hint_navigate"), isPill: true)
                hintBadge(glyph: "←/→", text: viewModel.tr("controls.hint_adjust"), isPill: true)
                hintBadge(
                    glyph: controllerService.activeBrand == .playstation ? "✕" : "A",
                    text: viewModel.tr("controls.hint_toggle"),
                    bgColor: Color(red: 0.06, green: 0.49, blue: 0.06)
                )
                hintBadge(
                    glyph: controllerService.activeBrand == .playstation ? "□" : "X",
                    text: viewModel.tr("settings_modal.save_and_close"),
                    bgColor: Color(red: 0.0, green: 0.47, blue: 0.84)
                )
                hintBadge(
                    glyph: controllerService.activeBrand == .playstation ? "○" : "B",
                    text: viewModel.tr("common.close"),
                    bgColor: Color(red: 0.91, green: 0.07, blue: 0.14)
                )
            }
            .padding(.top, 2)
        }
        
        return Group {
            if useLiquidGlass {
                footerContent
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .nxGlassBar(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                    .padding(.bottom, 10)
            } else {
                footerContent
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(
                        ZStack {
                            NXTheme.glassSurfaceElevated.opacity(0.85)
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
    
    func hintBadge(glyph: String, text: String, isPill: Bool = false, bgColor: Color = Color(white: 0.25)) -> some View {
        HStack(spacing: 4) {
            if isPill {
                Text(glyph)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(bgColor))
            } else {
                Text(glyph)
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(bgColor))
            }
            Text(text)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(NXTheme.textSecondary)
        }
    }
    
    func settingCard<Content: View>(
        rowIndex: Int,
        title: String,
        icon: String,
        iconColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isFocused = rowIndex >= 0 && viewModel.settingsModalFocusIndex == rowIndex
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(NXTheme.textPrimary)
                
                Spacer()
                
                if isFocused {
                    Text(viewModel.tr("settings_modal.focused"))
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(NXTheme.primary.opacity(0.3))
                        .clipShape(Capsule())
                }
            }
            
            content()
        }
        .padding(14)
        .nxGlassCard(
            cornerRadius: 14,
            tint: isFocused ? NXTheme.primary.opacity(0.28) : nil
        )
        .overlay(
            Group {
                if isFocused {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(NXTheme.primaryGradient, lineWidth: 2.2)
                }
            }
        )
        .shadow(color: isFocused ? NXTheme.primary.opacity(0.4) : Color.clear, radius: 8, x: 0, y: 2)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
        .onTapGesture {
            if rowIndex >= 0 {
                viewModel.settingsModalFocusIndex = rowIndex
            }
        }
    }
}
