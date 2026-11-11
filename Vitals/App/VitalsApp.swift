import SwiftUI

@main
struct VitalsApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environment(appDelegate.appState)
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // `--promo <dir>` renders the marketing screenshots and quits; no
        // monitoring, no status item.
        if Promo.isActive {
            Promo.run(appState: appState)
            return
        }
        appState.startMonitoring()
        statusBarController = StatusBarController(appState: appState)
    }
}
