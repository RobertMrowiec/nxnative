import SwiftUI
import AppKit

public struct GameSettingsSavesSectionView: View {
    public let game: PortedGame
    @ObservedObject private var saveService = SaveSyncService.shared
    @ObservedObject private var deviceService = DeviceDeploymentService.shared

    @State private var backupStatusText: String? = nil
    @State private var syncStatusText: String? = nil
    @State private var isSyncing: Bool = false

    public init(game: PortedGame) {
        self.game = game
    }

    private var titleId: String {
        game.titleId ?? "UNKNOWN"
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: - 1. iCloud Cross-Save Universal Management
            iCloudCrossSaveCard

            // MARK: - 2. Device Direct Transfer (Only for Mac Apps)
            if game.platform == .macApp && !deviceService.connectedDevices.isEmpty {
                Divider().opacity(0.2)
                deviceSyncSection
            }
        }
        .padding(14)
        .nxGlassCard(cornerRadius: 14)
    }

    private var isGameICloudEnabledBinding: Binding<Bool> {
        Binding(
            get: {
                saveService.isICloudSyncEnabled(for: game)
            },
            set: { newValue in
                SoundEffectService.shared.play(.click)
                let cover = GameCoverService.shared.coverImage(for: game)
                saveService.setICloudSyncEnabled(newValue, for: game, cover: cover)
                if newValue {
                    backupStatusText = "Saves sincronizados via iCloud"
                } else {
                    backupStatusText = "Saves salvos localmente"
                }
            }
        )
    }

    private var iCloudCrossSaveCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "icloud.fill")
                        .foregroundColor(saveService.isICloudSyncEnabled(for: game) ? Color.blue : Color.gray)
                        .font(.system(size: 15))
                    Text(L10n.t("settings_modal.icloud_sync"))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(NXTheme.textPrimary)
                }

                Spacer(minLength: 12)

                Toggle("", isOn: isGameICloudEnabledBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            // Compact Status Banner
            HStack(spacing: 8) {
                Circle()
                    .fill(saveService.isICloudSyncEnabled(for: game) ? (saveService.isICloudDriveAvailable ? Color.green : Color.orange) : Color.blue)
                    .frame(width: 7, height: 7)

                Text(saveService.isICloudSyncEnabled(for: game)
                     ? (saveService.isICloudDriveAvailable ? "iCloud Drive Ativo (Cross-Save com iPhone)" : "iCloud Drive Desativado no macOS")
                     : L10n.t("settings_modal.icloud_local_only"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(NXTheme.textPrimary)

                Spacer()

                HStack(spacing: 6) {
                    Button(L10n.t("settings_modal.local_backup")) {
                        SoundEffectService.shared.play(.click)
                        if let backup = saveService.backupMacSave(titleId: titleId) {
                            backupStatusText = "Backup: \(backup.lastPathComponent)"
                        } else {
                            backupStatusText = "Nenhum save local para backup"
                        }
                    }
                    .buttonStyle(NXSecondaryButtonStyle())
                    .controlSize(.mini)

                    Button(action: {
                        SoundEffectService.shared.play(.click)
                        let cover = GameCoverService.shared.coverImage(for: game)
                        saveService.revealCloudGameFolder(for: game, cover: cover)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.fill")
                            Text(L10n.t("common.reveal_finder"))
                        }
                    }
                    .buttonStyle(NXSecondaryButtonStyle())
                    .controlSize(.mini)
                }
            }
            .padding(10)
            .nxGlassCard(cornerRadius: 10, isNested: true)

            if let status = backupStatusText {
                Text(status)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(red: 0.13, green: 0.77, blue: 0.37))
            }
        }
    }

    private var deviceSyncSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L10n.t("settings_modal.direct_sync_title"), systemImage: "arrow.triangle.2.circlepath")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(NXTheme.textPrimary)

            ForEach(deviceService.connectedDevices) { dev in
                HStack {
                    Text("\(dev.name) (\(dev.model))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(NXTheme.textPrimary)

                    Spacer()

                    Button(action: {
                        SoundEffectService.shared.play(.click)
                        isSyncing = true
                        syncStatusText = L10n.t("settings_modal.syncing_save")
                        saveService.autoSyncSave(
                            titleId: titleId,
                            bundleId: "org.nxnative.\(titleId.lowercased())",
                            device: dev,
                            game: game
                        ) { _, msg in
                            isSyncing = false
                            syncStatusText = msg
                        }
                    }) {
                        HStack(spacing: 5) {
                            if isSyncing {
                                ProgressView().controlSize(.mini)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            Text(isSyncing ? L10n.t("settings_modal.syncing_save") : L10n.t("settings_modal.sync_save"))
                        }
                    }
                    .buttonStyle(NXSecondaryButtonStyle())
                    .controlSize(.mini)
                    .disabled(isSyncing)
                }
            }
        }
    }
}
