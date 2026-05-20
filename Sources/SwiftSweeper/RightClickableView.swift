import AppKit
import SwiftUI

struct RightClickableView<Content: View>: NSViewRepresentable {
    var content: Content
    var onLeftClick: () -> Void
    var onRightClick: () -> Void

    func makeNSView(context: Context) -> RightClickHostingView<Content> {
        let host = RightClickHostingView(rootView: content)
        host.onLeftClick = onLeftClick
        host.onRightClick = onRightClick
        return host
    }

    func updateNSView(_ nsView: RightClickHostingView<Content>, context: Context) {
        nsView.rootView = content
        nsView.onLeftClick = onLeftClick
        nsView.onRightClick = onRightClick
    }
}

final class RightClickHostingView<Content: View>: NSHostingView<Content> {
    var onLeftClick: (() -> Void)?
    var onRightClick: (() -> Void)?

    // Refuse to claim hits outside our own bounds. SwiftUI's internal subviews
    // (especially under Liquid Glass) can extend past the parent's frame and
    // intercept events meant for neighboring cells.
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = self.convert(point, from: self.superview)
        guard self.bounds.contains(local) else { return nil }
        return super.hitTest(point)
    }

    // Second line of defense: even if a click is somehow delivered to us
    // despite hitTest returning nil for that location, drop it.
    override func mouseDown(with event: NSEvent) {
        let p = self.convert(event.locationInWindow, from: nil)
        guard self.bounds.contains(p) else {
            nextResponder?.mouseDown(with: event)
            return
        }
        onLeftClick?()
        super.mouseDown(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        let p = self.convert(event.locationInWindow, from: nil)
        guard self.bounds.contains(p) else {
            nextResponder?.rightMouseDown(with: event)
            return
        }
        onRightClick?()
        // Intentionally skip super.rightMouseDown to suppress the default
        // context menu.
    }
}
