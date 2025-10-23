import SwiftUI

struct RootView: View {
    @State private var isAuthenticated = false
    @State private var authToken: String?

    var body: some View {
        Group {
            if isAuthenticated {
                MainTabView(
                    isAuthenticated: $isAuthenticated,
                    authToken: authToken
                )
            } else {
                LoginView(
                    isAuthenticated: $isAuthenticated,
                    authToken: $authToken
                )
            }
        }
    }
}

#Preview {
    RootView()
}
