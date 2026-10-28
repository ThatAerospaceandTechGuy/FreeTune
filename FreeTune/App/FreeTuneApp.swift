import SwiftUI

@main
@MainActor
struct FreeTuneApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(model.library)
                .environmentObject(model.player)
                .environmentObject(model.downloads)
                .environmentObject(model.settings)
                .tint(.ftPrimary)
        }
    }
}
