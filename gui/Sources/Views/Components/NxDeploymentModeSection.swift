import SwiftUI

// MARK: - NxN Launcher Deployment Target Banner

/// Interactive Liquid Glass card displaying target status for the unified NxN Launcher container,
/// with toggles for USB-C External Storage and container presence checks.
public struct NxDeploymentModeSection: View {
    @ObservedObject private var hubService = NxHubDeploymentService.shared
    @ObservedObject private var deviceService = DeviceDeploymentService.shared
    @State private var isHubInstalled: Bool? = nil

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .foregroundColor(NXTheme.primary)
                        .font(.system(size: 13))
                    Text(L10n.t("nxn_launcher.title"))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(NXTheme.textPrimary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(NXTheme.glassSurfaceElevated.opacity(0.8))
                .cornerRadius(8)

                Spacer()

                // Toggle: USB-C External Storage
                Toggle(isOn: $hubService.useExternalStorage) {
                    HStack(spacing: 4) {
                        Image(systemName: "externaldrive.fill")
                            .font(.system(size: 11))
                            .foregroundColor(NXTheme.secondary)
                        Text("SSD USB-C")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(NXTheme.textPrimary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: NXTheme.secondary))
            }

            Text(L10n.t("nxn_launcher.single_app_notice"))
                .font(.system(size: 11))
                .foregroundColor(NXTheme.textSecondary)
                .lineLimit(2)

            HStack(spacing: 8) {
                if let installed = isHubInstalled {
                    if installed {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(red: 0.13, green: 0.77, blue: 0.37))
                                .font(.system(size: 11))
                            Text(L10n.t("nxn_launcher.status_ready"))
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundColor(NXTheme.textPrimary)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.app.fill")
                                .foregroundColor(NXTheme.primary)
                                .font(.system(size: 11))
                            Text(L10n.t("nxn_launcher.status_auto_install"))
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundColor(NXTheme.textPrimary)
                        }
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "circle.dotted")
                            .foregroundColor(NXTheme.secondary)
                            .font(.system(size: 11))
                        Text(L10n.t("nxn_launcher.status_checking"))
                            .font(.system(size: 10.5))
                            .foregroundColor(NXTheme.textSecondary)
                    }
                }

                Spacer()
            }
            .padding(8)
            .background(NXTheme.glassSurfaceElevated.opacity(0.6))
            .cornerRadius(8)
        }
        .padding(12)
        .nxGlassCard(cornerRadius: 10)
        .onAppear {
            checkHubInstallation()
        }
        .onChange(of: deviceService.selectedDevice) { _ in
            checkHubInstallation()
        }
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
