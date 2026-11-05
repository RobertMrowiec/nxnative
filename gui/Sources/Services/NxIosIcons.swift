import SwiftUI

// MARK: - Professional Vector SVG & Shape Icons (Zero-Emoji Policy)

/// Lightweight vector icons rendered cleanly via SwiftUI Path and SF Symbols.
public enum NxIosIcons {
    /// Renders a cross-style D-Pad glyph with neon specular lighting.
    public struct DPadShape: Shape {
        public func path(in rect: CGRect) -> Path {
            var path = Path()
            let w = rect.width
            let h = rect.height
            let armW = w * 0.34
            let armH = h * 0.34
            let x0 = (w - armW) / 2
            let y0 = (h - armH) / 2

            path.move(to: CGPoint(x: x0, y: 0))
            path.addLine(to: CGPoint(x: x0 + armW, y: 0))
            path.addLine(to: CGPoint(x: x0 + armW, y: y0))
            path.addLine(to: CGPoint(x: w, y: y0))
            path.addLine(to: CGPoint(x: w, y: y0 + armH))
            path.addLine(to: CGPoint(x: x0 + armW, y: y0 + armH))
            path.addLine(to: CGPoint(x: x0 + armW, y: h))
            path.addLine(to: CGPoint(x: x0, y: h))
            path.addLine(to: CGPoint(x: x0, y: y0 + armH))
            path.addLine(to: CGPoint(x: 0, y: y0 + armH))
            path.addLine(to: CGPoint(x: 0, y: y0))
            path.addLine(to: CGPoint(x: x0, y: y0))
            path.closeSubpath()

            return path
        }
    }

    /// Renders a controller thumbstick boundary with inner deadzone ring.
    public struct ThumbstickBase: View {
        public let diameter: CGFloat
        public let isHighlighted: Bool

        public init(diameter: CGFloat = 120, isHighlighted: Bool = false) {
            self.diameter = diameter
            self.isHighlighted = isHighlighted
        }

        public var body: some View {
            ZStack {
                Circle()
                    .fill(NXTheme.glassSurfaceElevated.opacity(0.65))
                    .frame(width: diameter, height: diameter)
                    .overlay(
                        Circle()
                            .strokeBorder(isHighlighted ? NXTheme.primary : NXTheme.borderSubtle, lineWidth: 1.5)
                    )

                Circle()
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    .frame(width: diameter * 0.45, height: diameter * 0.45)
            }
        }
    }

    /// Renders an external USB-C storage badge.
    public struct ExternalStorageBadge: View {
        public let isConnected: Bool

        public init(isConnected: Bool) {
            self.isConnected = isConnected
        }

        public var body: some View {
            HStack(spacing: 4) {
                Image(systemName: "externaldrive.fill")
                    .font(.system(size: 10, weight: .bold))
                Text(isConnected ? "USB-C SSD" : "Internal")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .foregroundColor(isConnected ? NXTheme.secondary : NXTheme.textSecondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(NXTheme.glassSurface.opacity(0.85))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isConnected ? NXTheme.secondary.opacity(0.4) : NXTheme.borderSubtle, lineWidth: 1)
            )
            .cornerRadius(6)
        }
    }

    /// Renders an iCloud synchronization status indicator.
    public struct CloudSyncBadge: View {
        public let state: NxHubSaveSyncState

        public init(state: NxHubSaveSyncState) {
            self.state = state
        }

        public var body: some View {
            HStack(spacing: 5) {
                Image(systemName: state == .syncing ? "arrow.triangle.2.circlepath" : "icloud.fill")
                    .font(.system(size: 10, weight: .bold))
                Text(state.rawValue)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
            }
            .foregroundColor(state == .idle ? Color(red: 0.13, green: 0.77, blue: 0.37) : NXTheme.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(NXTheme.glassSurface.opacity(0.85))
            .cornerRadius(6)
        }
    }
}
