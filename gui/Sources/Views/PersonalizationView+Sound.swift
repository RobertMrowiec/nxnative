import SwiftUI

// MARK: - Sound Effects Settings Extension for PersonalizationView

extension PersonalizationView {
    internal var soundEffectsCard: some View {
        GlassCard(cornerRadius: 16, padding: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: soundService.isSoundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(viewModel.highlightTheme.primaryColor)
                    
                    Text(viewModel.tr("personalization.sound_effects"))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(NXTheme.textPrimary)
                }
                
                Spacer()
                
                Toggle("", isOn: $soundService.isSoundEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .onChange(of: soundService.isSoundEnabled) { val in
                        if val {
                            SoundEffectService.shared.play(.click)
                        }
                    }
            }
        }
    }
}
