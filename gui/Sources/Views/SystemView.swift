import SwiftUI

public struct SystemView: View {
    @ObservedObject public var viewModel: AppViewModel
    @Namespace private var categoryNamespace
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header & Global Quick Actions
                    headerView
                        .frame(maxWidth: .infinity)
                    
                    // Category Navigation Tabs (Console Style)
                    categoryTabBar
                        .frame(maxWidth: .infinity)
                    
                    // Active Category Content
                    categoryContentView
                        .frame(maxWidth: .infinity)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .nxScrollEdgeEffect(edges: [.top, .bottom])
            .onChange(of: viewModel.isDeveloperMode) { isDev in
                if !isDev && viewModel.activeSettingsCategory == .developer {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        viewModel.activeSettingsCategory = .general
                        viewModel.settingsItemFocusIndex = 0
                    }
                }
            }
        }
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
    
    // MARK: - Header View
    private var headerView: some View {
        HStack(spacing: 12) {
            Text(viewModel.tr("system.title"))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(NXTheme.textPrimary)
            
            Spacer()
            
            // Developer Mode Switch Capsule
            HStack(spacing: 8) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(viewModel.isDeveloperMode ? NXTheme.primary : NXTheme.textSecondary)
                
                Text(viewModel.tr("build.dev_mode_title"))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(NXTheme.textPrimary)
                
                Toggle("", isOn: $viewModel.isDeveloperMode)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .nxGlassBar(
                in: Capsule(),
                fallbackFill: NXTheme.glassSurfaceElevated.opacity(0.65),
                fallbackStroke: NXTheme.borderSubtle
            )
            
            // Developer Mode Quick Actions
            if viewModel.isDeveloperMode {
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
    
    // MARK: - Category Tab Bar
    private var categoryTabBar: some View {
        HStack(spacing: 8) {
            ForEach(viewModel.availableSettingsCategories) { category in
                let isSelected = viewModel.activeSettingsCategory == category
                Button(action: {
                    SoundEffectService.shared.play(.tabSwitch)
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        viewModel.activeSettingsCategory = category
                        viewModel.settingsItemFocusIndex = 0
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: category.iconName)
                            .font(.system(size: 12, weight: .semibold))
                        Text(category.title(viewModel: viewModel))
                            .font(.system(size: 11.5, weight: isSelected ? .bold : .medium, design: .rounded))
                    }
                    .foregroundColor(isSelected ? .white : NXTheme.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        Group {
                            if isSelected {
                                Capsule()
                                    .fill(NXTheme.primary.opacity(0.85))
                                    .matchedGeometryEffect(id: "category_pill", in: categoryNamespace)
                            } else {
                                Capsule()
                                    .fill(NXTheme.glassSurfaceElevated.opacity(0.40))
                            }
                        }
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(isSelected ? Color.white.opacity(0.25) : NXTheme.borderSubtle, lineWidth: 0.8)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .nxNoFocusRing()
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
    
    // MARK: - Category Content View
    @ViewBuilder
    private var categoryContentView: some View {
        switch viewModel.activeSettingsCategory {
        case .general:
            SystemDirectoriesCard(viewModel: viewModel)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(viewModel.settingsItemFocusIndex == 0 ? NXTheme.secondary : Color.clear, lineWidth: 1.5)
                )
        case .updates:
            SystemUpdatesCard(viewModel: viewModel)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(viewModel.settingsItemFocusIndex == 0 ? NXTheme.secondary : Color.clear, lineWidth: 1.5)
                )
        case .toolchain:
            VStack(spacing: 14) {
                SystemKeysCard(viewModel: viewModel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(viewModel.settingsItemFocusIndex == 0 ? NXTheme.secondary : Color.clear, lineWidth: 1.5)
                    )
                
                SystemToolsCard(viewModel: viewModel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(viewModel.settingsItemFocusIndex == 1 ? NXTheme.secondary : Color.clear, lineWidth: 1.5)
                    )
            }
        case .developer:
            if viewModel.isDeveloperMode {
                VStack(spacing: 14) {
                    SystemRepoCard(viewModel: viewModel)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(viewModel.settingsItemFocusIndex == 0 ? NXTheme.secondary : Color.clear, lineWidth: 1.5)
                        )
                    
                    SystemStorageAndDiagnosticsCard(viewModel: viewModel)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(viewModel.settingsItemFocusIndex == 1 ? NXTheme.secondary : Color.clear, lineWidth: 1.5)
                        )
                }
            } else {
                SystemDirectoriesCard(viewModel: viewModel)
            }
        }
    }
}
