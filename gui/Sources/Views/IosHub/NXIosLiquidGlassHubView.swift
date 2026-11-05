import SwiftUI

// MARK: - NxNative iOS Console Hub View (Apple Liquid Glass)

/// The primary console library interface on iOS/iPadOS featuring Liquid Glass Cover Flow,
/// direct USB-C external storage indicators, and seamless iCloud save synchronization.
public struct NXIosLiquidGlassHubView: View {
    @ObservedObject private var storageService = IosGameStorageService.shared
    @State private var showSettingsModal: Bool = false
    @State private var isPlayingGame: Bool = false

    public init() {}

    public var body: some View {
        ZStack {
            // Ambient Obsidian Background with Fluid Refractions
            NXTheme.canvasObsidian.ignoresSafeArea()

            RadialGradient(
                colors: [NXTheme.primary.opacity(0.18), Color.clear],
                center: .topLeading,
                startRadius: 50,
                endRadius: 600
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topNavigationBar
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                if storageService.indexedGames.isEmpty {
                    emptyLibraryState
                        .frame(maxHeight: .infinity)
                } else {
                    mainConsoleLibraryContent
                        .frame(maxHeight: .infinity)
                }

                bottomActionBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)
            }
        }
        .onAppear {
            storageService.scanInstalledGames()
        }
    }

    // MARK: - Navigation Bar
    private var topNavigationBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Text("NxN")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(NXTheme.logoGradient)
                Text("LAUNCHER")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(NXTheme.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(NXTheme.secondary.opacity(0.15))
                    .cornerRadius(4)
            }

            Spacer()

            NxIosIcons.CloudSyncBadge(state: storageService.saveSyncState)

            NxIosIcons.ExternalStorageBadge(isConnected: storageService.externalStorageURL != nil)

            Button(action: {
                SoundEffectService.shared.play(.click)
                storageService.scanInstalledGames()
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(NXTheme.textPrimary)
                    .padding(8)
                    .background(NXTheme.glassSurfaceElevated.opacity(0.85))
                    .clipShape(Circle())
            }
            .buttonStyle(NXPressableButtonStyle())
        }
        .padding(.vertical, 8)
    }

    // MARK: - Library Content
    private var mainConsoleLibraryContent: some View {
        VStack(spacing: 16) {
            // Cover Flow Carousel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(storageService.indexedGames) { game in
                        let isSelected = storageService.selectedGame?.id == game.id
                        gameCoverCard(game: game, isSelected: isSelected)
                            .onTapGesture {
                                SoundEffectService.shared.play(.click)
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    storageService.selectedGame = game
                                }
                            }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 10)
            }

            // Selected Game Detail Hero Card
            if let selected = storageService.selectedGame {
                gameDetailHeroCard(game: selected)
                    .padding(.horizontal, 20)
            }

            Spacer()
        }
    }

    private func gameCoverCard(game: NxHubGameItem, isSelected: Bool) -> some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(NXTheme.glassSurfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(isSelected ? NXTheme.primary : NXTheme.borderSubtle, lineWidth: isSelected ? 2 : 1)
                )
                .shadow(color: isSelected ? NXTheme.primary.opacity(0.4) : Color.black.opacity(0.3), radius: isSelected ? 12 : 6)

            VStack(alignment: .leading, spacing: 4) {
                if game.isSwitch2 {
                    Text("SWITCH 2")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(Color.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(red: 0.98, green: 0.82, blue: 0.25))
                        .cornerRadius(4)
                }

                Text(game.name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color.white)
                    .lineLimit(2)

                Text("v\(game.displayVersion)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(NXTheme.textSecondary)
            }
            .padding(12)
        }
        .frame(width: 170, height: 230)
        .scaleEffect(isSelected ? 1.05 : 0.95)
    }

    private func gameDetailHeroCard(game: NxHubGameItem) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(game.name)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(Color.white)

                HStack(spacing: 8) {
                    badge(text: "\(game.launchSettings.fpsTarget) FPS", color: NXTheme.primary)
                    if game.launchSettings.metalFxUpscaling {
                        badge(text: "MetalFX", color: NXTheme.secondary)
                    }
                    badge(text: game.launchSettings.dockedMode ? "Docked" : "Handheld", color: Color.gray)
                }
            }

            Spacer()

            Button(action: {
                SoundEffectService.shared.play(.click)
                isPlayingGame = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14))
                    Text("PLAY")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(NXTheme.primaryGradient)
                .cornerRadius(12)
                .shadow(color: NXTheme.primary.opacity(0.4), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(NXPressableButtonStyle())
        }
        .padding(16)
        .nxGlassCard(cornerRadius: 16)
    }

    private func badge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .cornerRadius(6)
    }

    // MARK: - Empty State
    private var emptyLibraryState: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 40))
                .foregroundColor(NXTheme.textSecondary)

            Text("No Games in NxN Launcher")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(Color.white)

            Text("Instale jogos diretamente a partir do Mac Launcher para o NxN Launcher.")
                .font(.system(size: 12))
                .foregroundColor(NXTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .padding(24)
    }

    // MARK: - Bottom Action Bar
    private var bottomActionBar: some View {
        HStack {
            Text("Gamepad: [A] Play   [X] Options   [B] Back")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(NXTheme.textSecondary)
            Spacer()
        }
    }
}
