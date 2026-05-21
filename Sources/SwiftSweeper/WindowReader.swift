import AppKit
import SwiftUI

/// Calls `onChange(window)` whenever the underlying NSWindow becomes
/// available or changes. Used by ContentView to publish the main window to
/// ClickDispatcher (so events from sheets/popovers aren't intercepted).
struct WindowReader<Content: View>: View {
    @State private var window: NSWindow?
    let content: (NSWindow?) -> Content
    let onChange: (NSWindow?) -> Void

    init(onChange: @escaping (NSWindow?) -> Void,
         @ViewBuilder content: @escaping (NSWindow?) -> Content) {
        self.onChange = onChange
        self.content = content
    }

    var body: some View {
        content(window)
            .background(WindowAccessor(window: $window))
            .onChange(of: window) { _, new in onChange(new) }
            .onAppear { onChange(window) }
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
