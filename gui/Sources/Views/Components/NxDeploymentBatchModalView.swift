import SwiftUI
import AppKit

// MARK: - Multi-Game Batch Deployment Modal for NxN Launcher (Apple Liquid Glass)
public struct NxDeploymentBatchModalView: View {
    @ObservedObject public var viewModel: AppViewModel
    @ObservedObject private var hubService = NxHubDeploymentService.shared
    @ObservedObject private var deviceService = DeviceDeploymentService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedGameIds: Set<UUID> = []
    @State private var isDeploying: Bool = false
    @State private var currentBatchStatus: String = ""
    @State private var validationError: String? = nil

    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    private var availableGames: [PortedGame] {
        return viewModel.libraryGames
    }

    private var selectedGamesList: [PortedGame] {
        return availableGames.filter { selectedGameIds.contains($0.id) }
    }

    private var totalSelectedSizeFormatted: String {
        let fm = FileManager.default
        var total: Int64 = 0
        for g in selectedGamesList {
            let parentDir = g.url.deletingLastPathComponent()
            let candidates = [
                parentDir.appendingPathComponent("RomFS.img"),
                parentDir.appendingPathComponent("romfs.img"),
                g.url.appendingPathComponent("romfs.img")
            ]
            var s: Int64 = 0
            for c in candidates where fm.fileExists(atPath: c.path) {
                s = (try? fm.attributesOfItem(atPath: c.path)[.size] as? Int64) ?? 0
                break
            }
            if s == 0 {
                s = (try? fm.attributesOfItem(atPath: g.url.path)[.size] as? Int64) ?? 0
            }
            total += s
        }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerBar

            if let err = validationError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Color.orange)
                    Text(err)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(NXTheme.textPrimary)
                    Spacer()
                }
                .padding(10)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(8)
                .padding(.horizontal, 18)
                .padding(.top, 8)
            }

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 8) {
                    ForEach(availableGames) { game in
                        gameRow(game: game)
                    }
                }
                .padding(18)
            }
            .frame(maxHeight: 380)

            footerBar
        }
        .frame(width: 540)
        .background(NXTheme.canvasObsidian)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(NXTheme.borderSubtle, lineWidth: 1)
        )
        .onAppear {
            // Select all games by default for convenience
            selectedGameIds = Set(availableGames.map { $0.id })
            deviceService.refreshDevicesAndTeams()
        }
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 16))
                .foregroundColor(NXTheme.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("nxn_launcher.batch_modal_title"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(NXTheme.textPrimary)
                Text(L10n.t("nxn_launcher.batch_modal_subtitle"))
                    .font(.system(size: 11))
                    .foregroundColor(NXTheme.textSecondary)
            }

            Spacer()

            Button(action: {
                if selectedGameIds.count == availableGames.count {
                    selectedGameIds.removeAll()
                } else {
                    selectedGameIds = Set(availableGames.map { $0.id })
                }
            }) {
                Text(selectedGameIds.count == availableGames.count ? L10n.t("nxn_launcher.deselect_all") : L10n.t("nxn_launcher.select_all"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(NXTheme.primary)
            }
            .buttonStyle(.plain)

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(NXTheme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(NXTheme.glassSurfaceElevated.opacity(0.85))
    }

    private func gameRow(game: PortedGame) -> some View {
        let isSelected = selectedGameIds.contains(game.id)
        return HStack(spacing: 12) {
            Button(action: {
                if isSelected {
                    selectedGameIds.remove(game.id)
                } else {
                    selectedGameIds.insert(game.id)
                }
            }) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? NXTheme.primary : NXTheme.textSecondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(game.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(NXTheme.textPrimary)
                Text("ID: \(game.titleId ?? "N/A")  ·  Versão: \(game.versionString ?? "1.0.0")")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(NXTheme.textSecondary)
            }

            Spacer()

            if SaveSyncService.shared.locateExistingSave(titleId: game.titleId ?? "", gameName: game.name) != nil {
                HStack(spacing: 4) {
                    Image(systemName: "icloud.fill")
                        .font(.system(size: 10))
                        .foregroundColor(NXTheme.secondary)
                    Text("Save iCloud")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(NXTheme.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(NXTheme.secondary.opacity(0.12))
                .cornerRadius(4)
            }
        }
        .padding(10)
        .background(isSelected ? NXTheme.primary.opacity(0.08) : NXTheme.glassSurfaceElevated.opacity(0.4))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isSelected ? NXTheme.primary.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    private var footerBar: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(selectedGameIds.count) de \(availableGames.count) selecionado(s)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(NXTheme.textPrimary)
                Text("Tamanho total estimado: \(totalSelectedSizeFormatted)")
                    .font(.system(size: 10))
                    .foregroundColor(NXTheme.textSecondary)
            }

            Spacer()

            Button("Cancelar") {
                dismiss()
            }
            .buttonStyle(.plain)
            .foregroundColor(NXTheme.textSecondary)

            Button(action: startBatchDeployment) {
                HStack(spacing: 6) {
                    if isDeploying {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "arrow.up.forward.app.fill")
                            .font(.system(size: 12))
                    }
                    Text(isDeploying ? "Enviando..." : String(format: L10n.t("nxn_launcher.send_batch_btn"), selectedGameIds.count))
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(selectedGameIds.isEmpty ? Color.gray.opacity(0.4) : NXTheme.primary)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(selectedGameIds.isEmpty || isDeploying)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(NXTheme.glassSurfaceElevated.opacity(0.85))
    }

    private func startBatchDeployment() {
        guard let device = deviceService.selectedDevice else {
            validationError = "Nenhum dispositivo iOS conectado selecionado."
            return
        }
        guard !selectedGamesList.isEmpty else { return }

        isDeploying = true
        validationError = nil

        hubService.validateDeviceStorage(for: selectedGamesList, on: device) { ok, msg in
            if !ok {
                self.isDeploying = false
                self.validationError = msg
                return
            }

            self.dismiss()
            // Dispatch batch deployment through DeviceDeploymentService active sheet
            self.hubService.deployBatchToHub(
                games: self.selectedGamesList,
                device: device,
                team: self.deviceService.selectedSigningTeam,
                onProgress: { current, total, status in
                    DispatchQueue.main.async {
                        DeviceDeploymentService.shared.activeDeployment.statusMessage = status
                        DeviceDeploymentService.shared.activeDeployment.progressFraction = Double(current) / Double(total)
                    }
                },
                completion: { success, finalMsg in
                    DispatchQueue.main.async {
                        if success {
                            SoundEffectService.shared.play(.click)
                        } else {
                            SoundEffectService.shared.play(.error)
                        }
                    }
                }
            )
        }
    }
}
