import SwiftUI

struct LoginView: View {
    // Inputs
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false

    // State
    @State private var isBusy = false
    @State private var errorText: String?

    // Auth VM
    @StateObject private var auth = AuthViewModel()

    // Optional: call this after successful login to move to your app’s home screen
    var onLogin: (() -> Void)?

    var body: some View {
        NavigationStack {
            ZStack {
                // FULL-SCREEN BACKGROUND (same vibe as SignUp)
                LinearGradient(colors: [.black, .gray],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        Text("Welcome Back")
                            .font(.title.bold())
                            .foregroundStyle(.white)
                            .padding(.top, 32)

                        Text("Log in to continue")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        // Form
                        VStack(spacing: 12) {
                            customField(icon: "envelope",
                                        placeholder: "Email or username",
                                        text: $email,
                                        keyboardType: .emailAddress)

                            secureField(icon: "lock",
                                        placeholder: "Password",
                                        text: $password,
                                        show: $showPassword)
                        }
                        .padding(.horizontal)

                        // Forgot password (USchedule handles reset on web)
                        HStack {
                            Spacer()
                            Button {
                                errorText = "Password reset is handled on the USchedule website for this account."
                            } label: {
                                Text("Forgot password?")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.95))
                                    .underline()
                            }
                        }
                        .padding(.horizontal)

                        // Login button
                        Button {
                            Task { await signIn() }
                        } label: {
                            Group {
                                if isBusy { ProgressView() }
                                else { Text("Log In").font(.body.weight(.semibold)) }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.black.opacity(0.9))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isBusy)
                        .padding(.horizontal)

                        // Optional: Staff/No-password flow via Impersonate
                        Button {
                            Task { await impersonate() }
                        } label: {
                            Text("Impersonate (staff)")
                                .font(.footnote.weight(.semibold))
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(Color.white.opacity(0.2))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .disabled(isBusy)
                        .padding(.horizontal)

                        if let errorText {
                            Text(errorText)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        // Divider
                        HStack {
                            Rectangle().frame(height: 1).foregroundStyle(.white.opacity(0.5))
                            Text("OR CONTINUE WITH")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                            Rectangle().frame(height: 1).foregroundStyle(.white.opacity(0.5))
                        }
                        .padding(.horizontal)

                        // Social placeholders
                        HStack(spacing: 14) {
                            socialButton(image: "globe", label: "Google")
                            socialButton(image: "f.circle", label: "Facebook")
                        }
                        .padding(.horizontal)

                        Spacer(minLength: 24)
                    }
                    .frame(maxWidth: 560)
                    .padding(.bottom, 8)
                    .padding(.vertical, 24)
                    .background(Color.black.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(radius: 8)
                    .padding(.horizontal, 18)
                }
                .ignoresSafeArea(.keyboard)
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: auth.token) { _, tok in
                // If token exists, consider the user logged in
                if tok != nil { onLogin?() }
            }
        }
    }

    // MARK: - Actions

    /// Standard username/email + password login (USchedule ValidateUser)
    private func signIn() async {
        let e = normalizedEmailOrUsername
        guard !e.isEmpty, !password.isEmpty else {
            errorText = "Please enter email/username and password."
            return
        }
        isBusy = true; errorText = nil
        do {
            try await auth.login(username: e, password: password)
            isBusy = false
            onLogin?()
        } catch let err as USError {
            isBusy = false
            switch err {
            case .http(let code, _):
                errorText = (code == 401) ? "Email/username or password is incorrect." : err.localizedDescription
            default:
                errorText = err.localizedDescription
            }
        } catch {
            isBusy = false
            errorText = error.localizedDescription
        }
    }

    /// Optional: Impersonate by username (no password). Great for front-desk flow.
    private func impersonate() async {
        let e = normalizedEmailOrUsername
        guard !e.isEmpty else {
            errorText = "Enter the customer’s username/email to impersonate."
            return
        }
        isBusy = true; errorText = nil
        do {
            try await auth.impersonate(username: e)
            isBusy = false
            onLogin?()
        } catch let err as USError {
            isBusy = false
            switch err {
            case .http(let code, _):
                errorText = (code == 404 || code == 400) ? "No user found for that identifier." : err.localizedDescription
            default:
                errorText = err.localizedDescription
            }
        } catch {
            isBusy = false
            errorText = error.localizedDescription
        }
    }

    // MARK: - UI helpers

    private func customField(icon: String,
                             placeholder: String,
                             text: Binding<String>,
                             keyboardType: UIKeyboardType = .default) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.gray)
                .font(.body)
            TextField(placeholder, text: text)
                .font(.body)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(13)
        .background(Color.white.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func secureField(icon: String,
                             placeholder: String,
                             text: Binding<String>,
                             show: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.gray)
                .font(.body)
            if show.wrappedValue {
                TextField(placeholder, text: text)
                    .font(.body)
                    .textInputAutocapitalization(.never)
            } else {
                SecureField(placeholder, text: text)
                    .font(.body)
                    .textInputAutocapitalization(.never)
            }
            Button { show.wrappedValue.toggle() } label: {
                Image(systemName: show.wrappedValue ? "eye.slash" : "eye")
                    .foregroundStyle(.gray)
                    .font(.body)
            }
        }
        .padding(13)
        .background(Color.white.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func socialButton(image: String, label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: image).font(.body)
            Text(label).font(.body.weight(.medium))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .background(Color.white.opacity(0.95))
        .foregroundStyle(.black)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var normalizedEmailOrUsername: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview { LoginView() }
