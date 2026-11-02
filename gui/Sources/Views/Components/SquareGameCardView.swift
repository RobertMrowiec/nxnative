import SwiftUI
import AppKit

public struct SquareGameCardView: View {
    public let game: PortedGame
    @ObservedObject public var viewModel: AppViewModel
    public let isFocused: Bool
    public let isDropTarget: Bool
    public let baseSize: CGFloat
    public let onSelect: () -> Void
    @ObservedObject private var deploymentTracker = IosDeploymentTracker.shared
    @State private var cachedIcon: NSImage? = nil

    public init(
        game: PortedGame,
        viewModel: AppViewModel,
        isFocused: Bool,
        isDropTarget: Bool = false,
        baseSize: CGFloat = 170,
        onSelect: @escaping () -> Void
    ) {
        self.game = game
        self.viewModel = viewModel
        self.isFocused = isFocused
        self.isDropTarget = isDropTarget
        self.baseSize = baseSize
        self.onSelect = onSelect
    }

    private var iconImage: NSImage {
        if let cached = cachedIcon { return cached }
        return ArtworkStore.shared.loadSquareIcon(for: game)
    }

    private var isBeingDragged: Bool {
        viewModel.draggedGame?.url.standardized.path == game.url.standardized.path
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // MARK: - 1:1 Square Nintendo Switch Tile (Edge-to-Edge Full Bleed)
            Image(nsImage: iconImage)
                .resizable()
                .scaledToFill()
                .frame(width: baseSize, height: baseSize, alignment: .top)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            // Ambient gradient on bottom edge for subtle depth
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.35)],
                startPoint: .center,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .frame(width: baseSize, height: baseSize)
        .opacity(isBeingDragged ? 0.35 : 1.0)
        // Liquid Glass micro-capsules placed outside so backdrop refraction renders natively
        .overlay(alignment: .bottomTrailing) {
            NXGlassContainer(spacing: 4) {
                HStack(spacing: 4) {
                    let badgeText = game.platform == .macApp ? "MAC" : (game.platform == .nonSwitch ? "NATIVE" : "IOS")
                    let badgeColor = game.platform == .macApp ? NXTheme.primary : (game.platform == .nonSwitch ? Color(red: 0.20, green: 0.82, blue: 0.60) : NXTheme.secondary)

                    Text(badgeText)
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .nxGlassBar(
                            in: Capsule(),
                            tint: badgeColor.opacity(0.68),
                            fallbackFill: badgeColor.opacity(0.85),
                            fallbackStroke: Color.white.opacity(0.22)
                        )

                    if SaveSyncService.shared.isCloudSyncActive(for: game) {
                        Image(systemName: "icloud.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2.5)
                            .nxGlassBar(
                                in: Capsule(),
                                tint: Color.blue.opacity(0.68),
                                fallbackFill: Color.blue.opacity(0.85),
                                fallbackStroke: Color.white.opacity(0.22)
                            )
                    }
                }
                .padding(8)
            }
        }
        // iOS Sideload Renewal Countdown Badge (Top Right Corner)
        .overlay(alignment: .topTrailing) {
            if game.platform == .ios, let record = deploymentTracker.deploymentRecord(for: game) {
                IosRenewalBadgeView(record: record)
                    .padding(8)
            }
        }
        // MARK: - Switch Glowing Focus & Drop Target Frame
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isDropTarget
                        ? AnyShapeStyle(NXTheme.primary)
                        : (isFocused
                            ? AnyShapeStyle(LinearGradient(colors: [Color.white.opacity(0.95), NXTheme.primary], startPoint: .topLeading, endPoint: .bottomTrailing))
                            : AnyShapeStyle(Color.white.opacity(0.16))),
                    lineWidth: (isDropTarget || isFocused) ? 3.5 : 1
                )
        )
        .shadow(
            color: isDropTarget ? NXTheme.primary.opacity(0.85) : (isFocused ? NXTheme.primary.opacity(0.65) : Color.black.opacity(0.35)),
            radius: (isDropTarget || isFocused) ? 8 : 4,
            x: 0,
            y: (isDropTarget || isFocused) ? 2 : 2
        )
        .shadow(
            color: (isDropTarget || isFocused) ? NXTheme.primary.opacity(0.35) : Color.clear,
            radius: (isDropTarget || isFocused) ? 18 : 0,
            x: 0,
            y: (isDropTarget || isFocused) ? 3 : 0
        )
        .scaleEffect(isDropTarget ? 1.05 : (isFocused ? 1.08 : 1.0))
        .animation(.spring(response: 0.28, dampingFraction: 0.76), value: isFocused)
        .animation(.spring(response: 0.24, dampingFraction: 0.80), value: isDropTarget)
        .animation(.easeInOut(duration: 0.20), value: isBeingDragged)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture {
            onSelect()
        }
        .contextMenu {
            if game.isPlayableLocally {
                Button {
                    viewModel.launchGame(game)
                } label: {
                    Label(viewModel.tr("common.play"), systemImage: "play.fill")
                }
            } else {
                let isDeployed = deploymentTracker.isGameDeployed(game)
                Button {
                    viewModel.gameForSettingsSheet = game
                } label: {
                    Label(
                        isDeployed ? viewModel.tr("actions.renew_ios") : viewModel.tr("actions.send_ios"),
                        systemImage: isDeployed ? "arrow.triangle.2.circlepath" : "arrow.up.forward.app"
                    )
                }
            }

            Button {
                viewModel.gameForSettingsSheet = game
            } label: {
                Label(viewModel.tr("actions.game_settings"), systemImage: "slider.horizontal.3")
            }

            Button {
                viewModel.revealInFinder(url: game.url)
            } label: {
                Label(viewModel.tr("actions.app_files"), systemImage: "folder")
            }

            Button {
                let profile = GameDetailsProfile.inspect(for: game)
                viewModel.revealSaveFolder(profile.saveDirectory)
            } label: {
                Label(viewModel.tr("actions.save_location"), systemImage: "internaldrive")
            }

            Divider()

            Button {
                viewModel.gameToRemove = game
                viewModel.showRemoveConfirm = true
            } label: {
                Label(viewModel.tr("actions.remove_from_library"), systemImage: "eye.slash")
            }

            Button(role: .destructive) {
                viewModel.gameToTrash = game
                viewModel.showTrashConfirm = true
            } label: {
                Label(viewModel.tr("actions.move_to_trash"), systemImage: "trash")
            }
        }
        .onAppear {
            if cachedIcon == nil {
                cachedIcon = ArtworkStore.shared.loadSquareIcon(for: game)
            }
        }
        .onChange(of: game.url) { _ in
            cachedIcon = ArtworkStore.shared.loadSquareIcon(for: game)
        }
        .onReceive(GameCoverService.shared.$refreshRevision) { _ in
            cachedIcon = ArtworkStore.shared.loadSquareIcon(for: game)
        }
    }
}
