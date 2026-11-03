import SwiftUI
import AppKit

// MARK: - Platform Selector View
public struct PortPlatformSelectorView: View {
    @ObservedObject public var viewModel: AppViewModel
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        HStack(spacing: 10) {
            platformChoiceButton(
                platform: .macApp,
                icon: "macbook.and.display",
                title: viewModel.tr("port_modal.platform_mac_title"),
                desc: viewModel.tr("port_modal.platform_mac_desc"),
                index: 0
            )
            
            platformChoiceButton(
                platform: .ios,
                icon: "iphone.and.arrow.forward",
                title: viewModel.tr("port_modal.platform_ios_title"),
                desc: viewModel.tr("port_modal.platform_ios_desc"),
                index: 1
            )
        }
    }
    
    private func platformChoiceButton(platform: TargetPlatform, icon: String, title: String, desc: String, index: Int) -> some View {
        let isSelected = viewModel.platform == platform
        let isFocused = viewModel.portModalFocusIndex == index
        let isSwitch2 = viewModel.selectedGame?.isSwitch2 == true
        let isIosDisabled = (platform == .ios && isSwitch2)

        return Button(action: {
            guard !isIosDisabled else { return }
            SoundEffectService.shared.play(.click)
            viewModel.platform = platform
            viewModel.portModalFocusIndex = index
        }) {
            ZStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(isSelected ? NXTheme.primary : NXTheme.textSecondary)
                        Text(title)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(NXTheme.textPrimary)
                        Spacer()
                        if isSelected && !isIosDisabled {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color.green)
                                .font(.system(size: 13))
                        }
                    }
                    Text(desc)
                        .font(.system(size: 10))
                        .foregroundColor(NXTheme.textSecondary)
                        .lineLimit(2)
                }
                .opacity(isIosDisabled ? 0.35 : 1.0)

                if isIosDisabled {
                    Text(viewModel.tr("port_modal.coming_soon"))
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3.5)
                        .nxGlassBar(
                            in: Capsule(),
                            tint: Color(red: 0.95, green: 0.48, blue: 0.16).opacity(0.75),
                            fallbackFill: Color(red: 0.95, green: 0.48, blue: 0.16).opacity(0.90)
                        )
                        .shadow(color: Color.black.opacity(0.65), radius: 5, x: 0, y: 2)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected && !isIosDisabled ? NXTheme.primary.opacity(0.18) : NXTheme.glassSurfaceElevated.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isFocused ? AnyShapeStyle(NXTheme.secondary) : (isSelected && !isIosDisabled ? AnyShapeStyle(NXTheme.primary.opacity(0.7)) : AnyShapeStyle(NXTheme.specularRim)),
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .shadow(color: isFocused ? NXTheme.secondary.opacity(0.6) : Color.clear, radius: 6)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isIosDisabled)
        .nxNoFocusRing()
    }
}

// MARK: - iOS Immediate Auto-Deploy vs Later Choice View
public struct PortIosDeployChoiceView: View {
    @ObservedObject public var viewModel: AppViewModel
    @ObservedObject private var deviceService = DeviceDeploymentService.shared
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        GlassCard(padding: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Label(viewModel.tr("port_modal.ios_deploy_prompt"), systemImage: "iphone.badge.play")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(NXTheme.textPrimary)
                
                VStack(spacing: 6) {
                    deployChoiceRow(
                        title: viewModel.tr("port_modal.ios_deploy_now"),
                        subtitle: deviceService.selectedDevice != nil ? "\(deviceService.selectedDevice!.name) (\(deviceService.selectedDevice!.model))" : viewModel.tr("port_modal.ios_deploy_now_desc"),
                        icon: "bolt.fill",
                        isSelected: viewModel.autoDeployToDeviceOnFinish,
                        index: 2
                    ) {
                        viewModel.autoDeployToDeviceOnFinish = true
                        viewModel.portModalFocusIndex = 2
                    }
                    
                    deployChoiceRow(
                        title: viewModel.tr("port_modal.ios_deploy_later"),
                        subtitle: viewModel.tr("port_modal.ios_deploy_later_desc"),
                        icon: "clock.arrow.circlepath",
                        isSelected: !viewModel.autoDeployToDeviceOnFinish,
                        index: 3
                    ) {
                        viewModel.autoDeployToDeviceOnFinish = false
                        viewModel.portModalFocusIndex = 3
                    }
                }
                
                if viewModel.autoDeployToDeviceOnFinish {
                    Divider().opacity(0.15)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        // Device Selection Row
                        HStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "iphone.gen3")
                                    .foregroundColor(NXTheme.primary)
                                    .font(.system(size: 12))
                                Text(L10n.t("settings_modal.install_on_label"))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(NXTheme.textPrimary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                SoundEffectService.shared.play(.click)
                                deviceService.refreshDevicesAndTeams()
                            }) {
                                HStack(spacing: 3) {
                                    if deviceService.isDetecting {
                                        ProgressView().controlSize(.mini)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                    }
                                    Text(L10n.t("settings_modal.refresh_label"))
                                }
                            }
                            .buttonStyle(NXSecondaryButtonStyle())
                            .controlSize(.mini)
                            .disabled(deviceService.isDetecting)
                            
