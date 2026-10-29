import SwiftUI

// MARK: - Navigation Header and Island Views for MainView
extension MainView {
    internal var navigationHeader: some View {
        NXGlassContainer(spacing: 14) {
            HStack(spacing: 12) {
                // Left Island: Brand Logo & Update Pill
                brandIsland
                
                Spacer(minLength: 8)
                
                // Center Island: 7 Morphing Liquid Glass Navigation Tabs
                navigationTabsIsland
                
                Spacer(minLength: 8)
                
                // Right Island: Build & Readiness Status Indicator
                statusIsland
            }
            .padding(.horizontal, useFloatingGlassBars ? 14 : 18)
            .padding(.vertical, useFloatingGlassBars ? 8 : 10)
            .frame(minHeight: 54)
            .background(
                Group {
                    if !useFloatingGlassBars {
                        ZStack {
                            NXTheme.canvasObsidian.opacity(0.85)
                            Rectangle().fill(.ultraThinMaterial)
                        }
                    }
                }
            )
            .overlay(
                Group {
                    if !useFloatingGlassBars {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(NXTheme.borderSubtle)
                    }
                },
                alignment: .bottom
            )
        }
    }
    
    private var brandIsland: some View {
        HStack(spacing: 10) {
            AppLogoView(viewModel: viewModel)
            
            HStack(spacing: 6) {
                Text("NxNative Launcher")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(NXTheme.textPrimary)
                    .lineLimit(1)
                
                if let update = viewModel.updateInfo, update.hasUpdate {
                    Button(action: {
                        SoundEffectService.shared.play(.click)
                        viewModel.openUpdateCheckerAndAutoInstall()
                    }) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(NXTheme.secondary)
                                .frame(width: 5, height: 5)
                            Text(viewModel.tr("nav.update"))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .nxGlassInteractive(
                            in: Capsule(),
                            tint: NXTheme.secondary.opacity(0.65),
                            isSelected: true,
                            fallbackFill: NXTheme.secondary.opacity(0.35),
                            fallbackSelectedFill: NXTheme.secondary.opacity(0.35)
                        )
                        .nxGlassTransition(.materialize)
                    }
                    .buttonStyle(NXPressableButtonStyle())
                    .help(viewModel.tr("nav.update_tooltip"))
                }
            }
        }
        .padding(.leading, useFloatingGlassBars ? 4 : 0)
        .padding(.trailing, useFloatingGlassBars ? 12 : 0)
        .padding(.vertical, useFloatingGlassBars ? 3 : 0)
        .modifier(BrandIslandCapsuleModifier(isEnabled: useFloatingGlassBars))
    }
    
    private var navigationTabsIsland: some View {
        NXGlassContainer(spacing: 6) {
            HStack(spacing: isCompactNav ? 3 : 4) {
                ForEach(tabs, id: \.tag) { item in
                    let isSelected = viewModel.selectedTab == item.tag
                    Button(action: {
                        guard !viewModel.isAnyModalPresented else { return }
                        guard viewModel.selectedTab != item.tag else { return }
                        SoundEffectService.shared.play(.tabSwitch)
                        viewModel.selectedTab = item.tag
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: item.icon)
                                .font(.system(size: isCompactNav ? 13 : 12, weight: isSelected ? .bold : .semibold))
                            
                            if !isCompactNav {
                                Text(item.title)
                                    .font(.system(size: 12, weight: isSelected ? .bold : .semibold, design: .rounded))
                                    .lineLimit(1)
                            }
                        }
                        .foregroundColor(isSelected ? .white : .white.opacity(0.86))
                        .padding(.horizontal, isCompactNav ? 10 : 12)
                        .padding(.vertical, 6.5)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(NXPressableButtonStyle())
                    .disabled(viewModel.isAnyModalPresented)
                    .help(item.title)
                    .nxNoFocusRing()
                    .matchedGeometryEffect(id: item.tag, in: navTabNamespace, isSource: true)
                }
            }
            .background {
                NXLiquidSlidingPill(
                    in: Capsule(),
                    tint: NXTheme.primary.opacity(viewModel.liquidGlassEnvironment.mix(frosted: 0.86, liquid: 0.72))
                )
                .matchedGeometryEffect(
                    id: animatedTabPill,
                    in: navTabNamespace,
                    properties: .frame,
                    anchor: .center,
                    isSource: false
                )
            }
            .padding(4)
            .nxGlassBar(
                in: Capsule(),
                fallbackFill: NXTheme.glassSurfaceElevated.opacity(0.75),
                fallbackStroke: NXTheme.borderSubtle
            )
        }
    }
    
    private var statusIsland: some View {
        HStack(spacing: 8) {
            if viewModel.isBuilding {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text(viewModel.tr("status.building"))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .nxGlassBar(
                    in: Capsule(),
                    tint: NXTheme.primary.opacity(0.50),
                    fallbackFill: NXTheme.primary.opacity(0.35),
                    fallbackStroke: NXTheme.secondary.opacity(0.6)
                )
                .nxGlassTransition(.materialize)
            } else {
                StatusBadge(
                    isPositive: viewModel.isProdKeysValid && viewModel.isNxnativeValid,
                    text: (viewModel.isProdKeysValid && viewModel.isNxnativeValid)
                        ? viewModel.tr("status.env_ready")
                        : viewModel.tr("status.setup_required"),
                    showText: false
                )
                .padding(useFloatingGlassBars ? 7 : 0)
                .modifier(BrandIslandCapsuleModifier(isEnabled: useFloatingGlassBars))
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

internal struct BrandIslandCapsuleModifier: ViewModifier {
    let isEnabled: Bool
    
    func body(content: Content) -> some View {
        if isEnabled {
            content.nxGlassBar(in: Capsule())
        } else {
            content
        }
    }
}
