import SwiftUI
import AppKit

// MARK: - Header, Game Management & Modal Dismiss Handlers
extension GameSettingsSheetView {
    internal var settingsHeaderBar: some View {
        let headerContent = HStack(spacing: 14) {
            let icon = GameCoverService.shared.coverImage(for: game) ?? NSWorkspace.shared.icon(forFile: game.url.path)
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: NXTheme.primary.opacity(0.35), radius: 8, x: 0, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(NXTheme.specularRim, lineWidth: 1)
                )
            
            VStack(alignment: .leading, spacing: 3) {
                Text(game.name)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(NXTheme.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(game.platform == .macApp ? "Mac Port" : (game.platform == .nonSwitch ? "Mac Native" : "iOS IPA"))
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(game.platform == .nonSwitch ? Color(red: 0.20, green: 0.82, blue: 0.60).opacity(0.25) : (game.platform == .macApp ? NXTheme.primary.opacity(0.25) : NXTheme.secondary.opacity(0.25)))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                    
                    if let ver = game.versionString {
                        Text("v\(ver)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(NXTheme.textSecondary)
                    }
                    
                    if let tid = game.titleId {
                        Text("[\(tid)]")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(NXTheme.textMuted)
                    }
                }
            }
            
            Spacer()
            
            Button(action: {
                viewModel.gameForSettingsSheet = nil
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(NXTheme.textPrimary)
                    .frame(width: 30, height: 30)
                    .nxGlassInteractive(in: Circle())
            }
            .buttonStyle(NXPressableButtonStyle())
            .nxNoFocusRing()
            .focusable(false)
        }
        
        return Group {
            if useLiquidGlass {
                headerContent
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .nxGlassBar(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
            } else {
                headerContent
                    .padding(18)
                    .background(
                        ZStack {
                            NXTheme.glassSurfaceElevated.opacity(0.7)
                            Rectangle().fill(.ultraThinMaterial)
                        }
                    )
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(NXTheme.borderSubtle),
                        alignment: .bottom
                    )
            }
        }
    }
    
    func coverArtworkSection() -> some View {
        let isCustom = GameCoverService.shared.hasCustomCover(for: game)
        let currentCover = GameCoverService.shared.coverImage(for: game) ?? NSWorkspace.shared.icon(forFile: game.url.path)
        
        return settingCard(
            rowIndex: -1,
            title: viewModel.tr("settings_modal.cover_title"),
            icon: "photo.on.rectangle.angled",
            iconColor: Color(red: 0.95, green: 0.45, blue: 0.75)
        ) {
            HStack(spacing: 16) {
                Image(nsImage: currentCover)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 55, height: 78)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(NXTheme.specularRim, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 2)
                
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(isCustom ? viewModel.tr("settings_modal.cover_custom_active") : viewModel.tr("settings_modal.cover_auto_active"))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(isCustom ? NXTheme.secondary : NXTheme.textPrimary)
                        
                        if isCustom {
                            Text(viewModel.tr("settings_modal.cover_custom_badge"))
                                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(NXTheme.secondary.opacity(0.25))
                                .foregroundColor(NXTheme.secondary)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(isCustom
                         ? viewModel.tr("settings_modal.cover_custom_desc")
                         : viewModel.tr("settings_modal.cover_auto_desc"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)
                    
                    NXGlassContainer(spacing: 8) {
                        HStack(spacing: 8) {
                            Button(viewModel.tr("settings_modal.cover_choose_btn")) {
                                let panel = NSOpenPanel()
                                panel.title = viewModel.tr("settings_modal.cover_panel_title")
                                panel.allowedContentTypes = [.jpeg, .png, .webP, .image]
                                panel.allowsMultipleSelection = false
                                panel.canChooseDirectories = false
                                if panel.runModal() == .OK, let url = panel.url {
                                    SoundEffectService.shared.play(.click)
                                    _ = GameCoverService.shared.setCustomCover(imageURL: url, for: game)
                                }
                            }
                            .buttonStyle(NXSecondaryButtonStyle())
                            .controlSize(.small)
                            
                            if isCustom {
                                Button(viewModel.tr("settings_modal.cover_reset_btn")) {
                                    SoundEffectService.shared.play(.click)
                                    GameCoverService.shared.resetCustomCover(for: game)
                                }
                                .buttonStyle(NXSecondaryButtonStyle())
                                .controlSize(.small)
                                .foregroundColor(Color(red: 1.0, green: 0.4, blue: 0.4))
                            }
                        }
                    }
                    .padding(.top, 2)
                }
                Spacer()
            }
        }
    }

    func gameManagementSection() -> some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(viewModel.tr("settings_modal.management_title"), systemImage: "gearshape.2.fill")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(NXTheme.textPrimary)
                    Spacer()
                }
                
                Text(viewModel.tr("settings_modal.management_desc"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.88))
                
                HStack(spacing: 12) {
                    Spacer()
                    
                    NXGlassContainer(spacing: 12) {
                        HStack(spacing: 12) {
                            Button(action: {
                                dismissSettingsAndShowRemove()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "eye.slash")
                                    Text(viewModel.tr("actions.remove_from_library"))
                                }
                            }
                            .buttonStyle(NXSecondaryButtonStyle())
                            
                            Button(action: {
                                dismissSettingsAndShowTrash()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash.fill")
                                    Text(viewModel.tr("actions.move_to_trash"))
                                }
                                .foregroundColor(Color(red: 0.95, green: 0.35, blue: 0.35))
                            }
                            .buttonStyle(NXSecondaryButtonStyle())
                        }
                    }
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }
    
    func dismissSettingsAndShowRemove() {
        let target = game
        viewModel.gameForSettingsSheet = nil
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            viewModel.gameToRemove = target
            viewModel.showRemoveConfirm = true
        }
    }
    
    func dismissSettingsAndShowTrash() {
        let target = game
        viewModel.gameForSettingsSheet = nil
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            viewModel.gameToTrash = target
            viewModel.showTrashConfirm = true
        }
    }
}
