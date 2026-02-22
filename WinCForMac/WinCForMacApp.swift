import SwiftUI

// MARK: - App Entry Point

@main
struct WinCForMacApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar only app — no window group needed.
        // The Settings scene provides the standard "Preferences" menu item.
        Settings {
            EmptyView()
        }
    }
}
