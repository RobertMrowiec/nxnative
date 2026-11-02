import SwiftUI

/// Liquid Glass modal picker for 8 Players (P1..P8), fully navigable and interactable with gamepads.
struct ControlsPlayerLiquidPicker: View {
    @ObservedObject var profileManager = InputProfileManager.shared
    @ObservedObject var controllerService = GameControllerService.shared
    @Binding var isPresented: Bool
    @Binding var focusedPlayerIndex: Int

    var body: some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()
                .onTapGesture {
                    SoundEffectService.shared.play(.click)
                    isPresented = false
                }

            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(NXTheme.primary)

                    Text("Selecione o Jogador (1 - 8)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: {
                        SoundEffectService.shared.play(.click)
                        isPresented = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Divider().opacity(0.2)

                // Grid of 8 Players (2 rows of 4)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                    ForEach(0..<8, id: \.self) { pIdx in
                        let isSelected = (pIdx == profileManager.activePlayerIndex)
                        let isFocused = (pIdx == focusedPlayerIndex)
                        let isConnected = pIdx < controllerService.connectedControllers.count
                        let assignedProfile = profileManager.profile(forPlayer: pIdx)

                        Button(action: {
                            SoundEffectService.shared.play(.click)
                            selectPlayer(pIdx)
                        }) {
                            VStack(spacing: 6) {
                                HStack(spacing: 4) {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(isSelected ? NXTheme.primary : .white.opacity(0.85))

                                    Text("P\(pIdx + 1)")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)

                                    if isConnected {
                                        Circle()
                                            .fill(Color(red: 0.13, green: 0.77, blue: 0.37))
                                            .frame(width: 6, height: 6)
                                    }
                                }

                                Text(assignedProfile.name)
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.75))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 6)
                            .contentShape(RoundedRectangle(cornerRadius: 14))
                            .nxGlassInteractive(
                                in: RoundedRectangle(cornerRadius: 14),
                                fallbackFill: isFocused ? NXTheme.primary.opacity(0.40) : (isSelected ? NXTheme.glassSurfaceElevated : Color.white.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(isFocused ? NXTheme.secondary : (isSelected ? NXTheme.primary : Color.clear), lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(NXPressableButtonStyle())
                    }
                }

                Divider().opacity(0.2)

                // Footer
                HStack {
                    Text(controllerService.connectedControllers.isEmpty ? "Nenhum controle físico conectado" : "\(controllerService.connectedControllers.count) controle(s) conectado(s)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(NXTheme.textSecondary)

                    Spacer()

                    Button(action: {
                        SoundEffectService.shared.play(.click)
                        isPresented = false
                    }) {
                        Text("Pronto")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .contentShape(Capsule())
                            .nxGlassInteractive(in: Capsule(), fallbackFill: NXTheme.primary)
                    }
                    .buttonStyle(NXPressableButtonStyle())
                }
            }
            .padding(20)
            .frame(width: 480)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(NXTheme.glassSurfaceElevated.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(NXTheme.borderSubtle, lineWidth: 1.2)
            )
            .shadow(color: Color.black.opacity(0.55), radius: 24, x: 0, y: 12)
        }
        .onAppear {
            focusedPlayerIndex = profileManager.activePlayerIndex
        }
    }

    private func selectPlayer(_ pIdx: Int) {
        profileManager.activePlayerIndex = pIdx
        let assigned = profileManager.profile(forPlayer: pIdx)
        profileManager.activeProfileId = assigned.id
        isPresented = false
    }
}
