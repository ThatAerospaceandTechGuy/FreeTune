import UIKit

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Touching the shared model creates the background download session and
        // wires its callbacks before iOS delivers relaunch events.
        _ = AppModel.shared
        _ = BackgroundDownloadService.shared
        return true
    }

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        guard identifier == BackgroundDownloadService.identifier else {
            completionHandler()
            return
        }
        BackgroundSessionCompletion.shared.store(completionHandler)
        _ = AppModel.shared
        _ = BackgroundDownloadService.shared
    }
}
