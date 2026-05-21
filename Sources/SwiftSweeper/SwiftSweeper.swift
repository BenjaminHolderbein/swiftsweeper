import SwiftUI
import AppKit

fileprivate final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Capture every left/right mouseDown at the app level and route it
        // ourselves. Bypasses AppKit's per-cell NSHostingView delivery, which
        // is unreliable under Liquid Glass when `clickCount` accumulates
        // across button types (e.g. right-click cycle followed by left-click).
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp, .rightMouseUp]) { event in
            let handled = MainActor.assumeIsolated { ClickDispatcher.shared.dispatch(event) }
            return handled ? nil : event
        }
    }
}

@main
struct SwiftSweeper: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) fileprivate var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}
