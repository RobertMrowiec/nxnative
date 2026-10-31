import SwiftUI

public struct BuildGameSection: View {
    @ObservedObject public var viewModel: AppViewModel
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Main Drop Target
            DropZoneView(viewModel: viewModel)
            
            // Multiple Detected Games Selector (if folder contains >1 title)
            if viewModel.detectedGames.count > 1 {
                detectedGamesList
            }
            
            // Selected Game Profile Hero Card
            if let game = viewModel.selectedGame {
                selectedGameHeroCard(game)
            }
        }
    }
    
    private func selectedGameHeroCard(_ game: SelectableGame) -> some View {
        GlassCard(padding: 14) {
            VStack(spacing: 12) {
                HStack(spacing: 14) {
                    if let cover = GameCoverService.shared.coverImage(titleId: game.titleId, gameName: game.name) {
                        Image(nsImage: cover)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 48, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(NXTheme.specularRim, lineWidth: 0.8)
                            )
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(NXTheme.primary.opacity(0.18))
                                .frame(width: 48, height: 72)
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 22))
                                .foregroundColor(NXTheme.secondary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(game.name)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(NXTheme.textPrimary)
                            .lineLimit(1)
                        
                        if let titleId = game.titleId, !titleId.isEmpty {
                            Text(titleId)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(NXTheme.textSecondary)
                        }
                        
                        HStack(spacing: 8) {
                            Text(game.formattedSize)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(NXTheme.secondary)
                            
                            if game.updateCount > 0 {
                                Text(viewModel.tr("build.badge_updates", game.updateCount))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Color.blue.opacity(0.4))
                                    .clipShape(Capsule())
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color(red: 0.13, green: 0.77, blue: 0.37))
                                    .font(.system(size: 11))
                                Text(viewModel.tr("build.game_ready_badge"))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Color(red: 0.13, green: 0.77, blue: 0.37))
                            }
                        }
                    }
                    
                    Spacer()
                }
                
                Divider().opacity(0.15)
                
                HStack {
                    if let avail = viewModel.availableDiskBytes {
                        let availStr = ByteCountFormatter.string(fromByteCount: avail, countStyle: .file)
                        HStack(spacing: 6) {
                            Image(systemName: "externaldrive.fill")
                                .foregroundColor(NXTheme.textSecondary)
                                .font(.system(size: 11))
                            Text(viewModel.tr("build.storage_clear_badge", availStr))
                                .font(.system(size: 11))
                                .foregroundColor(NXTheme.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        SoundEffectService.shared.play(.click)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                            viewModel.goToWizardStep(2)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Text(viewModel.tr("build.continue_config"))
                            Image(systemName: "arrow.right.circle.fill")
                        }
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(NXPrimaryButtonStyle())
                }
            }
        }
    }
    
    private var detectedGamesList: some View {
        GlassCard(padding: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.tr("build.select_game_detected", viewModel.detectedGames.count))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(NXTheme.textPrimary)
                
                VStack(spacing: 6) {
                    ForEach(viewModel.detectedGames) { game in
                        SelectableGameCard(
                            game: game,
                            isSelected: viewModel.selectedGame?.id == game.id,
                            onSelect: {
                                SoundEffectService.shared.play(.click)
                                viewModel.selectedGame = game
                            }
                        )
                    }
                }
            }
        }
    }
}
