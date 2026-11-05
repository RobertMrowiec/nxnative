import SwiftUI

public struct PersonalizationView: View {
    @ObservedObject public var viewModel: AppViewModel
    @ObservedObject internal var soundService = SoundEffectService.shared
    @Namespace internal var glassAppearanceNamespace
    @Namespace internal var colorSelectionNamespace
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    private var hasNonDefaultSettings: Bool {
        viewModel.highlightTheme != .electricPurple
            || viewModel.iconAppearanceMode != .default
            || !soundService.isSoundEnabled
            || viewModel.launcherLanguage != .system
            || !viewModel.isLiquidGlassEnabled
            || abs(viewModel.liquidGlassIntensity - 1.0) > 0.01
    }
    
    private func cardStroke(for index: Int, cornerRadius: CGFloat = 16) -> some View {
        let isSelected = viewModel.personalizeCardIndex == index
        let isInside = viewModel.isInsidePersonalizeCard
        return RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(
                isSelected ? (isInside ? NXTheme.secondary.opacity(0.85) : NXTheme.primary) : Color.clear,
                lineWidth: isSelected ? (isInside ? 1.5 : 2.5) : 0
            )
            .shadow(
                color: (isSelected && !isInside) ? NXTheme.primary.opacity(0.45) : Color.clear,
                radius: 8
            )
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerView
                        .frame(maxWidth: .infinity)
                        .id("personalize_card_0")
                        .overlay(cardStroke(for: 0, cornerRadius: 16))

                    launcherLanguageCard
                        .frame(maxWidth: .infinity)
                        .id("personalize_card_1")
                        .overlay(cardStroke(for: 1, cornerRadius: 16))

                    highlightColorCard
                        .frame(maxWidth: .infinity)
                        .id("personalize_card_2")
                        .overlay(cardStroke(for: 2, cornerRadius: 18))

                    SystemAppearanceCard(viewModel: viewModel)
                        .frame(maxWidth: .infinity)
                        .id("personalize_card_3")
                        .overlay(cardStroke(for: 3, cornerRadius: 16))

                    soundEffectsCard
                        .frame(maxWidth: .infinity)
                        .id("personalize_card_4")
                        .overlay(cardStroke(for: 4, cornerRadius: 16))
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .nxScrollEdgeEffect(edges: [.top, .bottom])
            .onChange(of: viewModel.personalizeCardIndex) { newIdx in
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo("personalize_card_\(newIdx)", anchor: .center)
                }
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Text(viewModel.tr("personalization.title"))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(NXTheme.textPrimary)
            
            Spacer()
            
            if hasNonDefaultSettings {
                NXGlassContainer(spacing: 8) {
                    Button(action: {
                        SoundEffectService.shared.play(.click)
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) {
                            viewModel.highlightTheme = .electricPurple
                            viewModel.iconAppearanceMode = .default
                            soundService.isSoundEnabled = true
                            viewModel.launcherLanguage = .system
                            viewModel.isLiquidGlassEnabled = true
                            viewModel.liquidGlassIntensity = 1.0
                            viewModel.liquidGlassAppearance = .liquid
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                            Text(viewModel.tr("personalization.reset_defaults"))
                        }
                    }
                    .buttonStyle(NXSecondaryButtonStyle())
                    .nxGlassTransition(.materialize)
                }
            }
        }
    }
    
    private var launcherLanguageCard: some View {
        GlassCard(cornerRadius: 16, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(viewModel.highlightTheme.primaryColor)
                    
                    Text(viewModel.tr("personalization.launcher_language"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(NXTheme.textPrimary)
                    
                    Spacer()
                }
                
                let columns = [
                    GridItem(.adaptive(minimum: 165, maximum: 260), spacing: 10)
                ]
                
                NXGlassContainer(spacing: 10) {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(Array(AppLanguage.sortedForDisplay.enumerated()), id: \.element.id) { idx, lang in
                            let isSelected = viewModel.launcherLanguage == lang
                            let isFocused = viewModel.isInsidePersonalizeCard && viewModel.personalizeCardIndex == 1 && viewModel.personalizeLangFocus == idx
                            languagePill(lang: lang, isSelected: isSelected, isFocused: isFocused)
                        }
                    }
                }
            }
        }
    }
    
    private func languagePill(lang: AppLanguage, isSelected: Bool, isFocused: Bool = false) -> some View {
        Button(action: {
            SoundEffectService.shared.play(.click)
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                viewModel.launcherLanguage = lang
            }
        }) {
            HStack(spacing: 10) {
                Text(lang.flag)
                    .font(.system(size: 18))
                
                Text(lang == .system ? viewModel.tr("personalization.icon_auto") : lang.nativeName)
                    .font(.system(size: 12, weight: isSelected ? .bold : .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer(minLength: 0)
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .nxGlassInteractive(
                in: RoundedRectangle(cornerRadius: 10, style: .continuous),
                isSelected: isSelected || isFocused,
                fallbackFill: NXTheme.glassSurfaceElevated.opacity(0.5),
                fallbackSelectedFill: viewModel.highlightTheme.primaryColor.opacity(0.24)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isFocused ? NXTheme.secondary : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(NXPressableButtonStyle())
        .nxNoFocusRing()
    }
}
