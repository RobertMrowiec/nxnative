import SwiftUI
import AppKit

public struct UnportedGameCardView: View {
    public let game: SelectableGame
    @ObservedObject public var viewModel: AppViewModel
    public let isFocused: Bool
    public let baseSize: CGFloat
    public let onSelect: () -> Void
    @ObservedObject private var coverService = GameCoverService.shared
    
    public init(
        game: SelectableGame,
        viewModel: AppViewModel,
        isFocused: Bool,
        baseSize: CGFloat = 170,
        onSelect: @escaping () -> Void
    ) {
        self.game = game
        self.viewModel = viewModel
        self.isFocused = isFocused
        self.baseSize = baseSize
        self.onSelect = onSelect
    }
    
    private var isBeingPorted: Bool {
        viewModel.isBuilding && (viewModel.buildingGameId == game.id || viewModel.selectedGame?.id == game.id)
    }
    
    private var progress: Double {
        max(0.0, min(1.0, viewModel.progressFraction))
    }
    
    private var coverImage: NSImage? {
        coverService.coverImage(titleId: game.titleId, gameName: game.name)
    }
    
    private var stageText: String {
        let current = max(1, viewModel.stageIndex + 1)
        let total = viewModel.totalStages > 0 ? viewModel.totalStages : 10
        return String(format: "Stage %02d/%02d", current, total)
    }
    
    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Visual Card Content with Progressive Vertical Opacity
            cardVisualStack
            
            // Bottom Right Badges (Switch Pill + Updates/DLCs count)
            if !isBeingPorted {
                bottomBadges
            }
            
            // In-Progress Centered Percentage & Bottom Stage Pill
            if isBeingPorted {
                inProgressOverlay
            }
            
            // Top Right: Cancel Port Button (Only when being ported & focused)
            if isBeingPorted && isFocused {
                VStack {
                    HStack {
                        Spacer()
                        cancelPortButton
                    }
                    Spacer()
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: baseSize, height: baseSize)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isFocused
                        ? AnyShapeStyle(LinearGradient(colors: [Color.white.opacity(0.95), NXTheme.secondary], startPoint: .topLeading, endPoint: .bottomTrailing))
                        : (isBeingPorted ? AnyShapeStyle(NXTheme.primary.opacity(0.85)) : AnyShapeStyle(Color.white.opacity(0.14))),
                    lineWidth: (isFocused || isBeingPorted) ? 3.0 : 1.0
                )
        )
        .shadow(
            color: isFocused ? NXTheme.secondary.opacity(0.55) : (isBeingPorted ? NXTheme.primary.opacity(0.40) : Color.black.opacity(0.30)),
            radius: isFocused ? 8 : 4,
            x: 0,
            y: 2
        )
        .scaleEffect(isFocused ? 1.08 : 1.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.76), value: isFocused)
        .animation(.easeInOut(duration: 0.22), value: isBeingPorted)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture {
            onSelect()
        }
        .contextMenu {
            Button {
                viewModel.selectedGame = game
                viewModel.gameForPortModal = game
            } label: {
                Label(viewModel.tr("library.port_now"), systemImage: "play.circle.fill")
            }
            
            if let file = game.baseFile {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([file.url])
                } label: {
                    Label(viewModel.tr("actions.app_files"), systemImage: "folder")
                }
            }
        }
    }
    
    // MARK: - Progressive Vertical Opacity Stack
    @ViewBuilder
    private var cardVisualStack: some View {
        if isBeingPorted {
            ZStack {
                // Base at 60% opacity
                singleTileArt
                    .opacity(0.60)
                
                // Rising 100% solid opacity layer from bottom to top
                singleTileArt
                    .opacity(1.0)
                    .mask(
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            Rectangle()
                                .frame(height: baseSize * CGFloat(progress))
                        }
                    )
            }
        } else {
            // Idle unported state: steady 60% opacity
            singleTileArt
                .opacity(0.60)
        }
    }
    
    // MARK: - 1:1 Tile Art
    @ViewBuilder
    private var singleTileArt: some View {
        ZStack {
            if let img = coverImage {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: baseSize, height: baseSize)
                    .clipped()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(NXTheme.glassSurfaceElevated)
                    
                    VStack(spacing: 6) {
                        Image(systemName: "gamecontroller")
                            .font(.system(size: 32))
                            .foregroundColor(NXTheme.secondary.opacity(0.8))
                        
                        Text(game.name)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(NXTheme.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 8)
                    }
                }
            }
            
            // Ambient vignette
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.40)],
                startPoint: .center,
                endPoint: .bottom
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    
    // MARK: - Bottom Badges
    private var bottomBadges: some View {
        HStack(spacing: 4) {
            if game.isNup || game.isSwitch2 {
                Text(game.isNup ? "NUP" : "SW2")
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .nxGlassBar(
                        in: Capsule(),
                        tint: Color(red: 0.95, green: 0.48, blue: 0.16).opacity(0.85),
                        fallbackFill: Color(red: 0.95, green: 0.48, blue: 0.16).opacity(0.92),
                        fallbackStroke: Color.white.opacity(0.25)
                    )
            }

            Text(viewModel.tr("library.unported_badge"))
                .font(.system(size: 8, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .nxGlassBar(
                    in: Capsule(),
                    tint: NXTheme.secondary.opacity(0.75),
                    fallbackFill: NXTheme.secondary.opacity(0.85),
                    fallbackStroke: Color.white.opacity(0.20)
                )
            
            if game.updateCount > 0 || game.dlcCount > 0 {
                HStack(spacing: 2) {
                    if game.updateCount > 0 {
                        Text("+\(game.updateCount)U")
                    }
                    if game.dlcCount > 0 {
                        Text("+\(game.dlcCount)D")
                    }
                }
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2.5)
                .nxGlassBar(
                    in: Capsule(),
                    tint: Color.blue.opacity(0.65),
                    fallbackFill: Color.blue.opacity(0.75),
                    fallbackStroke: Color.white.opacity(0.20)
                )
            }
        }
        .padding(8)
    }
    
    // MARK: - Active Build Overlay (% Center + Stage Bottom)
    private var inProgressOverlay: some View {
        ZStack {
            // Centered Bold Percentage
            VStack(spacing: 4) {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.85), radius: 6, x: 0, y: 2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.72))
                    .overlay(
                        Capsule()
                            .strokeBorder(NXTheme.primary.opacity(0.85), lineWidth: 1.2)
                    )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            
            // Bottom Discrete Stage Indicator
            VStack {
                Spacer()
                Text(stageText)
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.92))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.75))
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
                            )
                    )
                    .padding(.bottom, 7)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
    
    // MARK: - Top Right Cancel Button
    private var cancelPortButton: some View {
        Button(action: {
            SoundEffectService.shared.play(.click)
            viewModel.cancelBuild()
        }) {
            HStack(spacing: 3.5) {
                Image(systemName: "xmark")
                    .font(.system(size: 8.5, weight: .black))
                Text(viewModel.tr("library.cancel_port"))
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                if GameControllerService.shared.isGamepadConnected {
                    Text("(B)")
                        .font(.system(size: 7.5, weight: .black, design: .monospaced))
                        .opacity(0.9)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(
                Capsule()
                    .fill(Color(red: 0.85, green: 0.18, blue: 0.18).opacity(0.92))
                    .overlay(
                        Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.6), radius: 4, x: 0, y: 1.5)
        }
        .buttonStyle(PlainButtonStyle())
        .nxNoFocusRing()
        .padding(7)
    }
}
