import SwiftUI

struct RootView: View {
    @State private var isAuthenticated = false

    var body: some View {
        Group {
            if isAuthenticated {
                MainTabView()
            } else {
                LoginView(isAuthenticated: $isAuthenticated)
            }
        }
    }
}
