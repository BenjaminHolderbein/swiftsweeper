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
    }
}

final class RightClickHostingView<Content: View>: NSHostingView<Content> {
    var onLeftClick: (() -> Void)?
    var onRightClick: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 1 { onLeftClick?() }
        super.mouseDown(with: event)
    }

    // Intentionally skip super to suppress the default context menu.
    override func rightMouseDown(with event: NSEvent) { onRightClick?() }
}
