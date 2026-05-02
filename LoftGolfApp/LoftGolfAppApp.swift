import SwiftUI

@main
struct LoftGolfApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var notificationManager = NotificationManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(notificationManager)
                .task {
                    await notificationManager.checkPermissionStatus()
                }
        }
    }
}
