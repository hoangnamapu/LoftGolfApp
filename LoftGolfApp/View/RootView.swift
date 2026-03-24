import SwiftUI

struct RootView: View {
    @State private var isAuthenticated = false
    @State private var authToken: String?
    @AppStorage("biometricEnabled") private var biometricEnabled = false

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
        .onAppear {
            guard biometricEnabled,
                  BiometricHelper.isAvailable,
                  KeychainHelper.readString(key: "loft.savedUsername") != nil
            else { return }
            Task { await attemptBiometricLogin() }
        }
    }

    private func attemptBiometricLogin() async {
        let ok = await BiometricHelper.authenticate(reason: "Log in to Loft Golf")
        guard ok,
              let user = KeychainHelper.readString(key: "loft.savedUsername"),
              let pass = KeychainHelper.readString(key: "loft.savedPassword")
        else { return }

        let auth = AuthViewModel()
        do {
            try await auth.login(username: user, password: pass)
            await MainActor.run {
                authToken = auth.token
                isAuthenticated = true
            }
        } catch {
            // Silent fail — user sees the login screen with email pre-filled
        }
    }
}

#Preview {
    RootView()
}
