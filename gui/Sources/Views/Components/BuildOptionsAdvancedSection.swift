import SwiftUI

public struct BuildOptionsAdvancedSection: View {
    @ObservedObject public var viewModel: AppViewModel
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 14) {
                Label(viewModel.tr("build.dev_mode_title"), systemImage: "hammer.fill")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(NXTheme.secondary)
                
                // Identity
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.tr("build.app_name_label"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(NXTheme.textSecondary)
                        NXLiquidGlassTextField("Custom name", text: $viewModel.appName)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.tr("build.bundle_id_label"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(NXTheme.textSecondary)
                        NXLiquidGlassTextField("org.nxnative.game", text: $viewModel.bundleId)
                    }
                }
                
                Divider().opacity(0.15)
                
                // Technical Switches
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(viewModel.tr("build.opt_fps"), isOn: $viewModel.showFps)
                        .font(.system(size: 12))
                        .foregroundColor(NXTheme.textPrimary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Toggle(viewModel.tr("build.opt_keep_extracted"), isOn: $viewModel.keepExtracted)
                            .font(.system(size: 12))
                            .foregroundColor(NXTheme.textPrimary)
                            .disabled(viewModel.isKeepExtractedLocked)
                        
                        if let reason = viewModel.keepExtractedLockReason {
                            Text(reason)
                                .font(.system(size: 10))
                                .foregroundColor(NXTheme.textMuted)
                                .padding(.leading, 20)
                        }
                    }
                    
                    Toggle(viewModel.tr("build.opt_allow_other_metal"), isOn: $viewModel.allowOtherMetal)
                        .font(.system(size: 12))
                        .foregroundColor(NXTheme.textPrimary)
                    
                    Toggle(viewModel.tr("build.opt_survey_only"), isOn: $viewModel.surveyOnly)
                        .font(.system(size: 12))
                        .foregroundColor(NXTheme.textPrimary)
                }
                
                // iOS RomFS Slider (if iOS selected)
                if viewModel.platform == .ios {
                    Divider().opacity(0.15)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(viewModel.tr("port_modal.romfs_split_title", Int(viewModel.autoRomfsSplitLimitGB)))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(NXTheme.textSecondary)
                            Spacer()
                        }
                        Slider(
                            value: Binding(
                                get: { viewModel.autoRomfsSplitLimitGB },
                                set: { val in
                                    viewModel.autoRomfsSplitLimitGB = val
                                    viewModel.userDidManuallyOverrideRomfsSeparate = false
                                    viewModel.evaluateAutoRomfsSplit()
                                }
                            ),
                            in: 2.0...16.0,
                            step: 1.0
                        )
                        .accentColor(NXTheme.primary)
                    }
                }
            }
        }
    }
}
