import SwiftUI

public struct SystemToolsCard: View {
    @ObservedObject public var viewModel: AppViewModel
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack(spacing: 10) {
                    Label(viewModel.tr("system.tools_title"), systemImage: "wrench.and.screwdriver.fill")
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(NXTheme.textPrimary)
                        .help(viewModel.tr("system.tools_help"))
                    
                    Spacer()
                    
                    StatusBadge(
                        isPositive: viewModel.prerequisites.allSatisfied,
                        text: viewModel.prerequisites.allSatisfied ? viewModel.tr("system.deps_ready") : viewModel.tr("system.deps_missing_count", viewModel.prerequisites.missingList.count)
                    )
                }
                
                if viewModel.isDeveloperMode {
                    developerModeContent
                } else {
                    simpleModeContent
                }
            }
        }
    }
    
    // MARK: - Simple Mode (Normal Users: 1 Button to Install All + Compact Log/Progress)
    @ViewBuilder
    private var simpleModeContent: some View {
        VStack(spacing: 12) {
            if !viewModel.prerequisites.allSatisfied {
                // Single button to install all
                Button(action: {
                    SoundEffectService.shared.play(.click)
                    viewModel.installAllMissingDependencies(openSheet: false)
                }) {
                    HStack(spacing: 8) {
                        if viewModel.isInstallingDependency {
                            ProgressView()
                                .controlSize(.small)
                            Text(viewModel.tr("common.installing"))
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                            Text(viewModel.tr("system.install_all"))
                        }
                    }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(NXAccentButtonStyle())
                .disabled(viewModel.isInstallingDependency)
            } else {
                // Everything is ready
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(red: 0.13, green: 0.77, blue: 0.37))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.tr("system.all_tools_ready"))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(NXTheme.textPrimary)
                        Text(viewModel.tr("system.tools_help"))
                            .font(.system(size: 11))
                            .foregroundColor(NXTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        SoundEffectService.shared.play(.click)
                        viewModel.refreshPrerequisites()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text(viewModel.tr("system.repair_recheck"))
                        }
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .buttonStyle(NXSecondaryButtonStyle())
                    .controlSize(.small)
                }
                .padding(12)
                .nxGlassCard(cornerRadius: 10, isNested: true)
            }
            
            // Inline compact log & progress
            if viewModel.isInstallingDependency || !viewModel.installerLogs.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(viewModel.isInstallingDependency ? viewModel.tr("common.installing") : "Log de Instalação")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(NXTheme.textSecondary)
                        Spacer()
                        if viewModel.isInstallingDependency {
                            ProgressView().controlSize(.mini)
                        }
                    }
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 3) {
                                ForEach(Array(viewModel.installerLogs.enumerated()), id: \.offset) { idx, line in
                                    let isError = line.lowercased().contains("error") || line.lowercased().contains("failed")
                                    Text(line)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(isError ? Color.red : NXTheme.textPrimary)
                                        .id(idx)
                                }
                            }
                            .padding(8)
                        }
                        .frame(height: 100)
                        .nxGlassCard(cornerRadius: 8, isNested: true)
                        .onChange(of: viewModel.installerLogs.count) { _ in
                            if let last = viewModel.installerLogs.indices.last {
                                proxy.scrollTo(last, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Developer Mode Content (Granular Dependency Control)
    @ViewBuilder
    private var developerModeContent: some View {
        VStack(spacing: 12) {
            // Missing Dependencies Action Callout
            if !viewModel.prerequisites.allSatisfied {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(NXTheme.tertiary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.tr("system.missing_deps_title", viewModel.prerequisites.missingList.count))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(NXTheme.textPrimary)
                        Text(viewModel.tr("system.missing_deps_desc"))
                            .font(.system(size: 11))
                            .foregroundColor(NXTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        SoundEffectService.shared.play(.click)
                        viewModel.installAllMissingDependencies()
                    }) {
                        HStack(spacing: 6) {
                            if viewModel.isInstallingDependency {
                                ProgressView().controlSize(.small)
                                Text(viewModel.tr("common.installing"))
                            } else {
                                Image(systemName: "play.fill")
                                Text(viewModel.tr("build.install_all_seq"))
                            }
                        }
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .buttonStyle(NXAccentButtonStyle())
                    .disabled(viewModel.isInstallingDependency)
                }
                .padding(12)
                .nxGlassCard(cornerRadius: 10, isNested: true)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(NXTheme.tertiary.opacity(0.35), lineWidth: 1)
                )
            }
            
            // Detailed Dependency rows list
            VStack(spacing: 8) {
                ForEach(viewModel.prerequisites.list) { item in
                    DependencyRow(item: item, viewModel: viewModel)
                }
            }
            
            // Bottom Action Bar
            HStack {
                Button(action: {
                    SoundEffectService.shared.play(.click)
                    viewModel.refreshPrerequisites()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text(viewModel.tr("system.repair_recheck"))
                    }
                }
                .buttonStyle(NXSecondaryButtonStyle())
                .controlSize(.small)
                
                Spacer()
                
                Button(viewModel.tr("system.repair_all")) {
                    SoundEffectService.shared.play(.click)
                    viewModel.repairAllDependencies()
                }
                .buttonStyle(NXSecondaryButtonStyle())
                .controlSize(.small)
                .help(viewModel.tr("system.repair_all_help"))
            }
            .padding(.top, 4)
        }
    }
}
