import SwiftUI
import AppKit

public struct UniversalControlsGuideView: View {
    @ObservedObject public var viewModel: AppViewModel
    @ObservedObject private var controllerService = GameControllerService.shared
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 16) {
            // MARK: - Header
            HStack(spacing: 12) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 24))
                    .foregroundColor(NXTheme.primary)

                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.tr("controls.guide_title"))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(NXTheme.textPrimary)

                    Text(viewModel.tr("controls.guide_subtitle"))
                        .font(.system(size: 11.5))
                        .foregroundColor(NXTheme.textSecondary)
                }

                Spacer()

                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(NXTheme.textSecondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.bottom, 2)

            // MARK: - Critical Switch Title Screen Prompt Banner (L + R)
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.yellow)

                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.tr("controls.title_screen_tip_title"))
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text(viewModel.tr("controls.title_screen_tip_desc"))
                        .font(.system(size: 11.5))
                        .foregroundColor(.white.opacity(0.92))
                        .lineSpacing(2)

                    HStack(spacing: 16) {
                        HStack(spacing: 6) {
                            Text("Keyboard:")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(NXTheme.textSecondary)
                            keyPill("Q")
                            Text("+")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                            keyPill("E")
                        }

                        Divider()
                            .frame(height: 14)
                            .background(Color.white.opacity(0.3))

                        HStack(spacing: 6) {
                            Text("Gamepad:")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(NXTheme.textSecondary)
                            keyPill("LB / L1")
                            Text("+")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                            keyPill("RB / R1")
                        }
                    }
                    .padding(.top, 2)
                }

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.orange.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.orange.opacity(0.40), lineWidth: 1)
                    )
            )

            // MARK: - Dual Column: Keyboard vs Gamepad
            HStack(alignment: .top, spacing: 14) {
                // Keyboard Layout Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "keyboard.fill")
                            .font(.system(size: 13))
                            .foregroundColor(NXTheme.secondary)
                        Text("Mac Keyboard")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(NXTheme.textPrimary)
                    }

                    VStack(spacing: 6) {
                        controlRow(action: "Move / Walk", keys: ["W", "A", "S", "D"])
                        controlRow(action: "A (Confirm)", keys: ["J"])
                        controlRow(action: "B (Cancel / Jump)", keys: ["K"])
                        controlRow(action: "X (Action)", keys: ["U"])
                        controlRow(action: "Y (Action)", keys: ["I"])
                        controlRow(action: "L / R (Bumpers)", keys: ["Q", "E"])
                        controlRow(action: "ZL / ZR (Triggers)", keys: ["Z", "C"])
                        controlRow(action: "+ (Plus / Menu)", keys: ["Return ↵"])
                        controlRow(action: "- (Minus / Map)", keys: ["Tab ⇥"])
                        controlRow(action: "D-Pad", keys: ["↑", "←", "↓", "→"])
                    }
                }
                .padding(12)
                .nxGlassCard(cornerRadius: 10, isNested: true)

                // Gamepad Layout Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 13))
                            .foregroundColor(controllerService.isGamepadConnected ? Color(red: 0.13, green: 0.77, blue: 0.37) : NXTheme.primary)
                        Text(controllerService.isGamepadConnected ? controllerService.activeControllerName : "Gamepad (Xbox / PS / Switch)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(NXTheme.textPrimary)
                            .lineLimit(1)
                    }

                    VStack(spacing: 6) {
                        controlRow(action: "Movement / Aim", keys: ["Left Stick", "Right Stick"])
                        controlRow(action: "A (Confirm)", keys: ["Xbox B", "DualSense ○", "Switch A"])
                        controlRow(action: "B (Cancel)", keys: ["Xbox A", "DualSense ✕", "Switch B"])
                        controlRow(action: "X (Action)", keys: ["Xbox Y", "DualSense △", "Switch X"])
                        controlRow(action: "Y (Action)", keys: ["Xbox X", "DualSense □", "Switch Y"])
                        controlRow(action: "L / R (Bumpers)", keys: ["LB / L1", "RB / R1"])
                        controlRow(action: "ZL / ZR (Triggers)", keys: ["LT / L2", "RT / R2"])
                        controlRow(action: "+ (Start / Menu)", keys: ["Menu ☰ / Options"])
                        controlRow(action: "- (Select / Map)", keys: ["View ⧉ / Share"])
                        controlRow(action: "D-Pad", keys: ["D-Pad Buttons"])
                    }
                }
                .padding(12)
                .nxGlassCard(cornerRadius: 10, isNested: true)
            }

            // MARK: - Footer Actions & Connection Status
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(controllerService.isGamepadConnected ? Color(red: 0.13, green: 0.77, blue: 0.37) : Color.gray.opacity(0.5))
                        .frame(width: 8, height: 8)

                    Text(controllerService.isGamepadConnected ? "Gamepad Active" : "No Gamepad (Keyboard Active)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(NXTheme.textSecondary)
                }

                Spacer()

                Button(action: {
                    dismiss()
                    viewModel.selectedTab = 2 // Switch to Controls tab
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "slider.horizontal.3")
                        Text(viewModel.tr("controls.customize_keybindings"))
                    }
                    .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(NXSecondaryButtonStyle())
                .controlSize(.small)

                Button(action: {
                    dismiss()
                }) {
                    Text(viewModel.tr("common.done"))
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 14)
                }
                .buttonStyle(NXPrimaryButtonStyle())
                .controlSize(.small)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(width: 620)
        .nxGlassCard(cornerRadius: 14)
    }

    private func controlRow(action: String, keys: [String]) -> some View {
        HStack(spacing: 6) {
            Text(action)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(NXTheme.textSecondary)
            Spacer()
            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { k in
                    keyPill(k)
                }
            }
        }
    }

    private func keyPill(_ key: String) -> some View {
        Text(key)
            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(Color.white.opacity(0.12))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.6)
            )
    }
}
