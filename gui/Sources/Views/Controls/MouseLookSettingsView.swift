import SwiftUI

public struct MouseLookSettingsView: View {
    @Binding public var profile: ControllerProfile
    public var isMasterFocused: Bool = false
    public var isSensitivityFocused: Bool = false
    public var isInvertXFocused: Bool = false
    public var isInvertYFocused: Bool = false
    public var isModeFocused: Bool = false
    
    public init(
        profile: Binding<ControllerProfile>,
        isMasterFocused: Bool = false,
        isSensitivityFocused: Bool = false,
        isInvertXFocused: Bool = false,
        isInvertYFocused: Bool = false,
        isModeFocused: Bool = false
    ) {
        self._profile = profile
        self.isMasterFocused = isMasterFocused
        self.isSensitivityFocused = isSensitivityFocused
        self.isInvertXFocused = isInvertXFocused
        self.isInvertYFocused = isInvertYFocused
        self.isModeFocused = isModeFocused
    }
    
    public var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(L10n.t("controls.mouse_right_stick_title"), systemImage: "cursorarrow.motionlines")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(isMasterFocused ? NXTheme.primary : NXTheme.textPrimary)
                    
                    Spacer()
                    
                    Toggle("", isOn: $profile.mouseAsRightStick)
                        .toggleStyle(SwitchToggleStyle(tint: NXTheme.primary))
                        .labelsHidden()
                }
                .padding(6)
                .background(isMasterFocused ? NXTheme.primary.opacity(0.12) : Color.clear)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isMasterFocused ? NXTheme.secondary : Color.clear, lineWidth: 1.5)
                )
                
                Text(L10n.t("controls.mouse_right_stick_desc"))
                    .font(.system(size: 11))
                    .foregroundColor(NXTheme.textSecondary)
                
                if profile.mouseAsRightStick {
                    Divider().opacity(0.2)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        // Sensitivity Slider (Liquid Glass pattern, range up to 100x, default 5x)
                        HStack {
                            Text(L10n.t("controls.mouse_sensitivity"))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(isSensitivityFocused ? NXTheme.primary : NXTheme.textPrimary)
                            
                            Spacer()
                            
                            Text(String(format: "%.1fx", profile.mouseSensitivity))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(isSensitivityFocused ? .white : NXTheme.secondary)
                        }
                        
                        NXLiquidGlassSlider(
                            value: $profile.mouseSensitivity,
                            in: 0.5...100.0,
                            step: 0.5,
                            accentColor: isSensitivityFocused ? NXTheme.secondary : NXTheme.primary
                        )
                        .frame(height: 24)
                        .padding(6)
                        .background(isSensitivityFocused ? NXTheme.primary.opacity(0.12) : Color.clear)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSensitivityFocused ? NXTheme.secondary : Color.clear, lineWidth: 1.5)
                        )
                        
                        Divider().opacity(0.15)
                        
                        // Invert X Axis (Horizontal)
                        Toggle(isOn: $profile.mouseInvertX) {
                            Text(L10n.t("controls.mouse_invert_x"))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(isInvertXFocused ? NXTheme.primary : NXTheme.textPrimary)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: NXTheme.primary))
                        .padding(6)
                        .background(isInvertXFocused ? NXTheme.primary.opacity(0.12) : Color.clear)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isInvertXFocused ? NXTheme.secondary : Color.clear, lineWidth: 1.5)
                        )
                        
                        Divider().opacity(0.15)
                        
                        // Invert Y Axis (Vertical)
                        Toggle(isOn: $profile.mouseInvertY) {
                            Text(L10n.t("controls.mouse_invert_y"))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(isInvertYFocused ? NXTheme.primary : NXTheme.textPrimary)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: NXTheme.primary))
                        .padding(6)
                        .background(isInvertYFocused ? NXTheme.primary.opacity(0.12) : Color.clear)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isInvertYFocused ? NXTheme.secondary : Color.clear, lineWidth: 1.5)
                        )
                        
                        Divider().opacity(0.15)
                        
                        // Mode Selection (Apple Liquid Glass Segmented Bar)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L10n.t("controls.mouse_mode_title"))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(isModeFocused ? NXTheme.primary : NXTheme.textPrimary)
                            
                            NXLiquidSegmentedPicker(
                                selection: $profile.mouseRightStickMode,
                                options: [
                                    NXSegmentOption(value: "cursorLock", title: L10n.t("controls.mouse_mode_lock"), icon: "lock.fill"),
                                    NXSegmentOption(value: "rightDrag", title: L10n.t("controls.mouse_mode_drag"), icon: "hand.draw.fill")
                                ]
                            )
                        }
                        .padding(6)
                        .background(isModeFocused ? NXTheme.primary.opacity(0.12) : Color.clear)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isModeFocused ? NXTheme.secondary : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}
