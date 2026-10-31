import SwiftUI

public struct SystemView: View {
    @ObservedObject public var viewModel: AppViewModel
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Header & Action Bar
                headerView
                
                // Developer Mode Switch Card (strictly in Settings)
                developerModeCard
                
                VStack(spacing: 12) {
                    SystemKeysCard(viewModel: viewModel)
                    SystemToolsCard(viewModel: viewModel)
                }
                
                if viewModel.isDeveloperMode {
                    VStack(spacing: 12) {
                        SystemRepoCard(viewModel: viewModel)
                        SystemDirectoriesCard(viewModel: viewModel)
                        SystemStorageAndDiagnosticsCard(viewModel: viewModel)
                        SystemPatchesCard(viewModel: viewModel)
                    }
                }
            }
            .padding(20)
        }
        .nxScrollEdgeEffect(edges: [.top, .bottom])
        .sheet(isPresented: $viewModel.showRyujinxNotFoundSheet) {
            RyujinxKeyMissingSheet(viewModel: viewModel)
                .environment(\.nxLiquidGlass, viewModel.liquidGlassEnvironment)
        }
        .sheet(isPresented: $viewModel.showInstallerSheet) {
            InstallerSheetView(viewModel: viewModel)
                .environment(\.nxLiquidGlass, viewModel.liquidGlassEnvironment)
        }
        .alert("Apple Command Line Tools", isPresented: $viewModel.showCltInstallAlert) {
            Button(viewModel.tr("common.ok"), role: .cancel) {}
        } message: {
            Text(viewModel.tr("build.apple_clt_dialog"))
        }
        .confirmationDialog(
            viewModel.tr("system.uninstall_title", viewModel.dependencyToUninstall?.name ?? "Tool"),
            isPresented: $viewModel.showUninstallConfirm,
            titleVisibility: .visible
        ) {
            Button(viewModel.tr("system.uninstall_button"), role: .destructive) {
                viewModel.executeUninstall()
            }
            Button(viewModel.tr("common.cancel"), role: .cancel) {}
        } message: {
            Text(viewModel.tr("system.uninstall_message"))
        }
    }
    
    private var headerView: some View {
        HStack {
            Text(viewModel.tr("system.title"))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(NXTheme.textPrimary)
            
            Spacer()
            
            NXGlassContainer(spacing: 8) {
                HStack(spacing: 8) {
                    if !viewModel.prerequisites.missingList.isEmpty {
                        Button(action: {
                            SoundEffectService.shared.play(.click)
                            viewModel.installAllMissingDependencies()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.circle.fill")
                                Text(viewModel.tr("system.install_all_missing", viewModel.prerequisites.missingList.count))
                            }
                        }
                        .buttonStyle(NXAccentButtonStyle())
                        .help(viewModel.tr("system.install_all_help"))
                    } else {
                        Button(action: {
                            SoundEffectService.shared.play(.click)
                            viewModel.repairAllDependencies()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text(viewModel.tr("system.repair_all"))
                            }
                        }
                        .buttonStyle(NXSecondaryButtonStyle())
                        .help(viewModel.tr("system.repair_all_help"))
                    }
                }
            }
        }
    }
    
    private var developerModeCard: some View {
        GlassCard(padding: 14) {
            HStack(spacing: 12) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 20))
                    .foregroundColor(viewModel.isDeveloperMode ? NXTheme.primary : NXTheme.textSecondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.tr("build.dev_mode_title"))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(NXTheme.textPrimary)
                    Text(viewModel.tr("build.dev_mode_desc"))
                        .font(.system(size: 11))
                        .foregroundColor(NXTheme.textSecondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $viewModel.isDeveloperMode)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }
    }
}
