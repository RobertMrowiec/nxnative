import SwiftUI

struct GameSettingsControllerSection: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject var profileManager = InputProfileManager.shared
    let rowIndex: Int
    @State private var selectedPlayerIndex: Int = 0

    var body: some View {
        let isRowFocused = viewModel.settingsModalFocusIndex == rowIndex
        let pKey = String(selectedPlayerIndex)
        let playerProfileId = viewModel.activeSettingsConfig.playerProfileIds?[pKey] ?? (selectedPlayerIndex == 0 ? viewModel.activeSettingsConfig.controllerProfileId : nil)
        let selectedProfile = playerProfileId.flatMap { idStr in
            UUID(uuidString: idStr).flatMap { uuid in
                profileManager.profiles.first(where: { $0.id == uuid })
            }
        }
        let globalLabel = String(format: viewModel.tr("settings_modal.controller_profile_global"), profileManager.profile(forPlayer: selectedPlayerIndex).name)
        let currentLabel = selectedProfile?.name ?? globalLabel

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(viewModel.tr("settings_modal.controller_profile_desc"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isRowFocused ? .white : .white.opacity(0.88))
                
                Spacer(minLength: 8)
                
                // Player Selector Dropdown (P1..P8)
                Menu {
                    ForEach(0..<8, id: \.self) { pIdx in
                        Button(action: {
                            SoundEffectService.shared.play(.click)
                            selectedPlayerIndex = pIdx
                        }) {
                            if selectedPlayerIndex == pIdx {
                                Label("Player \(pIdx + 1)", systemImage: "checkmark")
                            } else {
                                Text("Player \(pIdx + 1)")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(NXTheme.primary)
                        Text("P\(selectedPlayerIndex + 1)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .contentShape(Capsule())
                    .nxGlassInteractive(in: Capsule(), fallbackFill: NXTheme.glassSurfaceElevated)
                }
                .menuStyle(.button)
                .buttonStyle(NXPressableButtonStyle())
                .menuIndicator(.hidden)
                .fixedSize()
                .nxNoFocusRing()

                // Profile Selector for this player
                Menu {
                    Button(action: {
                        SoundEffectService.shared.play(.click)
                        var map = viewModel.activeSettingsConfig.playerProfileIds ?? [:]
                        map.removeValue(forKey: pKey)
                        viewModel.activeSettingsConfig.playerProfileIds = map.isEmpty ? nil : map
                        if selectedPlayerIndex == 0 {
                            viewModel.activeSettingsConfig.controllerProfileId = nil
                        }
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
                            var map = viewModel.activeSettingsConfig.playerProfileIds ?? [:]
                            map[pKey] = prof.id.uuidString
                            viewModel.activeSettingsConfig.playerProfileIds = map
                            if selectedPlayerIndex == 0 {
                                viewModel.activeSettingsConfig.controllerProfileId = prof.id.uuidString
                            }
                        }) {
                            if selectedProfile?.id == prof.id {
                                Label(prof.name, systemImage: "checkmark")
                            } else {
                                Text(prof.name)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                        Text(currentLabel)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .contentShape(Capsule())
                    .nxGlassInteractive(in: Capsule(), fallbackFill: NXTheme.glassSurfaceElevated)
                }
                .menuStyle(.button)
                .buttonStyle(NXPressableButtonStyle())
                .menuIndicator(.hidden)
                .fixedSize()
                .nxNoFocusRing()
            }
        }
    }
}
