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
    /// The NSWindow the grid lives in. Sheets/popovers have their own windows
    /// — events in those windows must not be intercepted by the dispatcher.
    weak var window: NSWindow?
    /// Fired on every mouseDown the dispatcher receives in the main window.
    /// ContentView uses this to hide the keyboard focus ring on mouse use.
    var onMouseUsed: (() -> Void)?

    private var leftDown = false
    private var rightDown = false
    private var chordFired = false

    @discardableResult
    func handle(_ event: NSEvent) -> Bool {
        // Capture chord state from before this event's bookkeeping.
        let priorChord = chordFired

        // Clear button-down flags on Ups unconditionally — even if the game
        // just ended (e.g. chord-induced game over), so state doesn't leak.
        if event.type == .leftMouseUp { leftDown = false }
        if event.type == .rightMouseUp { rightDown = false }
        if !leftDown && !rightDown { chordFired = false }

        // Signal mouse use on every left/right mouseDown in the main window,
        // regardless of game state — so the keyboard focus ring hides
        // immediately when the user reaches for the mouse.
        if event.window === window,
           event.type == .leftMouseDown || event.type == .rightMouseDown {
            onMouseUsed?()
        }

        guard let vm = viewModel,
              let eventWindow = event.window,
              eventWindow === window,
              gridFrameInWindowTL.width > 0,
              vm.gameState == .playing else { return false }

        let onGrid = cell(at: event) != nil

        switch event.type {
        case .leftMouseDown:
            // Pass through clicks that aren't on the grid so HUD buttons,
            // the difficulty menu, and the smiley reset all work.
            guard onGrid else { return false }
            leftDown = true
            if rightDown { return fireChord(for: event, vm: vm) }
            return true  // consume; defer normal tap to mouseUp

        case .rightMouseDown:
            guard onGrid else { return false }
            rightDown = true
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
