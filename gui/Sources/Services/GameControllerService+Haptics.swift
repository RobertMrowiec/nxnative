import Foundation
import GameController
import CoreHaptics

extension GameControllerService {
    
    /// Triggers a test haptic vibration pulse on the primary connected gamepad or specified player
    public func testRumble(playerIndex: Int = 0, strength: Double = 1.0, floorBoost: Bool = true) {
        let controllers = GCController.controllers()
        guard playerIndex >= 0 && playerIndex < controllers.count else {
            SoundEffectService.shared.play(.error)
            return
        }
        let controller = controllers[playerIndex]
        guard let haptics = controller.haptics else {
            SoundEffectService.shared.play(.error)
            return
        }
        
        var effectiveIntensity = Float(max(0.0, min(1.0, strength)))
        if floorBoost && effectiveIntensity > 0 {
            effectiveIntensity = 0.22 + (0.78 * effectiveIntensity)
        }
        
        let localities = haptics.supportedLocalities
        let targetLocality: GCHapticsLocality
        if localities.contains(.handles) {
            targetLocality = .handles
        } else if localities.contains(.default) {
            targetLocality = .default
        } else if let first = localities.first {
            targetLocality = first
        } else {
            targetLocality = .default
        }
        
        guard let engine = haptics.createEngine(withLocality: targetLocality) else {
            SoundEffectService.shared.play(.error)
            return
        }
        
        do {
            try engine.start()
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: effectiveIntensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: 0,
                duration: 0.45
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                engine.stop(completionHandler: nil)
            }
            SoundEffectService.shared.play(.click)
        } catch {
            SoundEffectService.shared.play(.error)
        }
    }
}
