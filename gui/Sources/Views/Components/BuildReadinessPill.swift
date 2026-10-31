import SwiftUI

public struct BuildReadinessPill: View {
    @ObservedObject public var viewModel: AppViewModel
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        Group {
            if !viewModel.isNxnativeValid {
                missingNxnativeCard
            } else if !viewModel.isProdKeysValid {
                missingKeysCard
            } else if !viewModel.prerequisites.allSatisfied {
                missingToolsCard
            } else {
                readyStatusPill
            }
        }
    }
    
    private var readyStatusPill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(red: 0.13, green: 0.77, blue: 0.37))
                .frame(width: 7, height: 7)
            
            Text(viewModel.tr("build.env_ready_pill"))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(NXTheme.textSecondary)
            
            Spacer()
        }
        .padding(.horizontal, 4)
    }
    
    private var missingNxnativeCard: some View {
        GlassCard(padding: 12) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(NXTheme.tertiary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.tr("build.core_repo_missing"))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(NXTheme.textPrimary)
                    Text(viewModel.tr("build.core_repo_missing_desc"))
                        .font(.system(size: 11))
                        .foregroundColor(NXTheme.textSecondary)
                }
                
                Spacer()
                
                if viewModel.isCloningRepository {
                    ProgressView().controlSize(.small)
                } else {
                    Button(viewModel.tr("build.download_setup_click")) {
                        viewModel.cloneNxnativeRepository()
                    }
                    .buttonStyle(NXPrimaryButtonStyle())
                    .controlSize(.small)
                }
            }
        }
    }
    
    private var missingKeysCard: some View {
        GlassCard(padding: 12) {
            HStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .font(.system(size: 20))
                    .foregroundColor(NXTheme.tertiary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.tr("build.keys_missing_title"))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(NXTheme.textPrimary)
                    Text(viewModel.tr("build.keys_missing_desc"))
                        .font(.system(size: 11))
                        .foregroundColor(NXTheme.textSecondary)
                }
                
                Spacer()
                
                Button(viewModel.tr("common.choose")) {
                    viewModel.selectProdKeysFile()
                }
                .buttonStyle(NXSecondaryButtonStyle())
                .controlSize(.small)
            }
        }
    }
    
    private var missingToolsCard: some View {
        GlassCard(padding: 12) {
            HStack(spacing: 12) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 20))
                    .foregroundColor(NXTheme.tertiary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.tr("build.readiness_missing_tools"))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(NXTheme.textPrimary)
                    Text(viewModel.tr("build.readiness_missing_tools_desc"))
                        .font(.system(size: 11))
                        .foregroundColor(NXTheme.textSecondary)
                }
                
                Spacer()
                
                Button(viewModel.tr("system.install_all")) {
                    viewModel.installAllMissingDependencies()
                }
                .buttonStyle(NXPrimaryButtonStyle())
                .controlSize(.small)
            }
        }
    }
}
