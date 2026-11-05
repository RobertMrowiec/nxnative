import SwiftUI
import AppKit

/// Live reordering: swaps dragged card into hovered card's slot on the same shelf.
public struct GameReorderDropDelegate: DropDelegate {
    public let target: PortedGame
    public let viewModel: AppViewModel
    @Binding public var hoveredTargetGamePath: String?
    public let move: (PortedGame, PortedGame) -> Void

    public init(
        target: PortedGame,
        viewModel: AppViewModel,
        hoveredTargetGamePath: Binding<String?>,
        move: @escaping (PortedGame, PortedGame) -> Void
    ) {
        self.target = target
        self.viewModel = viewModel
        self._hoveredTargetGamePath = hoveredTargetGamePath
        self.move = move
    }

    public func dropEntered(info: DropInfo) {
        guard let dragged = viewModel.draggedGame,
              dragged.url.standardized.path != target.url.standardized.path else { return }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.80)) {
            move(dragged, target)
        }
        hoveredTargetGamePath = nil
    }

    public func dropUpdated(info: DropInfo) -> DropProposal? {
        guard viewModel.draggedGame != nil else {
            return DropProposal(operation: .forbidden)
        }
        return DropProposal(operation: .move)
    }

    public func dropExited(info: DropInfo) {
        if hoveredTargetGamePath == target.url.standardized.path {
            hoveredTargetGamePath = nil
        }
    }

    public func performDrop(info: DropInfo) -> Bool {
        hoveredTargetGamePath = nil
        viewModel.draggedGame = nil
        SoundEffectService.shared.play(.click)
        return true
    }
}
