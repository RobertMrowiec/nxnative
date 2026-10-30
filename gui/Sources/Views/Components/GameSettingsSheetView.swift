import SwiftUI
import AppKit

public struct GameSettingsSheetView: View {
    @ObservedObject public var viewModel: AppViewModel
    @ObservedObject var controllerService = GameControllerService.shared
    @ObservedObject var profileManager = InputProfileManager.shared
    public let game: PortedGame
    
    @Environment(\.dismiss) internal var dismiss
    @Environment(\.nxLiquidGlass) internal var glassEnv
    @Environment(\.accessibilityReduceTransparency) internal var reduceTransparency
    
    public init(viewModel: AppViewModel, game: PortedGame) {
        self.viewModel = viewModel
        self.game = game
    }
    
    internal var useLiquidGlass: Bool {
        glassEnv.isSupportedAndEnabled && !reduceTransparency
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if game.platform == .macApp {
                    // Section 0: Framerate (60 FPS)
                    settingCard(
                        rowIndex: 0,
                        title: viewModel.tr("settings_modal.framerate_title"),
                        icon: "speedometer",
                        iconColor: Color(red: 0.13, green: 0.77, blue: 0.37)
                    ) {
                        let isRowFocused = viewModel.settingsModalFocusIndex == 0
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(viewModel.activeSettingsConfig.enable60FPS ? viewModel.tr("settings_modal.fps_60") : viewModel.tr("settings_modal.fps_30"))
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                Text(viewModel.tr("settings_modal.fps_desc"))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(isRowFocused ? .white : .white.opacity(0.88))
                            }
                            Spacer(minLength: 12)
                            Toggle("", isOn: $viewModel.activeSettingsConfig.enable60FPS)
                                .labelsHidden()
                                .toggleStyle(.switch)
                        }
                    }
                    
