import SwiftUI

/// Single profile row component to ensure rapid type-checking.
private struct ProfileRowButton: View {
    let profile: ControllerProfile
    let isSelected: Bool
    let isFocused: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? NXTheme.primary : .white.opacity(0.4))

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    if profile.isDefault {
                        Text("Default Preset")
                            .font(.system(size: 10))
                            .foregroundColor(NXTheme.secondary)
                    }
                }

                Spacer()

                if isSelected {
                    Text("Active")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(NXTheme.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(NXTheme.primary.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .nxGlassInteractive(
                in: RoundedRectangle(cornerRadius: 12),
                fallbackFill: isFocused ? NXTheme.primary.opacity(0.35) : (isSelected ? NXTheme.glassSurfaceElevated : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? NXTheme.secondary : (isSelected ? NXTheme.borderSubtle : Color.clear), lineWidth: 1.5)
            )
        }
        .buttonStyle(NXPressableButtonStyle())
    }
}

/// Liquid Glass modal picker for Controller Profiles, fully navigable and interactable with gamepads.
struct ControlsProfileLiquidPicker: View {
    @ObservedObject var profileManager = InputProfileManager.shared
    @Binding var activeProfile: ControllerProfile
    @Binding var isPresented: Bool
    @Binding var focusedProfileIndex: Int
    var onNewProfile: () -> Void
    @ObservedObject private var i18n = LocalizationService.shared

    var body: some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()
                .onTapGesture {
                    SoundEffectService.shared.play(.click)
                    isPresented = false
                }

            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(NXTheme.primary)

                    Text(i18n.t("controls.profile"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: {
                        SoundEffectService.shared.play(.click)
                        isPresented = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Divider().opacity(0.2)

                // Profiles List
                ScrollViewReader { _ in
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(Array(profileManager.profiles.enumerated()), id: \.element.id) { idx, prof in
                                ProfileRowButton(
                                    profile: prof,
                                    isSelected: prof.id == activeProfile.id,
                                    isFocused: idx == focusedProfileIndex,
                                    onSelect: {
                                        SoundEffectService.shared.play(.click)
                                        selectProfile(prof)
                                    }
                                )
                                .id("prof_row_\(idx)")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 280)
                }

                Divider().opacity(0.2)

                // Actions Footer
                HStack {
                    Button(action: {
                        SoundEffectService.shared.play(.click)
                        isPresented = false
                        onNewProfile()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text(i18n.t("controls.new_profile"))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(NXTheme.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .contentShape(Capsule())
                        .nxGlassInteractive(in: Capsule(), fallbackFill: NXTheme.glassSurfaceElevated)
                    }
                    .buttonStyle(NXPressableButtonStyle())

                    Spacer()

                    Button(action: {
                        SoundEffectService.shared.play(.click)
                        isPresented = false
                    }) {
                        Text(i18n.t("common.done"))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .contentShape(Capsule())
                            .nxGlassInteractive(in: Capsule(), fallbackFill: NXTheme.primary)
                    }
                    .buttonStyle(NXPressableButtonStyle())
                }
            }
            .padding(20)
            .frame(width: 440)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(NXTheme.glassSurfaceElevated.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(NXTheme.borderSubtle, lineWidth: 1.2)
            )
            .shadow(color: Color.black.opacity(0.55), radius: 24, x: 0, y: 12)
        }
        .onAppear {
            if let idx = profileManager.profiles.firstIndex(where: { $0.id == activeProfile.id }) {
                focusedProfileIndex = idx
            }
        }
    }

    private func selectProfile(_ prof: ControllerProfile) {
        profileManager.setProfile(prof, forPlayer: profileManager.activePlayerIndex)
        activeProfile = prof
        isPresented = false
    }
}
