import SwiftUI
import WebKit

// MARK: - SignUpView

struct SignUpView: View {
    @Binding var isAuthenticated: Bool
    @Binding var authToken: String?

    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var navigationTitle = "Create Account"
    @State private var showWaiverCompletedAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                SignUpWebView(
                    authToken: authToken,
                    isLoading: $isLoading,
                    onTitleChange: { title in
                        navigationTitle = title
                    },
                    onWaiverSigned: {
                        showWaiverCompletedAlert = true
                    }
                )
                .ignoresSafeArea(edges: .bottom)

                if isLoading {
                    ProgressView("Loading...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 4)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Hide Close button once on the waiver — user must complete it
                if navigationTitle != "Sign Waiver" {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Close") {
                            dismiss()
                        }
                    }
                }
            }
            .alert("Account Created!", isPresented: $showWaiverCompletedAlert) {
                Button("Log In") {
                    dismiss() // Dismisses SignUpView, returning to LoginView
                }
            } message: {
                Text("Your account and waiver are complete. Please log in to continue.")
            }
        }
    }
}

// MARK: - SignUpWebView

struct SignUpWebView: UIViewRepresentable {
    let authToken: String?
    @Binding var isLoading: Bool
    var onTitleChange: (String) -> Void
    var onWaiverSigned: () -> Void

    private let registerURL = "https://clients.uschedule.com/loftgolfstudios/Account/Register"
    private static let sharedProcessPool = WKProcessPool()

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.processPool = Self.sharedProcessPool
        config.websiteDataStore = .nonPersistent()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator

        if let url = URL(string: registerURL) {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: SignUpWebView
        var redirectAfterLogin: URL?

        private var hasVisitedRegisterPage = false
        private var isOnWaiverPage = false

        init(_ parent: SignUpWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async { self.parent.isLoading = true }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async { self.parent.isLoading = false }

            guard let currentURL = webView.url?.absoluteString.lowercased() else { return }
            print("SignUp current URL:", currentURL)

            // Step 1: After remotelogin, go to register
            if currentURL.contains("remotelogin"), let nextURL = redirectAfterLogin {
                redirectAfterLogin = nil
                webView.load(URLRequest(url: nextURL))
                return
            }

            // Step 2: On the register page
            if currentURL.contains("/account/register") {
                hasVisitedRegisterPage = true
                DispatchQueue.main.async {
                    self.parent.onTitleChange("Create Account")
                }
                return
            }

            // Step 3: USchedule auto-redirects to waiver after sign-up
            if currentURL.contains("/booking/form/2447") {
                isOnWaiverPage = true
                DispatchQueue.main.async {
                    self.parent.onTitleChange("Sign Waiver")
                }
                return
            }

            // Step 4: Waiver submitted — USchedule redirects away from the form
            if isOnWaiverPage {
                DispatchQueue.main.async {
                    self.parent.onWaiverSigned()
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.parent.isLoading = false }
            print("Navigation failed:", error.localizedDescription)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.parent.isLoading = false }
            print("Provisional navigation failed:", error.localizedDescription)
        }
    }
}

// MARK: - Previews

#Preview {
    SignUpView(
        isAuthenticated: .constant(false),
        authToken: .constant(nil)
    )
}
