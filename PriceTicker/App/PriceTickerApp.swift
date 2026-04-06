import SwiftUI

@main
struct PriceTickerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No main window — purely status bar + floating panels
        Settings {
            EmptyView()
        }
    }
}
