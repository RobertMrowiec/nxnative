import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Liquid Glass On-Screen Touch Controller Overlay

/// Virtual gaming overlay with translucent liquid glass buttons, dynamic analog stick, and tactile haptic feedback.
public struct NXIosTouchOverlay: View {
    @State private var stickOffset: CGSize = .zero
    @State private var isTouchingStick: Bool = false
    @State private var overlayOpacity: Double = 0.65

    public let onButtonPressed: ((String) -> Void)?
    public let onStickMoved: ((CGFloat, CGFloat) -> Void)?

    public init(
        onButtonPressed: ((String) -> Void)? = nil,
        onStickMoved: ((CGFloat, CGFloat) -> Void)? = nil
    ) {
        self.onButtonPressed = onButtonPressed
        self.onStickMoved = onStickMoved
    }

    private func triggerHaptic() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Left Side: D-Pad and Left Analog Stick
                VStack(spacing: 24) {
                    Spacer()
                    analogStickView
                        .padding(.leading, 36)
                        .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity, alignment: .bottomLeading)

                // Right Side: Action Buttons (A, B, X, Y)
                VStack(spacing: 24) {
                    Spacer()
                    actionButtonsCluster
                        .padding(.trailing, 36)
                        .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity, alignment: .bottomTrailing)

                // Top Triggers: L, R, ZL, ZR
                HStack {
                    triggerButton(label: "ZL")
                    triggerButton(label: "L")
                    Spacer()
                    triggerButton(label: "R")
                    triggerButton(label: "ZR")
                }
                .padding(.horizontal, 28)
                .padding(.top, 14)
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .opacity(overlayOpacity)
        }
    }

    // MARK: - Analog Stick
    private var analogStickView: some View {
        ZStack {
            NxIosIcons.ThumbstickBase(diameter: 130, isHighlighted: isTouchingStick)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.35), Color.white.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 55, height: 55)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.5), lineWidth: 1.5))
                .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 3)
                .offset(stickOffset)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isTouchingStick = true
                            let maxDistance: CGFloat = 45
                            let translation = value.translation
                            let distance = sqrt(translation.width * translation.width + translation.height * translation.height)
                            let clampedDistance = min(distance, maxDistance)
                            let angle = atan2(translation.height, translation.width)

                            let finalX = cos(angle) * clampedDistance
                            let finalY = sin(angle) * clampedDistance
                            stickOffset = CGSize(width: finalX, height: finalY)

                            onStickMoved?(finalX / maxDistance, finalY / maxDistance)
                        }
                        .onEnded { _ in
                            isTouchingStick = false
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                                stickOffset = .zero
                            }
                            onStickMoved?(0, 0)
                        }
                )
        }
    }

    // MARK: - Action Buttons (A, B, X, Y)
    private var actionButtonsCluster: some View {
        ZStack {
            actionPill(label: "Y", offset: CGSize(width: -40, height: 0), color: NXTheme.primary)
            actionPill(label: "X", offset: CGSize(width: 0, height: -40), color: NXTheme.secondary)
            actionPill(label: "B", offset: CGSize(width: 0, height: 40), color: Color(red: 0.98, green: 0.82, blue: 0.25))
            actionPill(label: "A", offset: CGSize(width: 40, height: 0), color: Color(red: 0.13, green: 0.77, blue: 0.37))
        }
        .frame(width: 130, height: 130)
    }

    private func actionPill(label: String, offset: CGSize, color: Color) -> some View {
        Button(action: {
            triggerHaptic()
            onButtonPressed?(label)
        }) {
            ZStack {
                Circle()
                    .fill(NXTheme.glassSurfaceElevated.opacity(0.85))
                    .frame(width: 44, height: 44)
                    .overlay(Circle().strokeBorder(color.opacity(0.6), lineWidth: 1.5))
                    .shadow(color: color.opacity(0.3), radius: 6)

                Text(label)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(NXPressableButtonStyle())
        .offset(offset)
    }

    private func triggerButton(label: String) -> some View {
        Button(action: {
            triggerHaptic()
            onButtonPressed?(label)
        }) {
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(NXTheme.glassSurfaceElevated.opacity(0.8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
                .cornerRadius(8)
        }
        .buttonStyle(NXPressableButtonStyle())
    }
}
