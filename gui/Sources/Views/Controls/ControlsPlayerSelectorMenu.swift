import SwiftUI

struct ControlsPlayerSelectorMenu: View {
    public var isFocused: Bool = false
    @Binding public var isPresented: Bool
    @Binding public var focusedIndex: Int
    @ObservedObject var profileManager = InputProfileManager.shared
    @ObservedObject var controllerService = GameControllerService.shared

    var body: some View {
        Button(action: {
            SoundEffectService.shared.play(.click)
            focusedIndex = profileManager.activePlayerIndex
            isPresented.toggle()
        }) {
            HStack(spacing: 6) {
                Image(systemName: "person.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(NXTheme.primary)

                Text("P\(profileManager.activePlayerIndex + 1)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                if profileManager.activePlayerIndex < controllerService.connectedControllers.count {
                    Circle()
                        .fill(Color(red: 0.13, green: 0.77, blue: 0.37))
                        .frame(width: 6, height: 6)
                }

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Capsule())
            .nxGlassInteractive(
                in: Capsule(),
                fallbackFill: isFocused ? NXTheme.primary.opacity(0.35) : NXTheme.glassSurfaceElevated
            )
            .overlay(
                Capsule()
                    .stroke(isFocused ? NXTheme.secondary : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(NXPressableButtonStyle())
        .fixedSize()
        .nxNoFocusRing()
        .sheet(isPresented: $isPresented) {
            ControlsPlayerLiquidPicker(
                isPresented: $isPresented,
                focusedPlayerIndex: $focusedIndex
            )
        }
    }
}
