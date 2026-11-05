import SwiftUI
import GameController

public struct ControlsView: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject private var i18n = LocalizationService.shared
    @ObservedObject private var profileManager = InputProfileManager.shared
    @ObservedObject private var controllerService = GameControllerService.shared
    @Environment(\.nxLiquidGlass) private var glassEnv
    @State private var selectedDeviceIndex: Int = 0 // 0: Controller, 1: Keyboard
    @State private var showNewProfileAlert: Bool = false
    @State private var newProfileName: String = ""
    @State private var activeProfile: ControllerProfile = ControllerProfile.nintendoDefault
    @State private var pressedButtons: Set<SwitchButton> = []
    @State private var monitorTimer: Timer? = nil

    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
        let hasGamepad = GameControllerService.shared.isGamepadConnected
        _selectedDeviceIndex = State(initialValue: hasGamepad ? 0 : 1)
        let current = InputProfileManager.shared.activeProfile
        _activeProfile = State(initialValue: current)
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // MARK: - Header & Profile Management
                    profileManagementHeader
                        .frame(maxWidth: .infinity)
                        .id("controls_card_0")
                        .overlay(cardStroke(for: 0, cornerRadius: 20))

                    // MARK: - Device Mode Selector (Gamepad vs Keyboard)
                    deviceSelectorBar
                        .frame(maxWidth: .infinity)
                        .id("controls_item_device_bar")

                    // MARK: - Main Interactive Mapping Surface
                    if selectedDeviceIndex == 0 {
                        // Controller Mapping with Switch Pro Controller in the Center
                        GlassCard {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Label(i18n.t("controls.controller_mapping"), systemImage: "gamecontroller.fill")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(NXTheme.textPrimary)

                                    Spacer()

                                    Text(controllerService.isGamepadConnected ? controllerService.activeControllerName : i18n.t("controls.gamepad_none"))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(controllerService.isGamepadConnected ? Color(red: 0.13, green: 0.77, blue: 0.37) : NXTheme.textMuted)
                                }

                                Divider().opacity(0.2)

                                ControllerMappingCalloutOverlay(
                                    viewModel: viewModel,
                                    profile: $activeProfile,
                                    pressedButtons: pressedButtons
                                )
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .id("controls_card_1")
                        .overlay(cardStroke(for: 1, cornerRadius: 18))
                        
                        // Analog Stick Deadzone & Calibration (Exclusive to Game Controller mode)
                        AnalogDeadzoneTestView(
                            deadzone: $activeProfile.analogDeadzone,
                            isFocused: viewModel.isInsideControlsCard && viewModel.controlsCardIndex == 2
                        )
                        .frame(maxWidth: .infinity)
                        .id("controls_card_2")
                        .overlay(cardStroke(for: 2, cornerRadius: 18))

                        // Haptics & Vibration (Rumble) Settings
                        ProfileHapticsSection(
                            profile: $activeProfile,
                            isMasterFocused: viewModel.isInsideControlsCard && viewModel.controlsCardIndex == 3 && viewModel.controlsHapticsFocus == 0,
                            isStrengthFocused: viewModel.isInsideControlsCard && viewModel.controlsCardIndex == 3 && viewModel.controlsHapticsFocus == 1,
                            isFloorBoostFocused: viewModel.isInsideControlsCard && viewModel.controlsCardIndex == 3 && viewModel.controlsHapticsFocus == 2,
                            isTestFocused: viewModel.isInsideControlsCard && viewModel.controlsCardIndex == 3 && viewModel.controlsHapticsFocus == 3
                        )
                        .frame(maxWidth: .infinity)
                        .id("controls_card_3")
                        .overlay(cardStroke(for: 3, cornerRadius: 18))
                    } else {
                        // Simple Keyboard Mapping View
                        GlassCard {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Label(i18n.t("controls.keyboard_mapping"), systemImage: "keyboard.fill")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(NXTheme.textPrimary)

                                    Spacer()

                                    Text(i18n.t("controls.click_to_rebind"))
                                        .font(.system(size: 11))
                                        .foregroundColor(NXTheme.secondary)
                                }

                                Divider().opacity(0.2)

                                SimpleKeyboardMappingView(profile: $activeProfile)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .nxScrollEdgeEffect(edges: [.top, .bottom])
            .onChange(of: viewModel.controlsCardIndex) { newIdx in
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo("controls_card_\(newIdx)", anchor: .center)
                }
            }
        }
        .onAppear {
            if !controllerService.isGamepadConnected {
                selectedDeviceIndex = 1
            }
            activeProfile = profileManager.activeProfile
            if selectedDeviceIndex == 0 {
                setupControllerPressMonitoring()
            }
        }
        .onDisappear {
            stopControllerPressMonitoring()
            profileManager.updateProfile(activeProfile)
            profileManager.flushAllSettings()
        }
        .onChange(of: controllerService.isGamepadConnected) { isConnected in
            if !isConnected && selectedDeviceIndex == 0 {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
                    selectedDeviceIndex = 1
                }
            }
        }
        .onChange(of: selectedDeviceIndex) { newIndex in
            if newIndex == 0 {
                setupControllerPressMonitoring()
            } else {
                stopControllerPressMonitoring()
            }
        }
        .onChange(of: profileManager.activeProfileId) { _ in
            activeProfile = profileManager.activeProfile
        }
        .onChange(of: activeProfile) { updated in
            profileManager.updateProfile(updated)
        }
        .sheet(isPresented: $showNewProfileAlert) {
            NewControllerProfileSheet(
                isPresented: $showNewProfileAlert,
                activeProfile: $activeProfile
            )
            .environment(\.nxLiquidGlass, glassEnv)
        }
    }

    // MARK: - Profile Management Toolbar
    private func cardStroke(for index: Int, cornerRadius: CGFloat = 16) -> some View {
        let isSelected = viewModel.controlsCardIndex == index
        let isInside = viewModel.isInsideControlsCard
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

    private var profileManagementHeader: some View {
        ControlsProfileToolbar(
            viewModel: viewModel,
            activeProfile: $activeProfile,
            newProfileName: $newProfileName,
            showNewProfileAlert: $showNewProfileAlert
        )
    }

    // MARK: - Device Mode Selector
    private var deviceSelectorBar: some View {
        HStack(spacing: 12) {
            NXLiquidSegmentedPicker(
                selection: $selectedDeviceIndex,
                options: [
                    NXSegmentOption(value: 0, title: i18n.t("controls.gamepad_tab"), icon: "gamecontroller.fill"),
                    NXSegmentOption(value: 1, title: i18n.t("controls.keyboard_tab"), icon: "keyboard.fill")
                ]
            )
            .frame(maxWidth: 420)

            Spacer()
        }
    }

    private func setupControllerPressMonitoring() {
        stopControllerPressMonitoring()
        guard controllerService.isGamepadConnected else {
            self.pressedButtons = []
            return
        }
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [self] _ in
            guard NSApplication.shared.isActive && !MenuBarManager.isMinimized else { return }
            guard controllerService.isGamepadConnected else {
                if !self.pressedButtons.isEmpty { self.pressedButtons = [] }
                return
            }
            if let pad = GCController.controllers().first?.extendedGamepad {
                var pressed = Set<SwitchButton>()
                for (elemName, switchBtn) in activeProfile.gamepadBindings {
                    if isGamepadElementPressed(pad: pad, element: elemName) {
                        pressed.insert(switchBtn)
                    }
                }
                if self.pressedButtons != pressed {
                    self.pressedButtons = pressed
                }
            } else if !self.pressedButtons.isEmpty {
                self.pressedButtons = []
            }
        }
    }

    private func stopControllerPressMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        if !pressedButtons.isEmpty {
            pressedButtons = []
        }
    }

    private func isGamepadElementPressed(pad: GCExtendedGamepad, element: String) -> Bool {
        switch element {
        case "buttonA": return pad.buttonA.isPressed
        case "buttonB": return pad.buttonB.isPressed
        case "buttonX": return pad.buttonX.isPressed
        case "buttonY": return pad.buttonY.isPressed
        case "leftShoulder": return pad.leftShoulder.isPressed
        case "rightShoulder": return pad.rightShoulder.isPressed
        case "leftTrigger": return pad.leftTrigger.isPressed
        case "rightTrigger": return pad.rightTrigger.isPressed
        case "buttonMenu": return pad.buttonMenu.isPressed
        case "buttonOptions": return pad.buttonOptions?.isPressed ?? false
        case "leftThumbstickButton": return pad.leftThumbstickButton?.isPressed ?? false
        case "rightThumbstickButton": return pad.rightThumbstickButton?.isPressed ?? false
        case "dpad.up": return pad.dpad.up.isPressed
        case "dpad.down": return pad.dpad.down.isPressed
        case "dpad.left": return pad.dpad.left.isPressed
        case "dpad.right": return pad.dpad.right.isPressed
        default: return false
        }
    }
}
