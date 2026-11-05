import SwiftUI
import AppKit

public struct BuildCelebrationCard: View {
    @ObservedObject public var viewModel: AppViewModel
    public let outputPath: String
    
    public init(viewModel: AppViewModel, outputPath: String) {
        self.viewModel = viewModel
        self.outputPath = outputPath
    }
    
    private var matchingGame: PortedGame? {
        viewModel.libraryGames.first { $0.url.path == outputPath }
    }
    
    public var body: some View {
        GlassCard(padding: 18) {
            VStack(spacing: 16) {
                // Celebration Badge & Header
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.13, green: 0.77, blue: 0.37).opacity(0.2))
                            .frame(width: 44, height: 44)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(Color(red: 0.13, green: 0.77, blue: 0.37))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.tr("build.celebration_title"))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(NXTheme.textPrimary)
                        Text(viewModel.tr("build.celebration_desc"))
                            .font(.system(size: 11))
                            .foregroundColor(NXTheme.textSecondary)
                    }
                    
                    Spacer()
                }
                
                Divider().opacity(0.15)
                
                // Game Preview Poster & Title
                HStack(spacing: 14) {
                    if let sel = viewModel.selectedGame,
                       let cover = GameCoverService.shared.coverImage(titleId: sel.titleId, gameName: sel.name) {
                        Image(nsImage: cover)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 54, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(NXTheme.specularRim, lineWidth: 0.8)
                            )
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(NXTheme.primary.opacity(0.2))
                                .frame(width: 54, height: 80)
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 26))
                                .foregroundColor(NXTheme.secondary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.selectedGame?.name ?? "Game")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(NXTheme.textPrimary)
                            .lineLimit(1)
                        
                        Text(outputPath)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(NXTheme.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        HStack(spacing: 6) {
                            Text(viewModel.platform == .macApp ? "macOS App" : "iOS IPA")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(NXTheme.primary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(NXTheme.primary.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }
                    
                    Spacer()
                }
                
                Divider().opacity(0.15)
                
                // Primary Action Button (Play Now or AirDrop)
                HStack(spacing: 10) {
                    if outputPath.hasSuffix(".app") {
                        Button(action: {
                            if let game = matchingGame {
                                viewModel.launchGame(game)
                            } else {
                                NSWorkspace.shared.open(URL(fileURLWithPath: outputPath))
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                Text(viewModel.tr("build.play_now"))
                            }
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(NXPrimaryButtonStyle())
                    } else if outputPath.hasSuffix(".ipa") {
                        Button(action: {
                            let ipaURL = URL(fileURLWithPath: outputPath)
                            DeviceDeploymentService.shared.revealInFinder(fileURL: ipaURL)
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "folder")
                                Text(viewModel.tr("settings_modal.show_ipa"))
                            }
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(NXPrimaryButtonStyle())
                    }
                }
                
                // Secondary Actions Row
                HStack(spacing: 12) {
                    Button(action: {
                        NSWorkspace.shared.selectFile(outputPath, inFileViewerRootedAtPath: "")
                    }) {
                        Label(viewModel.tr("build.show_in_finder"), systemImage: "folder.fill")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(NXSecondaryButtonStyle())
                    
                    Button(action: {
                        viewModel.selectedTab = 0
                    }) {
                        Label(viewModel.tr("build.view_in_library"), systemImage: "gamecontroller.fill")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(NXSecondaryButtonStyle())
                    
                    Spacer()
                    
                    Button(action: {
                        SoundEffectService.shared.play(.click)
                        withAnimation {
                            viewModel.resetWizard()
                        }
                    }) {
                        Text(viewModel.tr("build.port_another"))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(NXSecondaryButtonStyle())
                }
            }
        }
    }
}
