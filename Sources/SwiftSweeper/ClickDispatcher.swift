import AppKit
import SwiftSweeperKit

/// Centralized click dispatcher. ContentView publishes the grid's frame and
/// the App-level NSEvent monitor calls `handle(_:)`. We compute which cell
/// the click hit and call the view model directly.
///
/// Why this exists: under Liquid Glass + rapid trackpad clicks across
/// button types, `event.clickCount` accumulates and AppKit silently drops
/// events before they reach NSHostingView's `mouseDown` override.
/// Bypassing per-cell event delivery sidesteps the problem.
///
/// Tap and flag fire on mouseUp (drag-off-grid cancels). Chord fires on
/// the second mouseDown when both buttons are held simultaneously.
@MainActor
final class ClickDispatcher {
    static let shared = ClickDispatcher()

    var gridFrameInWindowTL: CGRect = .zero
    var cellSize: CGFloat = 28
    var cellSpacing: CGFloat = 2
    var rows: Int = 9
    var cols: Int = 9
    weak var viewModel: GameViewModel?

    private var leftDown = false
    private var rightDown = false
    private var chordFired = false

    @discardableResult
    func handle(_ event: NSEvent) -> Bool {
        // State bookkeeping runs unconditionally so we never leak button-down
        // bools across games (e.g. after a chord-induced game over, the
        // mouseUp would otherwise be dropped and the next game would think
        // the button is still held — phantom-chording the first click).
        let priorChord = chordFired
        switch event.type {
        case .leftMouseDown:  leftDown = true
        case .rightMouseDown: rightDown = true
        case .leftMouseUp:    leftDown = false
        case .rightMouseUp:   rightDown = false
        default: break
        }
        if !leftDown && !rightDown { chordFired = false }

        guard let vm = viewModel, let _ = event.window,
              gridFrameInWindowTL.width > 0,
              vm.gameState == .playing else { return false }

        switch event.type {
        case .leftMouseDown:
            if rightDown { return fireChord(for: event, vm: vm) }
            return true  // consume; defer normal tap to mouseUp

        case .rightMouseDown:
            if leftDown { return fireChord(for: event, vm: vm) }
            return true  // consume; defer normal flag to mouseUp

        case .leftMouseUp:
            if priorChord { return true }
            return fire(.leftMouseUp, event: event, vm: vm)

        case .rightMouseUp:
            if priorChord { return true }
            return fire(.rightMouseUp, event: event, vm: vm)

        default:
            return false
        }
    }

    private func fire(_ kind: NSEvent.EventType, event: NSEvent, vm: GameViewModel) -> Bool {
        guard let (row, col) = cell(at: event) else { return false }
        switch kind {
        case .leftMouseUp:  vm.cellTapped(row: row, col: col)
        case .rightMouseUp: vm.cellFlagged(row: row, col: col)
        default: return false
        }
        return true
    }

    private func fireChord(for event: NSEvent, vm: GameViewModel) -> Bool {
        chordFired = true
        guard let (row, col) = cell(at: event) else { return true }
        vm.chord(row: row, col: col)
        return true
    }

    /// Returns the (row, col) of the cell under the event's window-coord
    /// position, or nil if outside the grid.
    private func cell(at event: NSEvent) -> (Int, Int)? {
        guard let window = event.window else { return nil }
        let pBL = event.locationInWindow
        let pTL = CGPoint(x: pBL.x, y: window.frame.height - pBL.y)
        guard gridFrameInWindowTL.contains(pTL) else { return nil }
        let xInGrid = pTL.x - gridFrameInWindowTL.minX
        let yInGrid = pTL.y - gridFrameInWindowTL.minY
        let stride = cellSize + cellSpacing
        let col = Int(xInGrid / stride)
        let row = Int(yInGrid / stride)
        guard row >= 0, row < rows, col >= 0, col < cols else { return nil }
        let xInCell = xInGrid - CGFloat(col) * stride
        let yInCell = yInGrid - CGFloat(row) * stride
        guard xInCell <= cellSize, yInCell <= cellSize else { return nil }
        return (row, col)
    }
}
