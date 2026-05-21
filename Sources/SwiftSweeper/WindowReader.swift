import AppKit
import SwiftUI

/// Resolves the NSWindow a SwiftUI view is hosted in and passes it to the
/// content closure. Used by ContentView to publish the main window to
/// ClickDispatcher so events from sheets/popovers aren't intercepted.
struct WindowReader<Content: View>: View {
    @State private var window: NSWindow?
    let content: (NSWindow?) -> Content

    init(@ViewBuilder content: @escaping (NSWindow?) -> Content) {
        self.content = content
    }

    var body: some View {
        content(window)
            .background(WindowAccessor(window: $window))
    }
}

private struct WindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { self.window = view.window }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if self.window !== nsView.window { self.window = nsView.window }
        }
    }
}
