import SwiftUI
import UniformTypeIdentifiers
import AppKit

public struct LibraryEmptyDropView: View {
    @ObservedObject public var viewModel: AppViewModel
    @State private var isTargeted: Bool = false
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            VStack(spacing: 16) {
                // Interactive Icon with Fluid Scaling
                ZStack {
                    Circle()
                        .fill(NXTheme.primary.opacity(isTargeted ? 0.25 : 0.12))
                        .frame(width: 96, height: 96)
                    
                    Image(systemName: isTargeted ? "arrow.down.doc.fill" : "plus.rectangle.on.folder.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundColor(isTargeted ? NXTheme.secondary : NXTheme.primary)
                        .scaleEffect(isTargeted ? 1.12 : 1.0)
                        .animation(.spring(response: 0.30, dampingFraction: 0.70), value: isTargeted)
                }
                
                VStack(spacing: 6) {
                    Text(viewModel.tr("library.empty_drop_title"))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(NXTheme.textPrimary)
                    
                    Text(viewModel.tr("library.empty_drop_subtitle"))
                        .font(.system(size: 12))
                        .foregroundColor(NXTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }
                
                HStack(spacing: 12) {
                    Button(action: {
                        SoundEffectService.shared.play(.click)
                        viewModel.selectAdditionalGameFolder()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "shippingbox.fill")
                            Text(viewModel.tr("library.choose_folder"))
                        }
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .contentShape(Capsule())
                        .nxGlassInteractive(
                            in: Capsule(),
                            tint: NXTheme.primary.opacity(0.80),
                            isSelected: true,
                            fallbackFill: NXTheme.primary,
                            fallbackSelectedFill: NXTheme.primary
                        )
                    }
                    .buttonStyle(NXPressableButtonStyle())
                    .nxNoFocusRing()
                    
                    Button(action: {
                        SoundEffectService.shared.play(.click)
                        viewModel.selectAdditionalNonSwitchGameFolder()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "gamecontroller.fill")
                            Text(viewModel.tr("system.add_nonswitch_folder"))
                        }
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .contentShape(Capsule())
                        .nxGlassInteractive(
                            in: Capsule(),
                            tint: Color(red: 0.20, green: 0.82, blue: 0.60).opacity(0.80),
                            isSelected: true,
                            fallbackFill: Color(red: 0.20, green: 0.82, blue: 0.60),
                            fallbackSelectedFill: Color(red: 0.20, green: 0.82, blue: 0.60)
                        )
                    }
                    .buttonStyle(NXPressableButtonStyle())
                    .nxNoFocusRing()
                }
                .padding(.top, 4)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isTargeted ? NXTheme.primary.opacity(0.08) : Color.white.opacity(0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        isTargeted ? AnyShapeStyle(NXTheme.secondary) : AnyShapeStyle(NXTheme.specularRim),
                        style: StrokeStyle(lineWidth: isTargeted ? 2.0 : 1.2, dash: isTargeted ? [8] : [6])
                    )
            )
            .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isTargeted)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            var urls: [URL] = []
            let group = DispatchGroup()
            
            for provider in providers {
                group.enter()
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    defer { group.leave() }
                    if let fileURL = url {
                        urls.append(fileURL)
                    }
                }
            }
            
            group.notify(queue: .main) {
                if !urls.isEmpty {
                    SoundEffectService.shared.play(.click)
                    viewModel.handleDroppedURLs(urls)
                }
            }
            return true
        }
    }
}
