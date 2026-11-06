import SwiftUI
import AppKit

public struct PortGameModalView: View {
    public let game: SelectableGame
    @ObservedObject public var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    
    public init(game: SelectableGame, viewModel: AppViewModel) {
        self.game = game
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Modal Top Header
            headerBar
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 14) {
                    // Game Identity Card
                    gameIdentityCard
                    
                    // Prerequisite Warning Card (shown when port button cannot start)
                    if !viewModel.canStartBuild {
                        prerequisitesWarningCard
                    }
                    
                    // Hardware-Based Porting Time Estimate Card
                    hardwareEstimateCard
                    
                    // Updates & DLCs Card
                    updatesAndDlcsCard
                    
                    // Platform Selection (Mac vs iPhone/iPad)
                    PortPlatformSelectorView(viewModel: viewModel)
                    
                    // If iOS: Immediate Auto-Deploy vs Later prompt
                    if viewModel.platform == .ios {
                        PortIosDeployChoiceView(viewModel: viewModel)
                    }
                    
                    // Discreet Advanced Settings Collapsible Section
                    PortAdvancedSettingsView(viewModel: viewModel)
                }
                .padding(18)
            }
            .frame(maxHeight: 480)
            
            // Modal Bottom Actions
            footerBar
        }
        .frame(width: 540)
        .background(NXTheme.canvasObsidian)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(NXTheme.specularRim, lineWidth: 1)
        )
        .onAppear {
            viewModel.portModalFocusIndex = 0
            viewModel.selectedGame = game
            if viewModel.selectedGameFolder == nil, let fileDir = game.files.first?.url.deletingLastPathComponent() {
                viewModel.selectedGameFolder = fileDir
            }
            if game.isSwitch2 || game.isNup {
                viewModel.platform = .macApp
            }
            if viewModel.appName.isEmpty {
                viewModel.appName = game.name
            }
            if DeviceDeploymentService.shared.connectedDevices.isEmpty || DeviceDeploymentService.shared.signingTeams.isEmpty {
                DeviceDeploymentService.shared.refreshDevicesAndTeams()
            }
        }
    }
    
    // MARK: - Header Bar
    private var headerBar: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "play.circle.fill")
                    .foregroundColor(NXTheme.primary)
                    .font(.system(size: 16, weight: .bold))
                Text(viewModel.tr("port_modal.title"))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(NXTheme.textPrimary)
            }
            
            Spacer()
            
            Button(action: {
                SoundEffectService.shared.play(.click)
                viewModel.gameForPortModal = nil
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(NXTheme.textSecondary)
            }
            .buttonStyle(PlainButtonStyle())
            .nxNoFocusRing()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(NXTheme.glassSurfaceElevated.opacity(0.85))
        .overlay(Rectangle().frame(height: 1).foregroundColor(NXTheme.borderSubtle), alignment: .bottom)
    }
    
    // MARK: - Game Identity Card
    private var gameIdentityCard: some View {
        GlassCard(padding: 12) {
            HStack(spacing: 12) {
                if let cover = GameCoverService.shared.coverImage(titleId: game.titleId, gameName: game.name) {
                    Image(nsImage: cover)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 66)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(NXTheme.primary.opacity(0.18))
                        .frame(width: 44, height: 66)
                        .overlay(Image(systemName: "gamecontroller").foregroundColor(NXTheme.secondary))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(game.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(NXTheme.textPrimary)
                        .lineLimit(1)
                    
                    if let tid = game.titleId, !tid.isEmpty {
                        Text(tid)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(NXTheme.textSecondary)
                    }
                    
                    if game.isSwitch2 || game.isNup {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles.tv.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text(game.isNup ? "NUP Container · No Keys Needed" : "Switch 2 Dump · No Keys Needed")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(red: 0.95, green: 0.48, blue: 0.16).opacity(0.85))
                        .clipShape(Capsule())
                    }
                    
                    Text(game.formattedSize)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(NXTheme.secondary)
                }
                Spacer()
            }
        }
    }
    
    // MARK: - Hardware Estimate Card
    private var hardwareEstimateCard: some View {
        let estimate = BuildEstimationService.shared.estimate(for: game, nxnativePath: viewModel.nxnativePath)
        
        return GlassCard(padding: 12) {
            VStack(alignment: .leading, spacing: 10) {
                // Header with gauge icon & hardware badge
                HStack(spacing: 8) {
                    Label(viewModel.tr("port_modal.estimate_title"), systemImage: "speedometer")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(NXTheme.textPrimary)
                    
                    Spacer()
                    
                    // Mac Hardware Pill (e.g.  Apple M4 (10 cores))
                    HStack(spacing: 4) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 9, weight: .bold))
                        Text(String(format: viewModel.tr("port_modal.estimate_chip_cores"), estimate.chipName, estimate.coreCount))
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(NXTheme.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(NXTheme.glassSurfaceElevated.opacity(0.8))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(NXTheme.specularRim.opacity(0.5), lineWidth: 0.8)
                    )
                }
                
                // Big Estimated Time Range & Category Badge
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(estimate.formattedRange)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    
                    // Badge: e.g. Instant Rebuild, Extensive, Fast
                    HStack(spacing: 4) {
                        Circle()
                            .fill(estimate.speedCategory.color)
                            .frame(width: 6, height: 6)
                        Text(estimate.speedCategory.badgeTitle(viewModel: viewModel))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(estimate.speedCategory.color.opacity(0.25))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(estimate.speedCategory.color.opacity(0.6), lineWidth: 0.8)
                    )
                    
                    if estimate.shaderCount > 0 {
                        Spacer()
                        Text("\(estimate.shaderCount.formatted()) shaders")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(NXTheme.textSecondary)
                    }
                }
                
                // Explanatory Note
                HStack(spacing: 6) {
                    Image(systemName: estimate.isCached ? "bolt.shield.fill" : "info.circle")
                        .font(.system(size: 10))
                        .foregroundColor(estimate.isCached ? Color(red: 0.15, green: 0.85, blue: 0.50) : NXTheme.textSecondary)
                    
                    Text(estimate.isCached ? viewModel.tr("port_modal.estimate_cached_note") : viewModel.tr("port_modal.estimate_cold_build_note"))
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(NXTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
    
    // MARK: - Updates & DLCs Card
    private var updatesAndDlcsCard: some View {
        GlassCard(padding: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Label(viewModel.tr("port_modal.updates_dlcs"), systemImage: "arrow.triangle.merge")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(NXTheme.textPrimary)
                
                if game.updateCount == 0 && game.dlcCount == 0 {
                    Text(viewModel.tr("port_modal.no_updates_dlcs"))
                        .font(.system(size: 11))
                        .foregroundColor(NXTheme.textSecondary)
                } else {
                    HStack(spacing: 8) {
                        if game.updateCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 11))
                                Text(viewModel.tr("port_modal.updates_count", game.updateCount))
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.40))
                            .clipShape(Capsule())
                        }
                        
                        if game.dlcCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 11))
                                Text(viewModel.tr("port_modal.dlcs_count", game.dlcCount))
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.purple.opacity(0.40))
                            .clipShape(Capsule())
                        }
                        Spacer()
                    }
                }
            }
        }
    }
    
    // MARK: - Prerequisites Warning Card
    private var prerequisitesWarningCard: some View {
        GlassCard(padding: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 13, weight: .bold))
                    Text(viewModel.tr("port_modal.requirements_needed"))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(NXTheme.textPrimary)
                }
                
                if !viewModel.isNxnativeValid {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.badge.questionmark")
                            .foregroundColor(.orange)
                            .font(.system(size: 12))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.tr("system.repo_missing_badge"))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(NXTheme.textPrimary)
                            Text(viewModel.tr("build.core_repo_missing_desc"))
                                .font(.system(size: 10))
                                .foregroundColor(NXTheme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(8)
                    .background(NXTheme.glassSurfaceElevated.opacity(0.8))
                    .cornerRadius(8)
                }
                
                if !viewModel.isProdKeysValid && !game.isSwitch2 && !game.isNup {
                    HStack(spacing: 8) {
                        Image(systemName: "key.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 12))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.tr("system.keys_missing_badge"))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(NXTheme.textPrimary)
                            Text(viewModel.tr("system.keys_missing_desc"))
                                .font(.system(size: 10))
                                .foregroundColor(NXTheme.textSecondary)
                        }
                        Spacer()
                        Button(action: {
                            SoundEffectService.shared.play(.click)
                            viewModel.selectProdKeysFile()
                        }) {
                            Text(viewModel.tr("common.choose"))
                                .font(.system(size: 11, weight: .bold))
                        }
                        .buttonStyle(NXSecondaryButtonStyle())
                        .controlSize(.small)
                    }
                    .padding(8)
                    .background(NXTheme.glassSurfaceElevated.opacity(0.8))
                    .cornerRadius(8)
                }
                
                if viewModel.isDiskSpaceLow {
                    HStack(spacing: 8) {
                        Image(systemName: "internaldrive.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 12))
                        Text(viewModel.tr("build.disk_space_low"))
                            .font(.system(size: 11))
                            .foregroundColor(NXTheme.textPrimary)
                        Spacer()
                    }
                    .padding(8)
                    .background(NXTheme.glassSurfaceElevated.opacity(0.8))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Footer Bar
    private var footerBar: some View {
        HStack {
            let isCancelFocused = viewModel.portModalFocusIndex == 10
            Button(viewModel.tr("library.cancel")) {
                SoundEffectService.shared.play(.click)
                viewModel.gameForPortModal = nil
            }
            .buttonStyle(NXSecondaryButtonStyle())
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isCancelFocused ? NXTheme.secondary : Color.clear, lineWidth: 2)
            )
            .shadow(color: isCancelFocused ? NXTheme.secondary.opacity(0.6) : Color.clear, radius: 6)
            
            Spacer()
            
            if !viewModel.canStartBuild {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 11))
                    Text(viewModel.tr("port_modal.requirements_needed"))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(NXTheme.textSecondary)
                }
                .padding(.trailing, 4)
            }
            
            let isStartFocused = viewModel.portModalFocusIndex == 11
            Button(action: {
                SoundEffectService.shared.play(.click)
                viewModel.gameForPortModal = nil
                viewModel.selectedGame = game
                viewModel.startBuild()
            }) {
                HStack(spacing: 6) {
                    if viewModel.platform == .ios && viewModel.autoDeployToDeviceOnFinish {
                        Image(systemName: "iphone.and.arrow.forward")
                        if let dev = DeviceDeploymentService.shared.selectedDevice {
                            Text(viewModel.tr("port_modal.start_and_deploy_button", dev.name))
                        } else {
                            Text(viewModel.tr("port_modal.start_and_deploy_generic"))
                        }
                    } else {
                        Image(systemName: "play.fill")
                        Text(viewModel.tr("port_modal.start_port_button"))
                    }
                }
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .buttonStyle(NXPrimaryButtonStyle())
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isStartFocused ? Color.white : Color.clear, lineWidth: 2)
            )
            .shadow(color: isStartFocused ? NXTheme.primary.opacity(0.8) : Color.clear, radius: 8)
            .disabled(!viewModel.canStartBuild)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(NXTheme.glassSurfaceElevated.opacity(0.85))
        .overlay(Rectangle().frame(height: 1).foregroundColor(NXTheme.borderSubtle), alignment: .top)
    }
}
