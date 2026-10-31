import SwiftUI
import UniformTypeIdentifiers
import AppKit

public struct AddGameCardView: View {
    @ObservedObject public var viewModel: AppViewModel
    public let baseSize: CGFloat
    @State private var isTargeted: Bool = false
    @State private var isHovered: Bool = false
    
    public init(viewModel: AppViewModel, baseSize: CGFloat = 170) {
        self.viewModel = viewModel
        self.baseSize = baseSize
    }
    
    private var borderStrokeStyle: AnyShapeStyle {
        if isTargeted {
            return AnyShapeStyle(NXTheme.secondary)
        } else if isHovered {
            return AnyShapeStyle(NXTheme.primary.opacity(0.8))
        } else {
            return AnyShapeStyle(NXTheme.specularRim)
        }
    }
    
    public var body: some View {
        Button(action: {
            SoundEffectService.shared.play(.click)
            openFileOrFolderPicker()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isTargeted ? NXTheme.primary.opacity(0.16) : (isHovered ? Color.white.opacity(0.05) : Color.white.opacity(0.02)))
                
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(NXTheme.primary.opacity(isTargeted || isHovered ? 0.25 : 0.12))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: isTargeted ? "arrow.down.doc.fill" : "plus")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(isTargeted ? NXTheme.secondary : (isHovered ? NXTheme.primary : NXTheme.textSecondary))
                    }
                    
                    Text(viewModel.tr("library.add_game_card"))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(isHovered ? NXTheme.textPrimary : NXTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 8)
                    
                    Text("NSP, NSZ, XCI, XCZ, APP")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundColor(isHovered ? NXTheme.textSecondary : NXTheme.textMuted.opacity(0.80))
                        .lineLimit(1)
                }
            }
            .frame(width: baseSize, height: baseSize)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        borderStrokeStyle,
                        style: StrokeStyle(lineWidth: isTargeted ? 2.0 : 1.4, dash: [6])
                    )
            )
            .scaleEffect(isHovered || isTargeted ? 1.04 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isHovered)
            .animation(.spring(response: 0.24, dampingFraction: 0.80), value: isTargeted)
        }
        .buttonStyle(PlainButtonStyle())
        .nxNoFocusRing()
        .onHover { hovering in
            self.isHovered = hovering
        }
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
    
    private func openFileOrFolderPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [
            UTType(filenameExtension: "nsp") ?? .data,
            UTType(filenameExtension: "nsz") ?? .data,
            UTType(filenameExtension: "xci") ?? .data,
            UTType(filenameExtension: "xcz") ?? .data,
            UTType.application,
            .folder
        ]
        panel.prompt = viewModel.tr("common.choose")
        panel.message = viewModel.tr("library.empty_drop_subtitle")
        
        if panel.runModal() == .OK {
            viewModel.handleDroppedURLs(panel.urls)
        }
    }
}
