import SwiftUI
import AppKit

/// Centered Apple Liquid Glass modal dialog shown whenever a port fails,
/// with full Gamepad navigation, error copying, and one-click retry.
public struct BuildErrorBannerView: View {
    @ObservedObject var viewModel: AppViewModel

    public init(viewModel: AppViewModel) { self.viewModel = viewModel }

    private var hasRetryOption: Bool {
        viewModel.isMetalCompilerMismatchError
    }

    public var body: some View {
        if let error = viewModel.buildError, !viewModel.isBuilding {
            ZStack {
                // Liquid Glass Dimming Scrim
                Color.black.opacity(0.60)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        SoundEffectService.shared.play(.click)
                        viewModel.buildError = nil
                    }

                // Centered Liquid Glass Modal Card
                VStack(alignment: .leading, spacing: 14) {
                    // Header Bar
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.orange)

                        Text("Falha na Conversão (Port Failed)")
                            .font(.system(size: 14.5, weight: .bold, design: .rounded))
                            .foregroundColor(NXTheme.textPrimary)

                        Spacer()

                        Button(action: {
                            SoundEffectService.shared.play(.click)
                            viewModel.buildError = nil
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(NXTheme.textSecondary)
                                .padding(6)
                                .background(NXTheme.glassSurfaceElevated.opacity(0.7))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .nxNoFocusRing()
                    }

                    Divider().opacity(0.2)

                    // Error Details (Scrollable & selectable text in monospace)
                    ScrollView {
                        Text(error)
                            .font(.system(size: 11.5, design: .monospaced))
                            .foregroundColor(NXTheme.textPrimary.opacity(0.95))
                            .lineSpacing(3)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                    }
                    .frame(maxHeight: 220)
                    .background(Color.black.opacity(0.35))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1.0)
                    )

                    // Action Buttons (Gamepad Focusable)
                    HStack(spacing: 10) {
                        Spacer()

                        if hasRetryOption {
                            let isRetryFocused = viewModel.buildErrorFocusIndex == 0
                            Button(action: {
                                SoundEffectService.shared.play(.click)
                                viewModel.buildError = nil
                                viewModel.enableAllowOtherMetalAndRetry()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Tentar (--allow-other-metal)")
                                }
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(NXTheme.primary.opacity(isRetryFocused ? 0.95 : 0.75))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(isRetryFocused ? NXTheme.secondary : Color.white.opacity(0.25), lineWidth: isRetryFocused ? 2 : 1)
                                )
                                .shadow(color: isRetryFocused ? NXTheme.secondary.opacity(0.6) : Color.clear, radius: 6)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .nxNoFocusRing()
                        }

                        let copyIndex = hasRetryOption ? 1 : 0
                        let isCopyFocused = viewModel.buildErrorFocusIndex == copyIndex
                        Button(action: {
                            SoundEffectService.shared.play(.click)
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(error, forType: .string)
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.on.doc.fill")
                                Text("Copiar Erro")
                            }
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(NXTheme.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(NXTheme.glassSurfaceElevated)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(isCopyFocused ? NXTheme.secondary : Color.white.opacity(0.18), lineWidth: isCopyFocused ? 2 : 1)
                            )
                            .shadow(color: isCopyFocused ? NXTheme.secondary.opacity(0.6) : Color.clear, radius: 6)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .nxNoFocusRing()

                        let closeIndex = hasRetryOption ? 2 : 1
                        let isCloseFocused = viewModel.buildErrorFocusIndex == closeIndex
                        Button(action: {
                            SoundEffectService.shared.play(.click)
                            viewModel.buildError = nil
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                Text("Fechar")
                            }
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(isCloseFocused ? 0.25 : 0.15))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(isCloseFocused ? NXTheme.secondary : Color.white.opacity(0.30), lineWidth: isCloseFocused ? 2 : 1)
                            )
                            .shadow(color: isCloseFocused ? NXTheme.secondary.opacity(0.6) : Color.clear, radius: 6)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .nxNoFocusRing()
                    }
                }
                .padding(20)
                .frame(maxWidth: 580)
                .nxGlassBar(in: RoundedRectangle(cornerRadius: 20, style: .continuous), tint: Color.red.opacity(0.28))
                .shadow(color: Color.black.opacity(0.65), radius: 24, x: 0, y: 10)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .onAppear {
                viewModel.buildErrorFocusIndex = 0
            }
        }
    }
}
