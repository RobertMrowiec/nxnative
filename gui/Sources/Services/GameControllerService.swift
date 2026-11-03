import Foundation
import GameController

public final class GameControllerService: ObservableObject {
    public static let shared = GameControllerService()
    
    @Published public var isGamepadConnected: Bool = false
    @Published public var activeControllerName: String = "No Gamepad Connected"
    @Published public var activeBrand: GamepadBrand = .generic
    @Published public var connectedControllers: [(playerIndex: Int, name: String, brand: GamepadBrand)] = []
    @Published public var activeRunningGameApp: NSRunningApplication? = nil
    
    public var onAction: ((GamepadAction) -> Void)?
    public var onRawElementPressed: ((String) -> Void)?
    public var onRightStickScroll: ((CGFloat) -> Void)?
    
    private var lastNavTime: TimeInterval = 0
    private let navCooldown: TimeInterval = 0.20
    private let stickDeadzone: Float = 0.35
    private var homeButtonHoldTimer: Timer?
    
    private init() {
        GCController.shouldMonitorBackgroundEvents = true
        setupObservers()
        refreshControllers()
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            self?.refreshControllers()
        }
        
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            self?.refreshControllers()
        }
    }
    
    public func refreshControllers() {
        let controllers = GCController.controllers()
        guard let first = controllers.first else {
            isGamepadConnected = false
            activeControllerName = "No Gamepad Connected"
            activeBrand = .generic
            connectedControllers = []
            return
        }
        
        isGamepadConnected = true
        activeControllerName = first.vendorName ?? "Gamepad"
        activeBrand = detectBrand(from: activeControllerName)
        
        var list: [(playerIndex: Int, name: String, brand: GamepadBrand)] = []
        for (idx, c) in controllers.prefix(8).enumerated() {
            let name = c.vendorName ?? "Gamepad"
            let brand = detectBrand(from: name)
            list.append((playerIndex: idx, name: name, brand: brand))
            bindController(c)
        }
        connectedControllers = list
    }
    
    private func detectBrand(from vendor: String) -> GamepadBrand {
        let lower = vendor.lowercased()
        if lower.contains("switch") || lower.contains("joy-con") || lower.contains("nintendo") {
            return .nintendoSwitch
        } else if lower.contains("xbox") || lower.contains("microsoft") {
            return .xbox
        } else if lower.contains("dualsense") || lower.contains("dualshock") || lower.contains("sony") || lower.contains("playstation") {
            return .playstation
        }
        return .generic
    }
    
    private func bindController(_ controller: GCController) {
        guard let gamepad = controller.extendedGamepad else { return }
        
        // D-Pad
        gamepad.dpad.up.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                self?.triggerRawElement("dpad.up")
                self?.triggerAction(.navigateUp)
            }
        }
        gamepad.dpad.down.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                self?.triggerRawElement("dpad.down")
                self?.triggerAction(.navigateDown)
            }
        }
        gamepad.dpad.left.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                self?.triggerRawElement("dpad.left")
                self?.triggerAction(.navigateLeft)
            }
        }
        gamepad.dpad.right.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                self?.triggerRawElement("dpad.right")
                self?.triggerAction(.navigateRight)
            }
        }
        
        // Left Thumbstick Analog Navigation with Deadzone and Cooldown
        gamepad.leftThumbstick.valueChangedHandler = { [weak self] _, xVal, yVal in
            guard let self = self else { return }
            let now = ProcessInfo.processInfo.systemUptime
            guard now - self.lastNavTime > self.navCooldown else { return }
            
            if xVal > self.stickDeadzone {
                self.lastNavTime = now
                self.triggerAction(.navigateRight)
            } else if xVal < -self.stickDeadzone {
                self.lastNavTime = now
                self.triggerAction(.navigateLeft)
            } else if yVal > self.stickDeadzone {
                self.lastNavTime = now
                self.triggerAction(.navigateUp)
            } else if yVal < -self.stickDeadzone {
                self.lastNavTime = now
                self.triggerAction(.navigateDown)
            }
        }
        
        // Right Thumbstick Analog Scrolling for catalogs
        gamepad.rightThumbstick.valueChangedHandler = { [weak self] _, _, yVal in
            guard let self = self else { return }
            if abs(yVal) > 0.15 {
                let delta = CGFloat(yVal * 16.0)
                DispatchQueue.main.async {
                    self.onRightStickScroll?(delta)
                }
            }
        }
        
        // Face Buttons
        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                self?.triggerRawElement("buttonA")
                self?.triggerAction(.confirm)
            }
        }
        gamepad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                self?.triggerRawElement("buttonB")
                self?.triggerAction(.cancel)
            }
        }
        gamepad.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                self?.triggerRawElement("buttonX")
                self?.triggerAction(.secondaryAction)
            }
        }
        gamepad.buttonY.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                self?.triggerRawElement("buttonY")
                self?.triggerAction(.contextAction)
            }
        }
        
        // Shoulders: Tab Switching / Bumpers
        gamepad.leftShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                self?.triggerRawElement("leftShoulder")
                self?.triggerAction(.tabPrevious)
            }
        }
        gamepad.rightShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                self?.triggerRawElement("rightShoulder")
                self?.triggerAction(.tabNext)
            }
        }
        
        // Triggers (ZL / ZR)
        gamepad.leftTrigger.valueChangedHandler = { [weak self] _, val, pressed in
            if pressed || val > 0.35 {
                self?.triggerRawElement("leftTrigger")
            }
        }
        gamepad.rightTrigger.valueChangedHandler = { [weak self] _, val, pressed in
            if pressed || val > 0.35 {
                self?.triggerRawElement("rightTrigger")
            }
        }
        
        // Thumbstick Buttons (L3 / R3)
        gamepad.leftThumbstickButton?.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                self?.triggerRawElement("leftThumbstickButton")
            }
        }
        gamepad.rightThumbstickButton?.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                self?.triggerRawElement("rightThumbstickButton")
            }
        }
        
        // Menu / Plus
        gamepad.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                self?.triggerRawElement("buttonMenu")
                self?.triggerAction(.menu)
            }
        }
        
        // Options / Minus / Share / View (Select Button)
        gamepad.buttonOptions?.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                self?.triggerRawElement("buttonOptions")
                self?.triggerAction(.options)
            }
        }

        // Dedicated Share / Capture Button (on Xbox Series, Switch Pro, DualSense)
        if let share = controller.physicalInputProfile.buttons[GCInputButtonShare] {
            share.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed {
                    self?.triggerRawElement("buttonShare")
                    self?.quitGameAndFocusLauncher()
                }
            }
        }
        
        // Home Button (Xbox Logo / Guide): Pressed & held for 3 seconds quits game & brings NxNative to front
        gamepad.buttonHome?.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                self?.triggerRawElement("buttonHome")
                self?.startHomeHoldTimer()
            } else {
                self?.cancelHomeHoldTimer()
            }
        }
    }
    
    private func triggerRawElement(_ element: String) {
        DispatchQueue.main.async { [weak self] in
            guard NSApplication.shared.isActive else { return }
            self?.onRawElementPressed?(element)
        }
    }
    
    private func startHomeHoldTimer() {
        homeButtonHoldTimer?.invalidate()
        homeButtonHoldTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.handleHomeHold3Seconds()
        }
    }
    
    private func cancelHomeHoldTimer() {
        homeButtonHoldTimer?.invalidate()
        homeButtonHoldTimer = nil
    }
    
    public func quitGameAndFocusLauncher() {
        DispatchQueue.main.async {
            if let app = self.activeRunningGameApp, !app.isTerminated {
                app.terminate()
            }
            self.activeRunningGameApp = nil
            
            for proc in ["nxnative", "dmhost"] {
                let killProc = Process()
                killProc.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
                killProc.arguments = ["-TERM", proc]
                try? killProc.run()
            }
            
            MenuBarManager.shared.restoreMainWindow()
            SoundEffectService.shared.play(.error)
        }
    }

    private func handleHomeHold3Seconds() {
        quitGameAndFocusLauncher()
    }
    
    private func triggerAction(_ action: GamepadAction) {
        DispatchQueue.main.async { [weak self] in
            // Guard against intercepting gamepad events while user is playing another game in foreground
            guard NSApplication.shared.isActive else { return }
            guard !MenuBarManager.isMinimized else { return }
            self?.onAction?(action)
        }
    }
}
