import SwiftUI
import AppKit

public struct SystemUpdatesCard: View {
    @ObservedObject public var viewModel: AppViewModel
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.9.9"
    }
    
    private var currentCommit: String {
        if let commit = viewModel.updateInfo?.localCommit, !commit.isEmpty {
            return commit
        }
        return UpdateCheckerService.shared.getLocalCommit(nxnativePath: viewModel.nxnativePath)
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // MARK: - Current Version & Status Header
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(NXTheme.primaryGradient)
                                .frame(width: 44, height: 44)
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text("NxNative Launcher")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(NXTheme.textPrimary)
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "tag.fill")
                                        .font(.system(size: 9, weight: .bold))
                                    Text("v\(appVersion) · \(currentCommit)")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(NXTheme.primary.opacity(0.55))
                                .clipShape(Capsule())
                            }
                            
                            Text("GitLab: rennan-group2/nxnative_Launcher · Upstream: seedds/nxnative")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(NXTheme.textSecondary)
                        }
                        
                        Spacer()
                        
                        // Status Badge
                        if viewModel.isCheckingUpdate {
                            StatusBadge(isPositive: true, text: viewModel.tr("updates.status_checking"))
                        } else if viewModel.isApplyingUpdate || viewModel.isSyncingUpstream {
                            StatusBadge(isPositive: true, text: viewModel.tr("updates.status_updating"))
                        } else if let info = viewModel.updateInfo, info.hasUpdate {
                            StatusBadge(isPositive: true, text: viewModel.tr("updates.status_available"))
                        } else {
                            StatusBadge(isPositive: true, text: viewModel.tr("updates.status_latest"))
                        }
                    }
                    
                    Divider().opacity(0.2)
                    
                    // State Banner & Action Row
                    if viewModel.isCheckingUpdate {
                        HStack(spacing: 12) {
                            ProgressView().controlSize(.small)
                            Text(viewModel.tr("updates.checking_desc"))
                                .font(.system(size: 12))
                                .foregroundColor(NXTheme.textSecondary)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    } else if viewModel.updateCompletedReadyToRelaunch {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 24))
                                .foregroundColor(Color(red: 0.13, green: 0.77, blue: 0.37))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModel.tr("updates.completed_title"))
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text(viewModel.updateSuccessBanner ?? viewModel.tr("updates.completed_desc"))
                                    .font(.system(size: 11))
                                    .foregroundColor(NXTheme.textSecondary)
                            }
                            Spacer()
                            Button(viewModel.tr("updates.relaunch_now")) {
                                SoundEffectService.shared.play(.click)
                                viewModel.relaunchUpdatedLauncher()
                            }
                            .buttonStyle(NXPrimaryButtonStyle())
                        }
                        .padding(12)
                        .nxGlassCard(cornerRadius: 12, tint: Color(red: 0.13, green: 0.77, blue: 0.37).opacity(0.25))
                    } else if let err = viewModel.updateErrorBanner {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModel.tr("updates.warning_title"))
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                Text(err)
                                    .font(.system(size: 11))
                                    .foregroundColor(NXTheme.textSecondary)
                            }
                            Spacer()
                            Button(viewModel.tr("updates.try_again")) {
                                SoundEffectService.shared.play(.click)
                                viewModel.checkForUpdates()
                            }
                            .buttonStyle(NXSecondaryButtonStyle())
                        }
                        .padding(12)
                        .nxGlassCard(cornerRadius: 12, tint: Color.orange.opacity(0.25))
                    } else if let info = viewModel.updateInfo, info.hasUpdate {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 22))
                                .foregroundColor(NXTheme.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModel.tr("updates.found_title"))
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text(viewModel.tr("updates.found_desc", info.localCommit, info.remoteCommit, info.commitMessages.count))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(NXTheme.textSecondary)
                            }
                            Spacer()
                            Button(viewModel.tr("updates.update_to_new_version")) {
                                SoundEffectService.shared.play(.click)
                                viewModel.applyUpdate(autoRelaunch: true)
                            }
                            .buttonStyle(NXPrimaryButtonStyle())
                        }
                        .padding(12)
                        .nxGlassCard(cornerRadius: 12, tint: NXTheme.primary.opacity(0.25))
                    } else {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color(red: 0.13, green: 0.77, blue: 0.37))
                            Text(viewModel.tr("updates.already_latest_desc"))
                                .font(.system(size: 12))
                                .foregroundColor(NXTheme.textSecondary)
                            Spacer()
                        }
                    }
                    
                    // Action Buttons Bar
                    HStack(spacing: 10) {
                        Button(action: {
                            SoundEffectService.shared.play(.click)
                            viewModel.checkForUpdates()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                Text(viewModel.tr("updates.check_updates"))
                            }
                        }
                        .buttonStyle(NXSecondaryButtonStyle())
                        .disabled(viewModel.isCheckingUpdate || viewModel.isApplyingUpdate || viewModel.isSyncingUpstream)
                        
                        if let info = viewModel.updateInfo, info.hasUpdate {
                            Button(action: {
                                SoundEffectService.shared.play(.click)
                                viewModel.applyUpdate(autoRelaunch: true)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.down.circle.fill")
                                    Text(viewModel.tr("updates.update_now"))
                                }
                            }
                            .buttonStyle(NXPrimaryButtonStyle())
                            .disabled(viewModel.isApplyingUpdate)
                        }
                        
                        if viewModel.isDeveloperMode {
                            Button(action: {
                                SoundEffectService.shared.play(.click)
                                viewModel.syncUpstreamEngine()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.triangle.merge")
                                    Text(viewModel.tr("updates.sync_upstream"))
                                }
                            }
                            .buttonStyle(NXSecondaryButtonStyle())
                            .disabled(viewModel.isSyncingUpstream || viewModel.isApplyingUpdate)
                            .help(viewModel.tr("updates.sync_upstream_help"))
                        }
                        
                        Button(action: {
                            if let url = URL(string: "https://gitlab.com/rennan-group2/nxnative_Launcher/-/issues") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "ladybug.fill")
                                    .foregroundColor(Color.orange)
                                Text("Issues")
                            }
                        }
                        .buttonStyle(NXSecondaryButtonStyle())
                        .help(viewModel.tr("updates.issues_help"))

                        Button(action: {
                            if let url = URL(string: "https://gitlab.com/rennan-group2/nxnative_Launcher/-/merge_requests") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.triangle.merge")
                                    .foregroundColor(Color.cyan)
                                Text("Pull Requests")
                            }
                        }
                        .buttonStyle(NXSecondaryButtonStyle())
                        .help(viewModel.tr("updates.prs_help"))
                        
                        Spacer()
                    }
                    
                    // Live Install Logs console if applying update
                    if viewModel.isApplyingUpdate || viewModel.isSyncingUpstream || !viewModel.updateInstallLogs.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(viewModel.tr("updates.log_title"))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(NXTheme.textSecondary)
                                Spacer()
                            }
                            
                            ScrollView {
                                VStack(alignment: .leading, spacing: 3) {
                                    ForEach(Array(viewModel.updateInstallLogs.enumerated()), id: \.offset) { _, line in
                                        Text(line)
                                            .font(.system(size: 10.5, design: .monospaced))
                                            .foregroundColor(line.contains("error") || line.contains("Error") ? .red : NXTheme.textSecondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                            }
                            .frame(height: 120)
                            .background(Color.black.opacity(0.45))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 0.8))
                        }
                    }
                }
                .padding(6)
            }
            
            // MARK: - What's New & Fixes (Changelog)
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(viewModel.tr("updates.changelog_title"), systemImage: "sparkles.rectangle.stack.fill")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(NXTheme.textPrimary)
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        // Highlight 1: Zelda Ocarina of Time
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text("🗡️")
                                Text("The Legend of Zelda: Ocarina of Time (Switch 2 · 0400486024DEC000)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                changeItem(viewModel.tr("updates.changelog_oot_video"))
                                changeItem(viewModel.tr("updates.changelog_oot_pacing"))
                                changeItem(viewModel.tr("updates.changelog_oot_metalfx"))
                                changeItem(viewModel.tr("updates.changelog_oot_memory"))
                                changeItem(viewModel.tr("updates.changelog_oot_overlay"))
                            }
                            .padding(.leading, 8)
                        }
                        .padding(10)
                        .nxGlassCard(cornerRadius: 10, tint: Color.blue.opacity(0.18))
                        
                        // Highlight 2: Launcher & Motor
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text("🚀")
                                Text(viewModel.tr("updates.changelog_system_title"))
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                changeItem(viewModel.tr("updates.changelog_system_updates"))
                                changeItem(viewModel.tr("updates.changelog_system_env"))
                                changeItem(viewModel.tr("updates.changelog_system_isolation"))
                            }
                            .padding(.leading, 8)
                        }
                        .padding(10)
                        .nxGlassCard(cornerRadius: 10, tint: Color.purple.opacity(0.18))
                        
                        // Commits list from git if available
                        if let info = viewModel.updateInfo, !info.commitMessages.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(viewModel.tr("updates.remote_commits_title"))
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(NXTheme.textSecondary)
                                ForEach(info.commitMessages.prefix(10), id: \.self) { msg in
                                    Text("• \(msg)")
                                        .font(.system(size: 10.5, design: .monospaced))
                                        .foregroundColor(NXTheme.textMuted)
                                }
                            }
                            .padding(8)
                            .nxGlassCard(cornerRadius: 8)
                        }
                    }
                }
                .padding(6)
            }
            
            // MARK: - Game Porting Instructions
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label(viewModel.tr("updates.instructions_title"), systemImage: "info.circle.fill")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(NXTheme.textPrimary)
                    
                    HStack(alignment: .top, spacing: 14) {
                        // For New Ports
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 5) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(Color(red: 0.13, green: 0.77, blue: 0.37))
                                Text(viewModel.tr("updates.instructions_new_title"))
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Text(viewModel.tr("updates.instructions_new_desc"))
                                .font(.system(size: 11))
                                .foregroundColor(NXTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .nxGlassCard(cornerRadius: 10)
                        
                        // For Existing Ports
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                    .foregroundColor(NXTheme.secondary)
                                Text(viewModel.tr("updates.instructions_existing_title"))
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Text(viewModel.tr("updates.instructions_existing_desc"))
                                .font(.system(size: 11))
                                .foregroundColor(NXTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .nxGlassCard(cornerRadius: 10)
                    }
                }
                .padding(6)
            }
        }
    }
    
    @ViewBuilder
    private func changeItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
                .foregroundColor(NXTheme.secondary)
                .font(.system(size: 12, weight: .bold))
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(NXTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