                    // Section 1: macOS Game Mode (Modo Jogo & Fullscreen)
                    settingCard(
                        rowIndex: 1,
                        title: viewModel.tr("settings_modal.game_mode_title"),
                        icon: "gamecontroller.fill",
                        iconColor: Color(red: 0.25, green: 0.55, blue: 1.0)
                    ) {
                        let isRowFocused = viewModel.settingsModalFocusIndex == 1
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(viewModel.activeSettingsConfig.enableGameMode ? viewModel.tr("settings_modal.game_mode_enabled") : viewModel.tr("settings_modal.game_mode_disabled"))
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                Text(viewModel.tr("settings_modal.game_mode_desc"))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(isRowFocused ? .white : .white.opacity(0.88))
                            }
                            Spacer(minLength: 12)
                            Toggle("", isOn: $viewModel.activeSettingsConfig.enableGameMode)
                                .labelsHidden()
                                .toggleStyle(.switch)
                        }
                    }
                    
                    // Section 2: Metal HUD
                    settingCard(
                        rowIndex: 2,
                        title: viewModel.tr("settings_modal.metal_hud_title"),
                        icon: "gauge.with.needle.fill",
                        iconColor: NXTheme.secondary
                    ) {
                        let isRowFocused = viewModel.settingsModalFocusIndex == 2
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(viewModel.activeSettingsConfig.enableMetalHUD ? viewModel.tr("settings_modal.metal_hud_enabled") : viewModel.tr("settings_modal.metal_hud_disabled"))
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                Text(viewModel.tr("settings_modal.metal_hud_desc"))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(isRowFocused ? .white : .white.opacity(0.88))
                            }
                            Spacer(minLength: 12)
                            Toggle("", isOn: $viewModel.activeSettingsConfig.enableMetalHUD)
                                .labelsHidden()
                                .toggleStyle(.switch)
                        }
                    }
                    
                    // Section 3: Console Mode (Sliding Liquid Glass Segmented Picker)
                    settingCard(
                        rowIndex: 3,
                        title: viewModel.tr("settings_modal.console_mode_title"),
                        icon: "tv.and.mediabox",
                        iconColor: NXTheme.primary
                    ) {
                        let isRowFocused = viewModel.settingsModalFocusIndex == 3
                        VStack(alignment: .leading, spacing: 10) {
                            NXLiquidSegmentedPicker(
                                selection: $viewModel.activeSettingsConfig.isDockedMode,
                                options: [
                                    NXSegmentOption(value: true, title: viewModel.tr("settings_modal.docked_label"), icon: "tv.fill"),
                                    NXSegmentOption(value: false, title: viewModel.tr("settings_modal.handheld_label"), icon: "iphone.gen3.landscape")
                                ]
                            )
                            
                            Text(viewModel.activeSettingsConfig.isDockedMode
                                 ? viewModel.tr("settings_modal.docked_desc")
                                 : viewModel.tr("settings_modal.handheld_desc"))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(isRowFocused ? .white : .white.opacity(0.88))
                        }
                    }
                    
                    // Section 4: 3D Render Scale (Liquid Glass Slider)
                    settingCard(
                        rowIndex: 4,
                        title: viewModel.tr("settings_modal.render_scale_title"),
                        icon: "viewfinder.circle.fill",
                        iconColor: Color(red: 1.0, green: 0.65, blue: 0.35)
                    ) {
                        let isRowFocused = viewModel.settingsModalFocusIndex == 4
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(viewModel.tr("settings_modal.render_scale_label"))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(isRowFocused ? .white : .white.opacity(0.88))
                                Spacer()
                                Text("\(Int(round(viewModel.activeSettingsConfig.renderScale * 100)))%")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                            
                            NXLiquidGlassSlider(
                                value: $viewModel.activeSettingsConfig.renderScale,
                                in: 0.50...1.00,
                                step: 0.05,
                                accentColor: NXTheme.primary
                            )
                            
                            NXGlassContainer(spacing: 8) {
                                HStack(spacing: 8) {
                                    Button(viewModel.tr("settings_modal.scale_50")) {
                                        viewModel.activeSettingsConfig.renderScale = 0.50
                                    }
                                    .buttonStyle(NXSecondaryButtonStyle())
                                    .controlSize(.mini)
                                    
                                    Button(viewModel.tr("settings_modal.scale_75")) {
                                        viewModel.activeSettingsConfig.renderScale = 0.75
                                    }
                                    .buttonStyle(NXSecondaryButtonStyle())
                                    .controlSize(.mini)
                                    
                                    Button(viewModel.tr("settings_modal.resolution_native")) {
                                        viewModel.activeSettingsConfig.renderScale = 1.00
                                    }
                                    .buttonStyle(NXSecondaryButtonStyle())
                                    .controlSize(.mini)
                                }
                            }
                        }
                    }
                    
                    // Section 5: MetalFX Upscaling
                    settingCard(
                        rowIndex: 5,
                        title: viewModel.tr("settings_modal.metalfx_title"),
                        icon: "sparkles.tv.fill",
                        iconColor: NXTheme.secondary
                    ) {
                        let isRowFocused = viewModel.settingsModalFocusIndex == 5
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(viewModel.activeSettingsConfig.enableMetalFXUpscale ? viewModel.tr("settings_modal.metalfx_enabled") : viewModel.tr("settings_modal.metalfx_disabled"))
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                Text(viewModel.tr("settings_modal.metalfx_desc"))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(isRowFocused ? .white : .white.opacity(0.88))
                            }
                            Spacer(minLength: 12)
                            Toggle("", isOn: $viewModel.activeSettingsConfig.enableMetalFXUpscale)
                                .labelsHidden()
                                .toggleStyle(.switch)
                        }
                    }
                    
                    // Section 6: Controller Profile Override (Liquid Glass Dropdown)
                    controllerProfileSection(rowIndex: 6)
                    
                    // Section 7: Cover Artwork Customization
                    coverArtworkSection()
                    
                    // Section 8: Mods Management & Save Sync
                    GameSettingsModsAndSavesView(game: game)
                } else {
                    // iOS Port: Installation, AirDrop, Sideload & Saves
                    GameSettingsModsAndSavesView(game: game)
                    
                    // Cover Artwork Customization
                    coverArtworkSection()
                }
                
                // Section: Game Management (Remove / Trash)
                gameManagementSection()
            }
            .padding(20)
        }
        .nxScrollEdgeEffect(edges: [.top, .bottom])
        .safeAreaInset(edge: .top, spacing: 0) {
            settingsHeaderBar
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            footerBar(onDismiss: { dismiss() })
        }
        .nxSheetSurface()
        .frame(minWidth: 500, idealWidth: 560, maxWidth: 640, minHeight: 560, idealHeight: 640, maxHeight: 740)
    }
}
