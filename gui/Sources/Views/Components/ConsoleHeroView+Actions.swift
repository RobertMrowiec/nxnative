import SwiftUI
import AppKit

extension ConsoleHeroView {
    @ViewBuilder
    internal func portedActionBar(for g: PortedGame) -> some View {
        if g.isPlayableLocally {
            // Play Button Pill for Mac Apps & Mac Native Games
            Button(action: {
                viewModel.launchGame(g)
            }) {
                HStack(spacing: 8) {
                    if isLaunching {
                        ProgressView()
                            .controlSize(.small)
                        Text(viewModel.tr("common.launching"))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                        Text(viewModel.tr("common.play"))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
                .contentShape(Capsule())
                .nxGlassInteractive(
                    in: Capsule(),
                    tint: NXTheme.primary.opacity(glassEnv.appearance == .liquid ? 0.76 : 0.88),
                    isSelected: true,
                    isInteractive: !isLaunching,
                    fallbackFill: NXTheme.primary,
                    fallbackSelectedFill: NXTheme.primary
                )
            }
            .buttonStyle(NXPressableButtonStyle())
            .disabled(isLaunching)
            .nxNoFocusRing()
            
            // Controls Guide Button (only for Mac ports)
            if g.platform == .macApp {
                heroSecondaryButton(
                    icon: "gamecontroller.fill",
                    title: viewModel.tr("controls.guide_title")
                ) {
                    SoundEffectService.shared.play(.click)
                    viewModel.showControlsGuideSheet = true
                }
            }
        } else {
            // Send to Device Button for iOS IPAs
            Button(action: {
                SoundEffectService.shared.play(.click)
                viewModel.gameForSettingsSheet = g
            }) {
                HStack(spacing: 8) {
                    if deviceService.activeDeployment.isRunning {
                        ProgressView()
                            .controlSize(.small)
                        Text("\(deviceService.activeDeployment.phase.rawValue) (\(Int(deviceService.activeDeployment.progressFraction * 100))%)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    } else {
                        let isDeployed = IosDeploymentTracker.shared.isGameDeployed(g)
                        let record = IosDeploymentTracker.shared.deploymentRecord(for: g)
                        let isExpired = record?.isExpired ?? false

                        Image(systemName: isDeployed ? "arrow.triangle.2.circlepath" : "arrow.up.forward.app")
                            .font(.system(size: 13))
                        Text(
                            isDeployed
                                ? (isExpired ? viewModel.tr("console.renew_ios_expired") : viewModel.tr("console.renew_ios"))
                                : viewModel.tr("console.send_ios")
                        )
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .contentShape(Capsule())
                .nxGlassInteractive(
                    in: Capsule(),
                    tint: ((IosDeploymentTracker.shared.deploymentRecord(for: g)?.isExpired ?? false) ? Color.red : NXTheme.primary).opacity(glassEnv.appearance == .liquid ? 0.76 : 0.88),
                    isSelected: true,
                    fallbackFill: ((IosDeploymentTracker.shared.deploymentRecord(for: g)?.isExpired ?? false) ? Color.red : NXTheme.primary),
                    fallbackSelectedFill: ((IosDeploymentTracker.shared.deploymentRecord(for: g)?.isExpired ?? false) ? Color.red : NXTheme.primary)
                )
            }
            .buttonStyle(NXPressableButtonStyle())
            .nxNoFocusRing()

            // AirDrop Button for iOS
            heroSecondaryButton(
                icon: "airdrop",
                title: viewModel.tr("common.airdrop")
            ) {
                SoundEffectService.shared.play(.click)
                DeviceDeploymentService.shared.shareViaAirDrop(fileURL: g.url)
            }
            .help(viewModel.tr("settings_modal.airdrop_help"))

            // Reveal in Finder Button for iOS
            heroSecondaryButton(
                icon: "folder.fill",
                title: viewModel.tr("console.reveal_ipa")
            ) {
                SoundEffectService.shared.play(.click)
                NSWorkspace.shared.activateFileViewerSelecting([g.url])
            }
        }

        // Options Button
        heroSecondaryButton(
            icon: "slider.horizontal.3",
            title: viewModel.tr("console.options")
        ) {
            SoundEffectService.shared.play(.click)
            viewModel.gameForSettingsSheet = g
        }

        // Saves Folder Button
        heroSecondaryButton(
            icon: "folder.fill",
            title: viewModel.tr("console.saves")
        ) {
            SoundEffectService.shared.play(.click)
            let profile = GameDetailsProfile.inspect(for: g)
            viewModel.revealSaveFolder(profile.saveDirectory)
        }
    }

    @ViewBuilder
    internal func unportedActionBar(for u: SelectableGame) -> some View {
        Button(action: {
            SoundEffectService.shared.play(.click)
            viewModel.selectedGame = u
            viewModel.gameForPortModal = u
        }) {
            HStack(spacing: 8) {
                if isUnportedBuilding {
                    ProgressView()
                        .controlSize(.small)
                    Text("Building (\(Int(viewModel.progressFraction * 100))%)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                } else {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 13))
                    Text(viewModel.tr("library.port_now"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .contentShape(Capsule())
            .nxGlassInteractive(
                in: Capsule(),
                tint: NXTheme.primary.opacity(0.88),
                isSelected: true,
                isInteractive: !isUnportedBuilding,
                fallbackFill: NXTheme.primary,
                fallbackSelectedFill: NXTheme.primary
            )
        }
        .buttonStyle(NXPressableButtonStyle())
        .disabled(isUnportedBuilding)
        .nxNoFocusRing()

        if let base = u.baseFile {
            heroSecondaryButton(icon: "folder.fill", title: viewModel.tr("actions.app_files")) {
                SoundEffectService.shared.play(.click)
                NSWorkspace.shared.activateFileViewerSelecting([base.url])
            }
        }
    }

    internal func heroSecondaryButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundColor(NXTheme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Capsule())
            .nxGlassInteractive(
                in: Capsule(),
                fallbackFill: NXTheme.glassSurfaceElevated.opacity(0.85)
            )
        }
        .buttonStyle(NXPressableButtonStyle())
        .nxNoFocusRing()
    }

    internal func statusPill(title: String, active: Bool) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .nxGlassBar(
                in: Capsule(),
                tint: active ? NXTheme.primary.opacity(0.46) : NXTheme.glassSurface.opacity(0.28),
                fallbackFill: active ? NXTheme.primary.opacity(0.35) : NXTheme.textMuted.opacity(0.24),
                fallbackStroke: active ? NXTheme.secondary.opacity(0.45) : Color.white.opacity(0.12)
            )
    }
}
