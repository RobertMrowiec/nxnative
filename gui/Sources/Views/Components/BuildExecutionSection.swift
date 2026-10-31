import SwiftUI

public struct BuildExecutionSection: View {
    @ObservedObject public var viewModel: AppViewModel
    @State private var showTechLogs: Bool = false
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            if viewModel.isBuilding {
                activeExecutionCard
            } else if let successPath = viewModel.buildSuccessPath {
                BuildCelebrationCard(viewModel: viewModel, outputPath: successPath)
            } else if let error = viewModel.buildError {
                failedExecutionCard(errorMessage: error)
            } else {
                idleCard
            }
        }
    }
    
    // MARK: - Active Build Pipeline Card
    
    private var activeExecutionCard: some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text(viewModel.currentStageName)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(NXTheme.textPrimary)
                        }
                        if !viewModel.currentStepName.isEmpty {
                            Text(viewModel.currentStepName)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(NXTheme.secondary)
                                .padding(.leading, 24)
                        }
                    }
                    
                    Spacer()
                    
                    if let eta = viewModel.etaSeconds, eta > 0 {
                        let minutes = Int(eta) / 60
                        let seconds = Int(eta) % 60
                        Text(String(format: "ETA: ~%02d:%02d", minutes, seconds))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(NXTheme.textSecondary)
                    }
                    
                    Text("\(Int(viewModel.progressFraction * 100))%")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(NXTheme.primary)
                }
                
                ProgressView(value: viewModel.progressFraction)
                    .progressViewStyle(.linear)
                    .tint(NXTheme.primary)
                
                // Live Pipeline Stages Stepper
                if !viewModel.buildStages.isEmpty {
                    BuildStageStepperView(viewModel: viewModel)
                }
                
                // Live Logs (Always in Developer Mode, Optional in Gamer Mode)
                if viewModel.isDeveloperMode || showTechLogs {
                    BuildLiveLogsDrawer(viewModel: viewModel)
                }
                
                HStack {
                    Button(action: {
                        viewModel.cancelBuild()
                    }) {
                        Label(viewModel.tr("build.cancel"), systemImage: "xmark.circle.fill")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    
                    Spacer()
                    
                    if !viewModel.isDeveloperMode {
                        Button(action: {
                            withAnimation {
                                showTechLogs.toggle()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: showTechLogs ? "chevron.up" : "chevron.down")
                                Text(showTechLogs ? viewModel.tr("build.hide_tech_logs") : viewModel.tr("build.show_tech_logs"))
                            }
                            .font(.system(size: 11))
                            .foregroundColor(NXTheme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    // MARK: - Failure State
    
    private func failedExecutionCard(errorMessage: String) -> some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.octagon.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 24))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.tr("build.port_failed_title"))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(NXTheme.textPrimary)
                        Text(errorMessage)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.red.opacity(0.9))
                            .lineLimit(3)
                    }
                }
                
                BuildLiveLogsDrawer(viewModel: viewModel)
                
                HStack {
                    Button(action: {
                        viewModel.resetWizard()
                    }) {
                        Text(viewModel.tr("build.try_again"))
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(NXPrimaryButtonStyle())
                    
                    Spacer()
                    
                    Button(viewModel.tr("build.open_console")) {
                        viewModel.selectedTab = 5
                    }
                    .buttonStyle(.link)
                    .font(.system(size: 11))
                    .foregroundColor(NXTheme.secondary)
                }
            }
        }
    }
    
    private var idleCard: some View {
        GlassCard(padding: 24) {
            VStack(spacing: 8) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 32))
                    .foregroundColor(NXTheme.textMuted)
                Text(viewModel.tr("build.no_task_title"))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(NXTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