                            if deviceService.connectedDevices.isEmpty {
                                Text(L10n.t("settings_modal.no_devices"))
                                    .font(.system(size: 10))
                                    .foregroundColor(NXTheme.textSecondary)
                            } else {
                                Picker("", selection: $deviceService.selectedDevice) {
                                    ForEach(deviceService.connectedDevices) { dev in
                                        Text("\(dev.name) (\(dev.model) • iOS \(dev.osVersion))")
                                            .tag(Optional(dev))
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .frame(maxWidth: 220)
                                
                                Circle()
                                    .fill(Color(red: 0.13, green: 0.77, blue: 0.37))
                                    .frame(width: 6, height: 6)
                            }
                        }
                        
                        // Signing Team Row
                        HStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "person.badge.shield.checkmark")
                                    .foregroundColor(NXTheme.primary)
                                    .font(.system(size: 12))
                                Text(L10n.t("settings_modal.signing_team_label"))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(NXTheme.textPrimary)
                            }
                            
                            Spacer()
                            
                            if deviceService.signingTeams.isEmpty {
                                Text(L10n.t("settings_modal.no_teams_found"))
                                    .font(.system(size: 10))
                                    .foregroundColor(NXTheme.textSecondary)
                            } else {
                                Picker("", selection: $deviceService.selectedSigningTeam) {
                                    Text(L10n.t("settings.ios_unsigned_sideloading")).tag(Optional<DeveloperSigningTeam>.none)
                                    ForEach(deviceService.signingTeams) { team in
                                        Text(team.displayName)
                                            .tag(Optional(team))
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .frame(maxWidth: 240)
                            }
                        }
                    }
                    .padding(8)
                    .background(NXTheme.glassSurfaceElevated.opacity(0.35))
                    .cornerRadius(8)
                }
            }
        }
        .onAppear {
            if deviceService.connectedDevices.isEmpty || deviceService.signingTeams.isEmpty {
                deviceService.refreshDevicesAndTeams()
            }
        }
    }
    
    private func deployChoiceRow(title: String, subtitle: String? = nil, icon: String, isSelected: Bool, index: Int, action: @escaping () -> Void) -> some View {
        let isFocused = viewModel.portModalFocusIndex == index
        return Button(action: {
            SoundEffectService.shared.play(.click)
            action()
        }) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? NXTheme.primary : NXTheme.textSecondary)
                    .font(.system(size: 12))
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? NXTheme.primary : NXTheme.textSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(NXTheme.textPrimary)
                    if let sub = subtitle, !sub.isEmpty {
                        Text(sub)
                            .font(.system(size: 9.5))
                            .foregroundColor(NXTheme.textSecondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? NXTheme.primary.opacity(0.12) : Color.clear)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(isFocused ? NXTheme.secondary : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .nxNoFocusRing()
    }
}

// MARK: - Advanced Settings Collapsible View
public struct PortAdvancedSettingsView: View {
    @ObservedObject public var viewModel: AppViewModel
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            let isAdvFocused = viewModel.portModalFocusIndex == 4
            Button(action: {
                SoundEffectService.shared.play(.click)
                withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
                    viewModel.isPortAdvancedExpanded.toggle()
                    viewModel.portModalFocusIndex = 4
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.isPortAdvancedExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(NXTheme.secondary)
                    Text(viewModel.tr("port_modal.advanced_settings"))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(NXTheme.textSecondary)
                    Spacer()
                }
                .padding(6)
                .background(isAdvFocused ? NXTheme.secondary.opacity(0.15) : Color.clear)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isAdvFocused ? NXTheme.secondary : Color.clear, lineWidth: 1.5)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .nxNoFocusRing()
            
            if viewModel.isPortAdvancedExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    // RomFS Split Slider
                    let isSliderFocused = viewModel.portModalFocusIndex == 5
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(String(format: viewModel.tr("port_modal.romfs_split_title"), Int(viewModel.autoRomfsSplitLimitGB)))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(NXTheme.textPrimary)
                            Spacer()
                            Text("\(Int(viewModel.autoRomfsSplitLimitGB)) GB")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(NXTheme.secondary)
                        }
                        Text(viewModel.tr("port_modal.romfs_split_desc"))
                            .font(.system(size: 10))
                            .foregroundColor(NXTheme.textSecondary)
                        
                        NXLiquidGlassSlider(
                            value: $viewModel.autoRomfsSplitLimitGB,
                            in: 2.0...16.0,
                            step: 1.0,
                            accentColor: NXTheme.primary
                        )
                        .padding(4)
                        .background(isSliderFocused ? NXTheme.secondary.opacity(0.12) : Color.clear)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(isSliderFocused ? NXTheme.secondary : Color.clear, lineWidth: 1.5)
                        )
                    }
                    
                    Divider().opacity(0.15)
                    
                    // Technical Toggles
                    VStack(alignment: .leading, spacing: 6) {
                        portToggleRow(title: viewModel.tr("build.opt_fps"), isOn: $viewModel.showFps, index: 6)
                        portToggleRow(title: viewModel.tr("build.opt_keep_extracted"), isOn: $viewModel.keepExtracted, index: 7)
                        portToggleRow(title: viewModel.tr("build.opt_allow_other_metal"), isOn: $viewModel.allowOtherMetal, index: 8)
                        portToggleRow(title: viewModel.tr("build.opt_survey_only"), isOn: $viewModel.surveyOnly, index: 9)
                    }
                }
                .padding(10)
                .background(NXTheme.glassSurfaceElevated.opacity(0.40))
                .cornerRadius(10)
            }
        }
    }

    private func portToggleRow(title: String, isOn: Binding<Bool>, index: Int) -> some View {
        let isFocused = viewModel.portModalFocusIndex == index
        return Toggle(title, isOn: isOn)
            .font(.system(size: 11))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(isFocused ? NXTheme.secondary.opacity(0.15) : Color.clear)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(isFocused ? NXTheme.secondary : Color.clear, lineWidth: 1.5)
            )
            .onTapGesture {
                viewModel.portModalFocusIndex = index
            }
    }
}
