import SwiftUI

public struct ProfileHapticsSection: View {
    @Binding public var profile: ControllerProfile
    public var isMasterFocused: Bool = false
    public var isStrengthFocused: Bool = false
    public var isFloorBoostFocused: Bool = false
    public var isTestFocused: Bool = false
    @ObservedObject private var controllerService = GameControllerService.shared
    @ObservedObject private var i18n = LocalizationService.shared

    public init(
        profile: Binding<ControllerProfile>,
        isMasterFocused: Bool = false,
        isStrengthFocused: Bool = false,
        isFloorBoostFocused: Bool = false,
        isTestFocused: Bool = false
    ) {
        self._profile = profile
        self.isMasterFocused = isMasterFocused
        self.isStrengthFocused = isStrengthFocused
        self.isFloorBoostFocused = isFloorBoostFocused
        self.isTestFocused = isTestFocused
    }

    public var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                // Header with Test Button
                HStack(alignment: .center) {
                    Label(
                        i18n.t("controls.haptics_title"),
                        systemImage: "waveform.path.ecg"
                    )
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(NXTheme.textPrimary)

                    Spacer()

                    Button(action: {
                        controllerService.testRumble(
                            strength: profile.rumbleStrength,
                            floorBoost: profile.rumbleFloorBoost
                        )
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(profile.enableRumble ? NXTheme.primary : NXTheme.textMuted)
                            Text(i18n.t("controls.test_rumble"))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .contentShape(Capsule())
                        .nxGlassInteractive(
                            in: Capsule(),
                            fallbackFill: isTestFocused ? NXTheme.primary.opacity(0.35) : NXTheme.glassSurfaceElevated
                        )
                        .overlay(
                            Capsule()
                                .stroke(isTestFocused ? NXTheme.secondary : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(NXPressableButtonStyle())
                    .disabled(!profile.enableRumble || !controllerService.isGamepadConnected)
                    .help(controllerService.isGamepadConnected ? "Dispara pulso de vibração de teste no controle ativo" : "Nenhum controle conectado")
                }

                Divider().opacity(0.2)

                // Master Toggle
                Toggle(isOn: $profile.enableRumble) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(i18n.t("controls.enable_rumble"))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(isMasterFocused ? NXTheme.primary : NXTheme.textPrimary)
                        Text(i18n.t("controls.enable_rumble_desc"))
                            .font(.system(size: 11))
                            .foregroundColor(NXTheme.textMuted)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: NXTheme.primary))
                .padding(6)
                .background(isMasterFocused ? NXTheme.primary.opacity(0.12) : Color.clear)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isMasterFocused ? NXTheme.secondary : Color.clear, lineWidth: 1.5)
                )

                if profile.enableRumble {
                    // Strength Slider
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(i18n.t("controls.rumble_strength"))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(isStrengthFocused ? NXTheme.primary : NXTheme.textSecondary)
                            Spacer()
                            Text(String(format: "%.0f%%", profile.rumbleStrength * 100))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(isStrengthFocused ? .white : NXTheme.primary)
                        }

                        NXLiquidGlassSlider(
                            value: $profile.rumbleStrength,
                            in: 0.1...2.0,
                            step: 0.05,
                            accentColor: isStrengthFocused ? NXTheme.secondary : NXTheme.primary
                        )
                        .frame(height: 24)
                    }
                    .padding(6)
                    .background(isStrengthFocused ? NXTheme.primary.opacity(0.12) : Color.clear)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isStrengthFocused ? NXTheme.secondary : Color.clear, lineWidth: 1.5)
                    )

                    // Inertia Compensation (Floor Boost) Toggle
                    Toggle(isOn: $profile.rumbleFloorBoost) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(i18n.t("controls.rumble_floor_boost"))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(isFloorBoostFocused ? NXTheme.primary : NXTheme.textPrimary)
                            Text(i18n.t("controls.rumble_floor_boost_desc"))
                                .font(.system(size: 11))
                                .foregroundColor(NXTheme.textMuted)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: NXTheme.primary))
                    .padding(6)
                    .background(isFloorBoostFocused ? NXTheme.primary.opacity(0.12) : Color.clear)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isFloorBoostFocused ? NXTheme.secondary : Color.clear, lineWidth: 1.5)
                    )
                }
            }
        }
    }
}
