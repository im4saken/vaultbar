import SwiftUI

@main
struct VaultBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Key") {
                    appDelegate.showAddKey()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}
