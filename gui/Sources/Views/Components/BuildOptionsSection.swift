import SwiftUI

public struct BuildOptionsSection: View {
    @ObservedObject public var viewModel: AppViewModel
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Selected Game Summary Banner
            SelectedGameSummaryCard(viewModel: viewModel)
            
            // Hero Platform Selection
            platformSelectionCard
            
            // Standard Gamer Options (Language & Output)
            gamerOptionsCard
            
            // Advanced Developer Options (Only if Developer Mode enabled)
            if viewModel.isDeveloperMode {
                BuildOptionsAdvancedSection(viewModel: viewModel)
            }
            
            // Step 2 Footer Navigation
            navigationFooter
        }
    }
    
    // MARK: - Platform Selection
    
    private var platformSelectionCard: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Label(viewModel.tr("build.step_2_gamer"), systemImage: "macbook.and.iphone")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(NXTheme.textPrimary)
                
                HStack(spacing: 12) {
                    platformCard(
                        platform: .macApp,
                        icon: "macbook.and.display",
                        titleKey: "build.platform_mac_title",
                        descKey: "build.platform_mac_desc"
                    )
                    
                    platformCard(
                        platform: .ios,
                        icon: "iphone.and.arrow.forward",
                        titleKey: "build.platform_ios_title",
                        descKey: "build.platform_ios_desc"
                    )
                }
            }
        }
    }
    
    private func platformCard(platform: TargetPlatform, icon: String, titleKey: String, descKey: String) -> some View {
        let isSelected = viewModel.platform == platform
        let isSwitch2OrNup = (viewModel.selectedGame?.isSwitch2 == true) || (viewModel.selectedGame?.isNup == true)
        let isIosDisabled = (platform == .ios && isSwitch2OrNup)

        return Button(action: {
            guard !isIosDisabled else { return }
            SoundEffectService.shared.play(.click)
            viewModel.platform = platform
        }) {
            ZStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: icon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(isSelected && !isIosDisabled ? NXTheme.primary : NXTheme.textSecondary)
                        
                        Text(viewModel.tr(titleKey))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(NXTheme.textPrimary)
                        
                        Spacer()
                        
                        if isSelected && !isIosDisabled {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(red: 0.13, green: 0.77, blue: 0.37))
                                .font(.system(size: 16))
                        }
                    }
                    
                    Text(viewModel.tr(descKey))
                        .font(.system(size: 11))
                        .foregroundColor(NXTheme.textSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
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
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected && !isIosDisabled ? NXTheme.primary.opacity(0.18) : NXTheme.glassSurfaceElevated.opacity(0.5))
            )
            .overlay {
                if isSelected && !isIosDisabled {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(NXTheme.primary.opacity(0.6), lineWidth: 1)
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(NXTheme.specularRim, lineWidth: 1)
                }
            }
        }
        .buttonStyle(NXPressableButtonStyle())
        .disabled(isIosDisabled)
        .nxNoFocusRing()
    }
    
    // MARK: - Gamer Options (Language & Output)
    
    private var gamerOptionsCard: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.tr("build.game_language_label"))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(NXTheme.textPrimary)
                        
                        let currentLabel = AppViewModel.availableLanguages.first(where: { $0.code == viewModel.selectedLanguage })?.label ?? "Game Default"
                        Menu {
                            ForEach(AppViewModel.availableLanguages, id: \.code) { item in
                                Button(action: {
                                    SoundEffectService.shared.play(.click)
                                    viewModel.selectedLanguage = item.code
                                }) {
                                    if viewModel.selectedLanguage == item.code {
                                        Label(item.label, systemImage: "checkmark")
                                    } else {
                                        Text(item.label)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "globe")
                                    .font(.system(size: 12))
                                    .foregroundColor(NXTheme.secondary)
                                Text(currentLabel)
                                    .font(.system(size: 12, weight: .medium))
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 9))
                                    .foregroundColor(NXTheme.textSecondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(NXTheme.glassSurfaceElevated.opacity(0.8))
                            .cornerRadius(8)
                        }
                        .menuStyle(.borderlessButton)
                    }
                    
                    Spacer()
                }
                
                Divider().opacity(0.15)
                
                Toggle(viewModel.tr("build.output_folder"), isOn: $viewModel.useCustomOutputFolder)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(NXTheme.textPrimary)
                
                if viewModel.useCustomOutputFolder {
                    PathPickerRow(
                        title: viewModel.tr("build.output_folder"),
                        icon: "arrow.down.doc.fill",
                        path: viewModel.customOutputFolder?.path,
                        placeholder: viewModel.tr("common.choose_folder"),
                        actionTitle: viewModel.tr("common.choose")
                    ) {
                        viewModel.selectOutputFolder()
                    }
                }
            }
        }
    }
    
    // MARK: - Navigation Footer
    
    private var navigationFooter: some View {
        GlassCard(padding: 12) {
            HStack {
                Button(action: {
                    SoundEffectService.shared.play(.click)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                        viewModel.goToWizardStep(1)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left.circle.fill")
                        Text(viewModel.tr("build.back_to_select"))
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
                .buttonStyle(NXSecondaryButtonStyle())
                
                Spacer()
                
                Button(action: {
                    SoundEffectService.shared.play(.click)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                        viewModel.startBuild()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text(viewModel.tr("build.port_game_now"))
                    }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(NXPrimaryButtonStyle())
                .disabled(!viewModel.canStartBuild)
            }
        }
    }
}
