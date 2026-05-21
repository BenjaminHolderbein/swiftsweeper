import SwiftSweeperKit
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
        NSEvent.addLocalMonitorForEvents(matching: [
            .leftMouseDown, .rightMouseDown, .leftMouseUp, .rightMouseUp,
        ]) { event in
            let handled = MainActor.assumeIsolated { ClickDispatcher.shared.handle(event) }
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
        .commands {
            CommandMenu("Game") {
                Button("New Game") {
                    ClickDispatcher.shared.viewModel?.resetGame()
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("Easy") {
                    ClickDispatcher.shared.viewModel?.setDifficulty(.easy)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Medium") {
                    ClickDispatcher.shared.viewModel?.setDifficulty(.medium)
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Hard") {
                    ClickDispatcher.shared.viewModel?.setDifficulty(.hard)
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("Custom…") {
                    NotificationCenter.default.post(name: .showCustomBoard, object: nil)
                }
                .keyboardShortcut("0", modifiers: .command)

                Divider()

                Button("Toggle Mute") {
                    let key = "muted"
                    UserDefaults.standard.set(!UserDefaults.standard.bool(forKey: key),
                                              forKey: key)
                }
                .keyboardShortcut("m", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let showCustomBoard = Notification.Name("SwiftSweeper.showCustomBoard")
}
