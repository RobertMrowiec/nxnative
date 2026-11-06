import SwiftUI

public struct BuildView: View {
    @ObservedObject public var viewModel: AppViewModel
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Pre-flight Environment Readiness Pill
                BuildReadinessPill(viewModel: viewModel)
                
                // 3-Step Segmented Capsule Stepper (Option A)
                BuildStepperHeaderView(viewModel: viewModel)
                
                // Active Wizard Step Content
                Group {
                    switch viewModel.buildWizardStep {
                    case 1:
                        BuildGameSection(viewModel: viewModel)
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    case 2:
                        BuildOptionsSection(viewModel: viewModel)
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    case 3:
                        BuildExecutionSection(viewModel: viewModel)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    default:
                        BuildGameSection(viewModel: viewModel)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: viewModel.buildWizardStep)
            }
            .padding(20)
        }
        .nxScrollEdgeEffect(edges: [.top, .bottom])
        .onAppear {
            if !viewModel.gameFolders.isEmpty && !viewModel.isBuilding {
                viewModel.scanAllGameFolders()
            }
        }
        .alert("Apple Command Line Tools", isPresented: $viewModel.showCltInstallAlert) {
            Button(viewModel.tr("common.ok"), role: .cancel) {}
        } message: {
            Text(viewModel.tr("build.apple_clt_dialog"))
        }
    }
}
