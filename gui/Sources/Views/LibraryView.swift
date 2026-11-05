import SwiftUI
import AppKit

public struct LibraryView: View {
    @ObservedObject public var viewModel: AppViewModel
    @ObservedObject private var controllerService = GameControllerService.shared
    public var containerHeight: CGFloat

    public init(viewModel: AppViewModel, containerHeight: CGFloat = 720) {
        self.viewModel = viewModel
        self.containerHeight = containerHeight
    }
    
    private var filteredGames: [PortedGame] {
        if viewModel.librarySearchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return viewModel.libraryGames
        }
        return viewModel.libraryGames.filter {
            $0.name.localizedCaseInsensitiveContains(viewModel.librarySearchText)
        }
    }
    
    private var currentSelectedGame: PortedGame? {
        viewModel.currentFocusedGame
    }
    
    public var body: some View {
        let isLibraryEmptyAfterScan = !viewModel.isScanningLibrary && viewModel.libraryGames.isEmpty && viewModel.unportedGames.isEmpty

        ZStack {
            SwitchConsoleLibraryView(
                viewModel: viewModel,
                games: filteredGames,
                containerHeight: containerHeight
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(isLibraryEmptyAfterScan ? 0 : 1)
            .allowsHitTesting(!isLibraryEmptyAfterScan)

            if isLibraryEmptyAfterScan {
                LibraryEmptyDropView(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Compact Console Action Sheet (Overlay when Game Selected)
            if viewModel.isGameActionMenuPresented, let selected = currentSelectedGame {
                CompactConsoleActionSheetView(
                    game: selected,
                    viewModel: viewModel,
                    onRemoveFromLibrary: { target in
                        viewModel.gameToRemove = target
                        viewModel.showRemoveConfirm = true
                    },
                    onDeleteToTrash: { target in
                        viewModel.gameToTrash = target
                        viewModel.showTrashConfirm = true
                    },
                    onDelete: { target in
                        viewModel.gameToTrash = target
                        viewModel.showTrashConfirm = true
                    },
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            viewModel.isGameActionMenuPresented = false
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(100)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if viewModel.detectedGames.isEmpty && !viewModel.gameFolders.isEmpty {
                viewModel.scanAllGameFolders()
            }
            viewModel.reconcileLibraryFocusState()
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isGameActionMenuPresented)
        .sheet(item: $viewModel.gameForSettingsSheet) { game in
            GameSettingsSheetView(viewModel: viewModel, game: game)
                .environment(\.nxLiquidGlass, viewModel.liquidGlassEnvironment)
        }
        .sheet(item: $viewModel.gameForPortModal) { game in
            PortGameModalView(game: game, viewModel: viewModel)
                .environment(\.nxLiquidGlass, viewModel.liquidGlassEnvironment)
        }
        .confirmationDialog(
            viewModel.tr("library.remove_title", viewModel.gameToRemove?.name ?? "Game"),
            isPresented: $viewModel.showRemoveConfirm,
            titleVisibility: .visible
        ) {
            Button(viewModel.tr("library.remove_button")) {
                if let g = viewModel.gameToRemove {
                    viewModel.removeGameFromLibrary(g)
                }
            }
            Button(viewModel.tr("library.cancel"), role: .cancel) {}
        } message: {
            Text(viewModel.tr("library.remove_message"))
        }
        .confirmationDialog(
            viewModel.tr("library.trash_title", viewModel.gameToTrash?.name ?? "Game"),
            isPresented: $viewModel.showTrashConfirm,
            titleVisibility: .visible
        ) {
            Button(viewModel.tr("library.trash_button"), role: .destructive) {
                if let g = viewModel.gameToTrash {
                    viewModel.deleteGameToTrash(g)
                }
            }
            Button(viewModel.tr("library.cancel"), role: .cancel) {}
        } message: {
            Text(viewModel.tr("library.trash_message"))
        }
        .confirmationDialog(
            viewModel.tr("library.delete_title", viewModel.gameToDelete?.name ?? "Game"),
            isPresented: $viewModel.showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(viewModel.tr("library.trash_button"), role: .destructive) {
                if let g = viewModel.gameToDelete {
                    viewModel.deleteGameToTrash(g)
                }
            }
            Button(viewModel.tr("library.cancel"), role: .cancel) {}
        } message: {
            Text(viewModel.tr("library.trash_message"))
        }
    }
}
