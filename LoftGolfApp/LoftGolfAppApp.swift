import SwiftUI
import FirebaseCore

@main
struct LoftGolfApp: App {

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            SignUpView()
        }
    }
}
