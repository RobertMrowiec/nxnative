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
                    Text(game.platform == .macApp ? "Mac App" : "iOS IPA")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(NXTheme.primary.opacity(0.25))
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
