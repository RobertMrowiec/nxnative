import Foundation

public enum MouseKeyCode {
    public static let left: UInt16 = 1001
    public static let right: UInt16 = 1002
    public static let middle: UInt16 = 1003
    public static let button4: UInt16 = 1004
    public static let button5: UInt16 = 1005

    public static func fromButtonNumber(_ num: Int) -> UInt16 {
        let code = 1001 + num
        return (code >= 1001 && code <= 1099) ? UInt16(code) : 0
    }

    public static func isMouse(_ code: UInt16) -> Bool {
        return code >= 1001 && code <= 1099
    }

    public static func name(for code: UInt16) -> String? {
        switch code {
        case left: return L10n.t("controls.mouse_button_left")
        case right: return L10n.t("controls.mouse_button_right")
        case middle: return L10n.t("controls.mouse_button_middle")
        case button4: return L10n.t("controls.mouse_button_4")
        case button5: return L10n.t("controls.mouse_button_5")
        default: return (code >= 1001 && code <= 1099) ? "Mouse \(code - 1000)" : nil
        }
    }
}

public enum KeyBindingTarget: Equatable {
    case switchButton(SwitchButton)
    case movement(String) // "up", "left", "down", "right"
}
