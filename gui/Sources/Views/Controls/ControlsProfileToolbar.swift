import SwiftUI

struct ControlsProfileToolbar: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject var profileManager = InputProfileManager.shared
    @Binding var activeProfile: ControllerProfile
    @Binding var newProfileName: String
    @Binding var showNewProfileAlert: Bool
    @ObservedObject private var i18n = LocalizationService.shared

    private var isHeaderActive: Bool {
        viewModel.isInsideControlsCard && viewModel.controlsCardIndex == 0
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(i18n.t("controls.title"))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(NXTheme.textPrimary)

            Spacer()

            NXGlassContainer(spacing: 8) {
                HStack(spacing: 8) {
                    // Player Selector Button (P1..P8)
                    ControlsPlayerSelectorMenu(
                        isFocused: isHeaderActive && viewModel.controlsHeaderFocus == 0,
                        isPresented: $viewModel.showControlsPlayerModal,
                        focusedIndex: $viewModel.controlsPlayerModalFocus
                    )

                    // Profile Selector Pill (Apple Liquid Glass)
                    Button(action: {
                        SoundEffectService.shared.play(.click)
                        if let idx = profileManager.profiles.firstIndex(where: { $0.id == activeProfile.id }) {
                            viewModel.controlsProfileModalFocus = idx
                        }
                        viewModel.showControlsProfileModal.toggle()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)

                            Text(activeProfile.name)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .contentShape(Capsule())
                        .nxGlassInteractive(
                            in: Capsule(),
                            fallbackFill: (isHeaderActive && viewModel.controlsHeaderFocus == 1) ? NXTheme.primary.opacity(0.35) : NXTheme.glassSurfaceElevated
                        )
                        .overlay(
                            Capsule()
                                .stroke((isHeaderActive && viewModel.controlsHeaderFocus == 1) ? NXTheme.secondary : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(NXPressableButtonStyle())
                    .fixedSize()
                    .nxNoFocusRing()
                    .sheet(isPresented: $viewModel.showControlsProfileModal) {
                        ControlsProfileLiquidPicker(
                            activeProfile: $activeProfile,
                            isPresented: $viewModel.showControlsProfileModal,
                            focusedProfileIndex: $viewModel.controlsProfileModalFocus,
                            onNewProfile: {
                                newProfileName = ""
                                showNewProfileAlert = true
                            }
                        )
                    }

                    Button(i18n.t("common.duplicate")) {
                        SoundEffectService.shared.play(.click)
                        let copy = profileManager.duplicateProfile(activeProfile)
                        activeProfile = copy
                    }
                    .buttonStyle(NXSecondaryButtonStyle())
                    .controlSize(.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke((isHeaderActive && viewModel.controlsHeaderFocus == 2) ? NXTheme.secondary : Color.clear, lineWidth: 1.5)
                    )

                    if !activeProfile.isDefault {
                        Button(i18n.t("common.delete")) {
                            SoundEffectService.shared.play(.click)
                            profileManager.deleteProfile(activeProfile)
                        }
                        .buttonStyle(NXSecondaryButtonStyle())
                        .controlSize(.small)
                        .nxGlassTransition(.materialize)
                    }

                    Button(i18n.t("common.reset")) {
                        SoundEffectService.shared.play(.click)
                        let reset = ControllerProfile.nintendoDefault
                        activeProfile = reset
                        profileManager.updateProfile(reset)
                    }
                    .buttonStyle(NXSecondaryButtonStyle())
                    .controlSize(.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke((isHeaderActive && viewModel.controlsHeaderFocus == 3) ? NXTheme.secondary : Color.clear, lineWidth: 1.5)
                    )
                }
            }
        }
    }
}
