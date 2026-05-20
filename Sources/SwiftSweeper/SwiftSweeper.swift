import SwiftUI
import AppKit

fileprivate final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
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
