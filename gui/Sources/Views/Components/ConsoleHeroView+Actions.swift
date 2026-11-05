import SwiftUI
import AppKit

extension ConsoleHeroView {
    @ViewBuilder
    internal func portedActionBar(for g: PortedGame) -> some View {
        let isPlayFocused = viewModel.isFocusOnHeroBar && viewModel.heroActionFocusIndex == 0
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
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isPlayFocused ? AnyShapeStyle(LinearGradient(colors: [Color.white, NXTheme.primary], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.clear),
                            lineWidth: isPlayFocused ? 2.5 : 0
                        )
                )
                .scaleEffect(isPlayFocused ? 1.05 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.72), value: isPlayFocused)
            }
            .buttonStyle(NXPressableButtonStyle())
            .disabled(isLaunching)
            .nxNoFocusRing()
            .nxGlassTransition(.identity)
            
            // Options Button (Gamepad Menu Icon, Text Removed)
            heroIconButton(
                icon: "line.3.horizontal",
                index: 1,
                helpText: viewModel.tr("console.options")
            ) {
                SoundEffectService.shared.play(.click)
                viewModel.gameForSettingsSheet = g
            }
            
            // Play Time Indicator (same line as play, matching title font style rounded heavy, slightly smaller)
            HStack(spacing: 7) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(NXTheme.primary)
                
                Text(viewModel.formattedPlayTime(for: g))
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(NXTheme.textPrimary)
            }
            .padding(.leading, 8)
            .shadow(color: Color.black.opacity(0.85), radius: 6, x: 0, y: 2)
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
                .overlay(
                    Capsule()
                        .strokeBorder(isPlayFocused ? Color.white : Color.clear, lineWidth: isPlayFocused ? 2.5 : 0)
                )
                .scaleEffect(isPlayFocused ? 1.05 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.72), value: isPlayFocused)
            }
            .buttonStyle(NXPressableButtonStyle())
            .nxNoFocusRing()
            .nxGlassTransition(.identity)

            // Options Button for iOS (Gamepad Menu Icon, Text Removed)
            heroIconButton(
                icon: "line.3.horizontal",
                index: 2,
                helpText: viewModel.tr("console.options")
            ) {
                SoundEffectService.shared.play(.click)
                viewModel.gameForSettingsSheet = g
            }

            // Reveal in Finder Button for iOS
            heroSecondaryButton(
                icon: "folder.fill",
                title: viewModel.tr("console.reveal_ipa"),
                index: 3
            ) {
                SoundEffectService.shared.play(.click)
                NSWorkspace.shared.activateFileViewerSelecting([g.url])
            }
            
            // Play Time Indicator for iOS ports
            HStack(spacing: 7) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(NXTheme.primary)
                
                Text(viewModel.formattedPlayTime(for: g))
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(NXTheme.textPrimary)
            }
            .padding(.leading, 8)
            .shadow(color: Color.black.opacity(0.85), radius: 6, x: 0, y: 2)
        }
    }

    @ViewBuilder
    internal func unportedActionBar(for u: SelectableGame) -> some View {
        let isPortFocused = viewModel.isFocusOnHeroBar && viewModel.heroActionFocusIndex == 0
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
            .overlay(
                Capsule()
                    .strokeBorder(isPortFocused ? Color.white : Color.clear, lineWidth: isPortFocused ? 2.5 : 0)
            )
            .scaleEffect(isPortFocused ? 1.05 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.72), value: isPortFocused)
        }
        .buttonStyle(NXPressableButtonStyle())
        .disabled(isUnportedBuilding)
        .nxNoFocusRing()
        .nxGlassTransition(.identity)

        if let base = u.baseFile {
            heroSecondaryButton(icon: "folder.fill", title: viewModel.tr("actions.app_files"), index: 1) {
                SoundEffectService.shared.play(.click)
                NSWorkspace.shared.activateFileViewerSelecting([base.url])
            }
        }
    }

    internal func heroSecondaryButton(icon: String, title: String, index: Int, action: @escaping () -> Void) -> some View {
        let isFocused = viewModel.isFocusOnHeroBar && viewModel.heroActionFocusIndex == index
        return Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundColor(isFocused ? .white : NXTheme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Capsule())
            .nxGlassInteractive(
                in: Capsule(),
                isSelected: isFocused,
                fallbackFill: isFocused ? NXTheme.primary.opacity(0.85) : NXTheme.glassSurfaceElevated.opacity(0.85)
            )
            .overlay(
                Capsule()
                    .strokeBorder(isFocused ? Color.white : Color.clear, lineWidth: isFocused ? 2 : 0)
            )
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.72), value: isFocused)
        }
        .buttonStyle(NXPressableButtonStyle())
        .nxNoFocusRing()
        .nxGlassTransition(.identity)
    }

    internal func heroIconButton(icon: String, index: Int, helpText: String, action: @escaping () -> Void) -> some View {
        let isFocused = viewModel.isFocusOnHeroBar && viewModel.heroActionFocusIndex == index
        return Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(isFocused ? .white : NXTheme.textPrimary)
                .frame(width: 36, height: 36)
                .contentShape(Circle())
                .nxGlassInteractive(
                    in: Circle(),
                    isSelected: isFocused,
                    fallbackFill: isFocused ? NXTheme.primary.opacity(0.85) : NXTheme.glassSurfaceElevated.opacity(0.85)
                )
                .overlay(
                    Circle()
                        .strokeBorder(isFocused ? Color.white : Color.clear, lineWidth: 2)
                )
                .scaleEffect(isFocused ? 1.05 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.72), value: isFocused)
        }
        .buttonStyle(NXPressableButtonStyle())
        .help(helpText)
        .nxNoFocusRing()
        .nxGlassTransition(.identity)
    }
}
