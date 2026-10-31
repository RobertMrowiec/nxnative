import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct RyujinxKeyMissingSheet: View {
    @ObservedObject public var viewModel: AppViewModel
    @State private var isTargeted: Bool = false
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Header Warning
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(Color.orange)
                    .font(.system(size: 22, weight: .bold))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.tr("system.ryujinx_not_found_title"))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(NXTheme.textPrimary)
                    
                    Text(viewModel.tr("system.ryujinx_not_found_desc"))
                        .font(.system(size: 11))
                        .foregroundColor(NXTheme.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, 4)
            
            // Drag and Drop Zone
            VStack(spacing: 10) {
                Image(systemName: isTargeted ? "arrow.down.doc.fill" : "key.fill")
                    .font(.system(size: 28))
                    .foregroundColor(isTargeted ? NXTheme.secondary : NXTheme.primary)
                    .scaleEffect(isTargeted ? 1.15 : 1.0)
                    .animation(.spring(response: 0.28, dampingFraction: 0.76), value: isTargeted)
                
                Text(viewModel.tr("system.drop_keys_here"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(NXTheme.textPrimary)
                
                Text(viewModel.tr("system.drop_keys_subtitle"))
                    .font(.system(size: 10))
                    .foregroundColor(NXTheme.textMuted)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isTargeted ? NXTheme.primary.opacity(0.18) : NXTheme.glassSurfaceElevated.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isTargeted ? NXTheme.secondary : NXTheme.borderSubtle,
                        style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: isTargeted ? [] : [6, 4])
                    )
            )
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                handleDroppedKey(providers: providers)
            }
            
            // Actions
            HStack(spacing: 10) {
                Button(viewModel.tr("library.cancel")) {
                    SoundEffectService.shared.play(.click)
                    viewModel.showRyujinxNotFoundSheet = false
                }
                .buttonStyle(NXSecondaryButtonStyle())
                
                Spacer()
                
                Button(viewModel.tr("system.select_folder")) {
                    SoundEffectService.shared.play(.click)
                    viewModel.selectRyujinxFolder()
                    if viewModel.isProdKeysValid {
                        viewModel.showRyujinxNotFoundSheet = false
                    }
                }
                .buttonStyle(NXSecondaryButtonStyle())
                
                Button(viewModel.tr("system.select_prod_keys")) {
                    SoundEffectService.shared.play(.click)
                    viewModel.selectProdKeysFile()
                    if viewModel.isProdKeysValid {
                        viewModel.showRyujinxNotFoundSheet = false
                    }
                }
                .buttonStyle(NXPrimaryButtonStyle())
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(width: 480)
        .background(NXTheme.canvasObsidian)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(NXTheme.specularRim, lineWidth: 1)
        )
    }
    
    private func handleDroppedKey(providers: [NSItemProvider]) -> Bool {
        var droppedURLs: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                defer { group.leave() }
                if let url = url {
                    droppedURLs.append(url)
                }
            }
        }
        
        group.notify(queue: .main) {
            guard let first = droppedURLs.first else { return }
            var isDir: ObjCBool = false
            let fm = FileManager.default
            if fm.fileExists(atPath: first.path, isDirectory: &isDir) {
                if isDir.boolValue {
                    viewModel.detectEnvironment(customRyujinxDir: first.path)
                    if viewModel.isProdKeysValid {
                        SoundEffectService.shared.play(.click)
                        viewModel.showRyujinxNotFoundSheet = false
                    }
                } else if first.lastPathComponent.lowercased().contains("keys") {
                    viewModel.prodKeysPath = first.path
                    viewModel.prodKeysSource = "Dropped prod.keys"
                    viewModel.isProdKeysValid = true
                    SoundEffectService.shared.play(.click)
                    viewModel.showRyujinxNotFoundSheet = false
                }
            }
        }
        return true
    }
}
