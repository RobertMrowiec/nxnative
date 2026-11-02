import SwiftUI
import GameController

struct NewControllerProfileSheet: View {
    @ObservedObject var profileManager = InputProfileManager.shared
    @Binding var isPresented: Bool
    @Binding var activeProfile: ControllerProfile
    @State private var newProfileName: String = ""
    private var i18n = LocalizationService.shared

    var body: some View {
        VStack(spacing: 16) {
            Text(i18n.t("controls.new_profile"))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(NXTheme.textPrimary)

            NXLiquidGlassTextField("Profile Name (e.g. Zelda Pro Controls)", text: $newProfileName)
                .frame(width: 290)

            NXGlassContainer(spacing: 12) {
                HStack(spacing: 12) {
                    Button(i18n.t("common.cancel")) {
                        isPresented = false
                    }
                    .buttonStyle(NXSecondaryButtonStyle())

                    Button(i18n.t("controls.create")) {
                        guard !newProfileName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        let created = profileManager.createProfile(name: newProfileName, basedOn: activeProfile)
                        profileManager.setProfile(created, forPlayer: profileManager.activePlayerIndex)
                        activeProfile = created
                        isPresented = false
                    }
                    .buttonStyle(NXPrimaryButtonStyle())
                    .disabled(newProfileName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .padding(24)
        .frame(width: 340, height: 160)
        .nxSheetSurface()
    }
}
