import SwiftUI

// MARK: - Appearance, Colors & Sound Settings Extension for PersonalizationView

extension PersonalizationView {
    internal var highlightColorCard: some View {
        GlassCard(cornerRadius: 18, padding: 18) {
            VStack(alignment: .leading, spacing: 16) {
                // Header: Accent Theme title + Liquid Glass On/Off Interactive Pill Button
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(viewModel.highlightTheme.primaryColor)
                        
                        Text(viewModel.tr("personalization.accent_theme"))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(NXTheme.textPrimary)
                    }
                    
                    Spacer()
                }
                
                // 8 Accent Highlight Color Swatches (Equal, uniform size and anti-clipping text)
                let columns = [
                    GridItem(.adaptive(minimum: 190, maximum: 280), spacing: 12)
                ]
                
                NXGlassContainer(spacing: 12) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Array(LauncherHighlightTheme.allCases.enumerated()), id: \.element.id) { idx, theme in
                            let isFocused = viewModel.isInsidePersonalizeCard && viewModel.personalizeCardIndex == 2 && viewModel.personalizeColorFocus == idx
                            colorSwatchButton(theme: theme, isFocused: isFocused)
                        }
                    }
                }
                
                // Subtle concentric divider inside the Color Card
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
                    .padding(.vertical, 2)
                
                // Liquid Glass Appearance Control Bar (Liquid vs Frosted)
                liquidGlassAppearanceRow
            }
        }
    }
    
    internal var liquidGlassToggleButton: some View {
        NXGlassContainer(spacing: 8) {
            Button(action: {
                SoundEffectService.shared.play(.click)
                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                    viewModel.isLiquidGlassEnabled.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isLiquidGlassEnabled ? "sparkles" : "sparkles.slash")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(
                        viewModel.tr(
                            viewModel.isLiquidGlassEnabled
                                ? "personalization.liquid_glass_on"
                                : "personalization.liquid_glass_off"
                        )
                    )
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    
                    Circle()
                        .fill(
                            viewModel.isLiquidGlassEnabled
                                ? Color(red: 0.20, green: 0.86, blue: 0.48)
                                : Color.white.opacity(0.25)
                        )
                        .frame(width: 7, height: 7)
                        .shadow(
                            color: viewModel.isLiquidGlassEnabled
                                ? Color(red: 0.20, green: 0.86, blue: 0.48).opacity(0.75)
                                : .clear,
                            radius: 4
                        )
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .contentShape(Capsule())
                .nxGlassInteractive(
                    in: Capsule(),
                    tint: viewModel.isLiquidGlassEnabled
                        ? viewModel.highlightTheme.primaryColor.opacity(0.60)
                        : nil,
                    isSelected: viewModel.isLiquidGlassEnabled,
                    fallbackFill: NXTheme.glassSurfaceElevated,
                    fallbackSelectedFill: viewModel.highlightTheme.primaryColor.opacity(0.26)
                )
            }
            .buttonStyle(NXPressableButtonStyle())
            .nxNoFocusRing()
        }
    }
    
    internal func colorSwatchButton(theme: LauncherHighlightTheme, isFocused: Bool = false) -> some View {
        let isSelected = viewModel.highlightTheme == theme
        return Button(action: {
            SoundEffectService.shared.play(.click)
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                viewModel.highlightTheme = theme
            }
        }) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [theme.primaryColor, theme.secondaryColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                        .shadow(
                            color: theme.primaryColor.opacity(isSelected ? 0.65 : 0.30),
                            radius: isSelected ? 8 : 4,
                            x: 0,
                            y: 2
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    Color.white.opacity(isSelected ? 0.85 : 0.25),
                                    lineWidth: isSelected ? 1.5 : 0.8
                                )
                        )
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(.white)
                    }
                }
                
                Text(theme.rawValue)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .allowsTightening(true)
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .contentShape(Rectangle())
            .nxGlassInteractive(
                in: RoundedRectangle(cornerRadius: 12, style: .continuous),
                tint: isSelected ? theme.primaryColor.opacity(0.55) : nil,
                isSelected: isSelected || isFocused,
                fallbackFill: NXTheme.glassSurfaceElevated.opacity(0.5),
                fallbackSelectedFill: theme.primaryColor.opacity(0.24)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isFocused ? NXTheme.secondary : Color.clear, lineWidth: 1.5)
            )
            .nxGlassID(isSelected ? "selectedHighlightSwatch" : nil, in: colorSelectionNamespace)
        }
        .buttonStyle(NXPressableButtonStyle())
        .nxNoFocusRing()
    }
    
    internal var liquidGlassAppearanceRow: some View {
        HStack(spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            viewModel.isLiquidGlassEnabled
                                ? viewModel.highlightTheme.primaryColor.opacity(0.22)
                                : Color.white.opacity(0.06)
                        )
                        .frame(width: 36, height: 36)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8)
                        )
                    
                    Image(
                        systemName: viewModel.isLiquidGlassEnabled
                            ? viewModel.liquidGlassAppearance.iconName
                            : "eye.slash"
                    )
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(
                        viewModel.isLiquidGlassEnabled
                            ? viewModel.highlightTheme.secondaryColor
                            : NXTheme.textMuted
                    )
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(viewModel.tr("personalization.glass_appearance"))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(NXTheme.textPrimary)
                        
                        if viewModel.isLiquidGlassEnabled {
                            Text("\(Int(round(viewModel.liquidGlassIntensity * 100)))%")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1.5)
                                .background(
                                    Capsule()
                                        .fill(viewModel.highlightTheme.primaryColor.opacity(0.45))
                                )
                        }
                    }
                    
                    Text(
                        viewModel.isLiquidGlassEnabled
                            ? viewModel.tr(viewModel.liquidGlassAppearance.descriptionLocalizationKey)
                            : viewModel.tr("personalization.glass_off_desc")
                    )
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.90))
                    .lineLimit(2)
                }
            }
            
            Spacer(minLength: 12)
            
            // Inline controls: [Frosted ──●── Liquid] continuous slider (only when enabled) + on/off toggle
            HStack(spacing: 14) {
                if viewModel.isLiquidGlassEnabled {
                    HStack(spacing: 8) {
                        Button(action: {
                            SoundEffectService.shared.play(.click)
                            withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
                                viewModel.liquidGlassIntensity = 0.0
                            }
                        }) {
                            Text(viewModel.tr("personalization.glass_frosted"))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(NXPressableButtonStyle())
                        .nxNoFocusRing()
                        
                        NXLiquidGlassSlider(
                            value: $viewModel.liquidGlassIntensity,
                            in: 0.0...1.0,
                            step: nil,
                            accentColor: viewModel.highlightTheme.primaryColor
                        )
                        .frame(width: 165)
                        .overlay(
                            Capsule()
                                .stroke((viewModel.isInsidePersonalizeCard && viewModel.personalizeCardIndex == 2 && viewModel.personalizeColorFocus == 8) ? NXTheme.secondary : Color.clear, lineWidth: 1.5)
                        )
                        
                        Button(action: {
                            SoundEffectService.shared.play(.click)
                            withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
                                viewModel.liquidGlassIntensity = 1.0
                            }
                        }) {
                            Text(viewModel.tr("personalization.glass_liquid"))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(NXPressableButtonStyle())
                        .nxNoFocusRing()
                    }
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
                
                Toggle("", isOn: $viewModel.isLiquidGlassEnabled.animation(.spring(response: 0.34, dampingFraction: 0.76)))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke((viewModel.isInsidePersonalizeCard && viewModel.personalizeCardIndex == 2 && viewModel.personalizeColorFocus == 9) ? NXTheme.secondary : Color.clear, lineWidth: 1.5)
                    )
                    .onChange(of: viewModel.isLiquidGlassEnabled) { _ in
                        SoundEffectService.shared.play(.click)
                    }
            }
        }
        .padding(12)
        .nxGlassCard(cornerRadius: 12, isNested: true)
    }
}
