import AppKit
import SwiftSweeperKit

/// Centralized click dispatcher. ContentView publishes the grid's frame and
/// the App-level NSEvent monitor calls `dispatch(_:)`. We look up the cell
/// at the click coordinate and call the view model directly.
///
/// Why this exists: under Liquid Glass + rapid trackpad clicks across
/// button types, `event.clickCount` accumulates and AppKit silently drops
/// the events before they reach our NSHostingView's `mouseDown` override.
/// Bypassing per-cell event delivery entirely sidesteps the problem.
@MainActor
final class ClickDispatcher {
    static let shared = ClickDispatcher()

    /// Grid frame as reported by SwiftUI's `.global` coordinate space —
    /// on macOS this is window-relative coords with TOP-LEFT origin.
    var gridFrameInWindowTL: CGRect = .zero
    var cellSize: CGFloat = 28
    var cellSpacing: CGFloat = 2
    var rows: Int = 9
    var cols: Int = 9
    weak var viewModel: GameViewModel?

    @discardableResult
    func dispatch(_ event: NSEvent) -> Bool {
        guard let vm = viewModel, let window = event.window,
              gridFrameInWindowTL.width > 0 else { return false }
        // Don't capture clicks while the game-over card is showing — it
        // overlays the grid and its buttons need to receive their own clicks.
        guard vm.gameState == .playing else { return false }

        // event.locationInWindow is in AppKit window coords (bottom-left).
        // SwiftUI's .global frame on macOS is window-relative top-left.
        // Convert by flipping y against the window frame height.
        let pBL = event.locationInWindow
        let pTL = CGPoint(x: pBL.x, y: window.frame.height - pBL.y)

        guard gridFrameInWindowTL.contains(pTL) else { return false }

        let xInGrid = pTL.x - gridFrameInWindowTL.minX
        let yInGrid = pTL.y - gridFrameInWindowTL.minY
        let stride = cellSize + cellSpacing
        let col = Int(xInGrid / stride)
        let row = Int(yInGrid / stride)
        guard row >= 0, row < rows, col >= 0, col < cols else { return false }
        let xInCell = xInGrid - CGFloat(col) * stride
        let yInCell = yInGrid - CGFloat(row) * stride
        guard xInCell <= cellSize, yInCell <= cellSize else { return false }

        switch event.type {
        case .leftMouseUp:  vm.cellTapped(row: row, col: col);  return true
        case .rightMouseUp: vm.cellFlagged(row: row, col: col); return true
        default: return false
        }
    }
}
