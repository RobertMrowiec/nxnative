import SwiftUI
import AppKit

public struct GameSettingsIosDeploymentView: View {
    public let game: PortedGame
    @ObservedObject internal var deviceService = DeviceDeploymentService.shared
    @ObservedObject internal var hubService = NxHubDeploymentService.shared
    @ObservedObject internal var deploymentTracker = IosDeploymentTracker.shared

    @State internal var showDeployLogs: Bool = false
    @State private var isHubInstalled: Bool? = nil
    @State private var showBatchModal: Bool = false

    internal var hasExternalRomfs: Bool {
        let parent = game.url.deletingLastPathComponent()
        return FileManager.default.fileExists(atPath: parent.appendingPathComponent("RomFS.img").path) ||
               FileManager.default.fileExists(atPath: parent.appendingPathComponent("romfs.img").path)
    }

    public init(game: PortedGame) {
        self.game = game
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerBar

            let deployment = deviceService.activeDeployment
            if deployment.isRunning {
                activeDeploymentCard(deployment: deployment)
            } else if deployment.phase == .completed {
                completedCard(deployment: deployment)
            } else if deployment.phase == .failed {
                failedCard(deployment: deployment)
            }

            if !deployment.isRunning {
                deploymentModeSelector
                deviceAndSigningSection
                actionSection
            }
        }
        .padding(14)
        .nxGlassCard(cornerRadius: 14)
        .sheet(isPresented: $showBatchModal) {
            if let vm = AppViewModel.shared {
                NxDeploymentBatchModalView(viewModel: vm)
            }
        }
        .onAppear {
            if deviceService.connectedDevices.isEmpty || deviceService.signingTeams.isEmpty {
                deviceService.refreshDevicesAndTeams()
            }
            deviceService.syncInstalledApps(with: [game])
            checkHubInstallation()
        }
        .onChange(of: deviceService.selectedDevice) { _ in
            checkHubInstallation()
        }
    }

    // MARK: - Header
    private var headerBar: some View {
        HStack(spacing: 8) {
            Label(L10n.t("settings_modal.ios_deploy_title"), systemImage: "iphone.badge.play")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(NXTheme.textPrimary)

            Spacer()

            if AppViewModel.shared != nil {
                Button(action: {
                    SoundEffectService.shared.play(.click)
                    showBatchModal = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 10))
                        Text(L10n.t("nxn_launcher.btn_batch"))
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                }
                .buttonStyle(NXSecondaryButtonStyle())
                .controlSize(.mini)
            }

            Button(action: {
                SoundEffectService.shared.play(.click)
                deviceService.revealInFinder(fileURL: game.url)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                    Text(L10n.t("settings_modal.show_ipa"))
                        .font(.system(size: 10.5, weight: .semibold))
                }
            }
            .buttonStyle(NXSecondaryButtonStyle())
            .controlSize(.mini)
        }
    }

    // MARK: - Mode Selector
    private var deploymentModeSelector: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "square.stack.3d.up.fill")
                    .foregroundColor(NXTheme.primary)
                    .font(.system(size: 12))
                Text("NxN Launcher")
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundColor(NXTheme.textPrimary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(NXTheme.glassSurfaceElevated.opacity(0.8))
            .cornerRadius(8)

            if isHubInstalled == true {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.green)
                        .font(.system(size: 11))
                    Text(L10n.t("nxn_launcher.status_ready"))
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(NXTheme.textSecondary)
                }
            } else if isHubInstalled == nil {
                HStack(spacing: 5) {
                    Image(systemName: "circle.dotted")
                        .foregroundColor(NXTheme.textSecondary)
                        .font(.system(size: 11))
                    Text(L10n.t("nxn_launcher.status_checking"))
                        .font(.system(size: 10.5))
                        .foregroundColor(NXTheme.textSecondary)
                }
            }

            Spacer()

            Toggle(isOn: $hubService.useExternalStorage) {
                HStack(spacing: 4) {
                    Image(systemName: "externaldrive.fill")
                        .font(.system(size: 11))
                        .foregroundColor(NXTheme.secondary)
                    Text("SSD USB-C")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(NXTheme.textPrimary)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: NXTheme.secondary))
        }
    }

    // MARK: - Device & Signing
    private var deviceAndSigningSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "iphone.gen3")
                    .foregroundColor(NXTheme.primary)
                    .font(.system(size: 13))
                Text(L10n.t("settings_modal.install_on_label"))
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(NXTheme.textPrimary)

                Spacer()

                if deviceService.connectedDevices.isEmpty {
                    Text(L10n.t("settings_modal.no_devices"))
                        .font(.system(size: 11))
                        .foregroundColor(NXTheme.textSecondary)
                } else {
                    Picker("", selection: $deviceService.selectedDevice) {
                        ForEach(deviceService.connectedDevices) { dev in
                            Text("\(dev.name) (\(dev.model))").tag(Optional(dev))
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: 240)

                    Circle()
                        .fill(deviceService.selectedDevice?.isAvailable == true ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                }

                Button(action: {
                    SoundEffectService.shared.play(.click)
                    deviceService.refreshDevicesAndTeams()
                }) {
                    Image(systemName: deviceService.isDetecting ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(NXSecondaryButtonStyle())
                .controlSize(.mini)
                .disabled(deviceService.isDetecting)
            }

            HStack(spacing: 8) {
                Image(systemName: "person.badge.shield.checkmark")
                    .foregroundColor(NXTheme.primary)
                    .font(.system(size: 13))
                Text(L10n.t("settings_modal.signing_team_label"))
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(NXTheme.textPrimary)

                Spacer()

                if deviceService.signingTeams.isEmpty {
                    Text(L10n.t("settings_modal.no_teams_found"))
                        .font(.system(size: 11))
                        .foregroundColor(NXTheme.textSecondary)
                } else {
                    Picker("", selection: $deviceService.selectedSigningTeam) {
                        Text(L10n.t("settings.ios_unsigned_sideloading")).tag(Optional<DeveloperSigningTeam>.none)
                        ForEach(deviceService.signingTeams) { team in
                            Text(team.displayName).tag(Optional(team))
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: 240)
                }
            }

            HStack(spacing: 6) {
                if let team = deviceService.selectedSigningTeam {
                    if team.hasCertificateInKeychain {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(Color.green)
                            .font(.system(size: 11))
                        Text("Certificado Apple Developer ativo no Keychain")
                            .font(.system(size: 10.5))
                            .foregroundColor(NXTheme.textSecondary)
                    } else {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 11))
                        Text("Perfil Pessoal (7 dias) • Requer Modo Desenvolvedor")
                            .font(.system(size: 10.5))
                            .foregroundColor(NXTheme.textSecondary)
                        Spacer()
                        Button("Xcode") {
                            deviceService.openXcodeAccounts()
                        }
                        .buttonStyle(NXSecondaryButtonStyle())
                        .controlSize(.mini)
                    }
                } else {
                    Image(systemName: "lock.open.fill")
                        .foregroundColor(NXTheme.secondary)
                        .font(.system(size: 11))
                    Text("Sem assinatura • Pronto para AltStore / TrollStore / Sideloadly")
                        .font(.system(size: 10.5))
                        .foregroundColor(NXTheme.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, 4)
        }
        .padding(10)
        .nxGlassCard(cornerRadius: 10, isNested: true)
    }

    private func checkHubInstallation() {
        guard let dev = deviceService.selectedDevice else {
            isHubInstalled = nil
            return
        }
        hubService.isHubAppInstalled(on: dev) { installed in
            self.isHubInstalled = installed
        }
    }
}
