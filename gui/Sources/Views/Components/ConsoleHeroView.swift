import SwiftUI
import AppKit

public struct ConsoleHeroView: View {
    public let game: PortedGame?
    public let unportedGame: SelectableGame?
    @ObservedObject public var viewModel: AppViewModel
    @ObservedObject internal var artworkStore = ArtworkStore.shared
    @ObservedObject internal var deviceService = DeviceDeploymentService.shared
    @ObservedObject internal var deploymentTracker = IosDeploymentTracker.shared
    @Environment(\.nxLiquidGlass) internal var glassEnv
    public let height: CGFloat

    public init(game: PortedGame? = nil, unportedGame: SelectableGame? = nil, viewModel: AppViewModel, height: CGFloat) {
        self.game = game
        self.unportedGame = unportedGame
        self.viewModel = viewModel
        self.height = height
    }

    private var heroImage: NSImage? {
        if let g = game {
            return ArtworkStore.shared.loadWidescreenHero(for: g)
        } else if let u = unportedGame {
            return ArtworkStore.shared.loadWidescreenHero(titleId: u.titleId, gameName: u.name)
        }
        return nil
    }

    internal var config: GameRuntimeConfig {
        if let g = game {
            return viewModel.loadRuntimeConfig(for: g)
        }
        return GameRuntimeConfig()
    }

    internal var isLaunching: Bool {
        guard let g = game else { return false }
        return viewModel.launchingGameId == g.id
    }

    internal var isUnportedBuilding: Bool {
        guard let u = unportedGame else { return false }
        return viewModel.isBuilding && (viewModel.buildingGameId == u.id || viewModel.selectedGame?.id == u.id)
    }

    public var body: some View {
        ZStack(alignment: .bottomLeading) {
            // MARK: - 16:9 Widescreen Promotional Artwork
            GeometryReader { geo in
                if let img = heroImage {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: height)
                        .clipped()
                } else {
                    // Procedural atmospheric gradient fallback
                    ZStack {
                        Color.nxCanvas.opacity(0.6)
                        RadialGradient(
                            gradient: Gradient(colors: [NXTheme.primary.opacity(0.34), Color.nxCanvas.opacity(0.85)]),
                            center: .topTrailing,
                            startRadius: 40,
                            endRadius: 600
                        )
                    }
                    .frame(width: geo.size.width, height: height)
                }
            }
            .allowsHitTesting(false)

            // MARK: - Dark Mode Linear Blend Overlay
            LinearGradient(
                stops: [
                    .init(color: Color.clear, location: 0.0),
                    .init(color: Color.black.opacity(0.18), location: 0.52),
                    .init(color: Color.nxCanvas.opacity(0.68), location: 0.84),
                    .init(color: Color.nxCanvas.opacity(glassEnv.isSupportedAndEnabled ? 0.88 : 1.0), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.68), location: 0.0),
                    .init(color: Color.clear, location: 0.75)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .allowsHitTesting(false)

            // MARK: - Game Metadata & Liquid Glass Console Action Buttons
            VStack(alignment: .leading, spacing: 12) {
                // Console Runtime Status Indicators
                NXGlassContainer(spacing: 6) {
                    HStack(spacing: 8) {
                        if let g = game {
                            if g.platform == .macApp {
                                statusPill(title: config.enable60FPS ? "60 FPS" : "30 FPS", active: config.enable60FPS)
                                statusPill(title: config.isDockedMode ? "Docked" : "Handheld", active: true)
                                if config.enableGameMode {
                                    statusPill(title: "Game Mode", active: true)
                                }
                                if config.enableMetalFXUpscale {
                                    statusPill(title: "MetalFX", active: true)
                                }
                                statusPill(title: "macOS Native", active: false)
                            } else {
                                statusPill(title: "iOS IPA Port", active: true)
                                statusPill(title: "Handheld", active: false)
                                if deviceService.activeDeployment.isRunning {
                                    statusPill(title: "Deploying (\(Int(deviceService.activeDeployment.progressFraction * 100))%)", active: true)
                                } else {
                                    statusPill(title: "iPhone & iPad", active: false)
                                }
                            }
                        } else if let u = unportedGame {
                            statusPill(title: "Nintendo Switch", active: true)
                            statusPill(title: u.formattedSize, active: false)
                            if u.updateCount > 0 {
                                statusPill(title: "+\(u.updateCount) Updates", active: true)
                            }
                            if u.dlcCount > 0 {
                                statusPill(title: "+\(u.dlcCount) DLCs", active: true)
                            }
                        }
                    }
                }

                // Clean Game Title
                Text(game?.name ?? unportedGame?.name ?? "")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundColor(NXTheme.textPrimary)
                    .lineLimit(2)
                    .shadow(color: Color.black.opacity(0.8), radius: 10, x: 0, y: 3)

                // Interactive Liquid Glass Action Bar
                NXGlassContainer(spacing: 12) {
                    HStack(spacing: 12) {
                        if let g = game {
                            portedActionBar(for: g)
                        } else if let u = unportedGame {
                            unportedActionBar(for: u)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 34)
            .padding(.bottom, 22)
        }
        .frame(height: height)
    }
}
