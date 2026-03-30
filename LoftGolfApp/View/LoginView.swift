import SwiftUI

struct LoginView: View {
    
    // App-level
    @Binding var isAuthenticated: Bool
    @Binding var authToken: String?

    // Inputs
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    

    // UI state
    @State private var isBusy = false
    @State private var errorText: String?
    @State private var rememberMe = false
    @State private var enableBiometric = false

    // ➕ Sign Up presentation
    @State private var showSignUp = false
    @State private var showForgotPasscode = false

    @AppStorage("biometricEnabled") private var biometricEnabled = false
    @StateObject private var auth = AuthViewModel()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color.black,
                    Color.black,
                    Color.black,
                    Color.black,
                    Color(.systemGray6).opacity(0.25),
                    Color.white
                ],
                startPoint: .top,
                endPoint: .bottom
            )                .ignoresSafeArea()

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

                    // Remember Me + Face ID + Forgot password
                    VStack(spacing: 8) {
                        HStack {
                            Toggle(isOn: $rememberMe) {
                                Text("Remember Me")
                                    .font(.footnote)
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            .tint(.green)
                            .fixedSize()
                            .onChange(of: rememberMe) { _, on in
                                if !on { enableBiometric = false }
                            }

                            Spacer()

                            Button {
                                showForgotPasscode = true
                            } label: {
                                Text("Forgot password?")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.95))
                                    .underline()
                            }
                        }

                        if rememberMe, BiometricHelper.isAvailable,
                           let biometricName = BiometricHelper.biometricType {
                            HStack {
                                Image(systemName: biometricName == "Face ID" ? "faceid" : "touchid")
                                    .foregroundStyle(.white.opacity(0.7))
                                    .font(.footnote)
                                Toggle(isOn: $enableBiometric) {
                                    Text("Enable \(biometricName)")
                                        .font(.footnote)
                                        .foregroundStyle(.white.opacity(0.9))
                                }
                                .tint(.green)
                                .fixedSize()
                                Spacer()
                            }
                            .padding(.leading, 8)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: rememberMe)
                    .padding(.horizontal)

                    // Log In
                    Button {
                        Task { await signInFlow() }
                    } label: {
                        Group {
                            if isBusy { ProgressView() }
                            else { Text("Log In").font(.body.weight(.semibold)) .foregroundStyle(.white)}
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color(.systemGray6).opacity(0.15))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.gray.opacity(0.9), lineWidth: 1)
                        )
                    }
                    .disabled(isBusy)
                    .padding(.horizontal)

                    if let errorText {
                        Text(errorText)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Biometric login button (shown only when credentials are saved)
                    if biometricEnabled, let biometricName = BiometricHelper.biometricType {
                        Button {
                            Task { await biometricFlow() }
                        } label: {
                            Label(
                                "Sign in with \(biometricName)",
                                systemImage: biometricName == "Face ID" ? "faceid" : "touchid"
                            )
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color(.systemGray6).opacity(0.15))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.gray.opacity(0.9), lineWidth: 1)
                            )
                        }
                        .disabled(isBusy)
                        .padding(.horizontal)
                    }

                    // Divider
                    HStack {
                        Rectangle().frame(height: 1).foregroundStyle(.white.opacity(0.5))
                        Text("OR")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                        Rectangle().frame(height: 1).foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.horizontal)

                    Button {
                        showSignUp = true
                    } label: {
                        Text("Don’t have an account? Create one")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6).opacity(0.15))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.gray.opacity(0.9), lineWidth: 1)
                            )
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
            .onAppear {
                if let saved = KeychainHelper.readString(key: "loft.savedUsername") {
                    email = saved
                    rememberMe = true
                    enableBiometric = biometricEnabled
                }
            }
            .sheet(isPresented: $showForgotPasscode) {
                NavigationStack {
                    WebView(url: URL(string: "https://clients.uschedule.com/loftgolfstudios/Account/PasswordReminder")!)
                        .navigationTitle("Password reset")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showForgotPasscode = false
                                }
                            }
                        }
                }
            }
        }
        // ➕ Full-screen Sign Up (your existing screen)
        .fullScreenCover(isPresented: $showSignUp) {
            SignUpView(
                isAuthenticated: $isAuthenticated,
                authToken: .constant(nil)
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Flows

    private func signInFlow() async {
        let e = normalizedEmailOrUsername
        guard !e.isEmpty, !password.isEmpty else {
            await MainActor.run { errorText = "Please enter email/username and password." }
            return
        }
        await MainActor.run { isBusy = true; errorText = nil }
        do {
            try await auth.login(username: e, password: password)
            await MainActor.run {
                isBusy = false
                if rememberMe {
                    KeychainHelper.saveString(e, key: "loft.savedUsername")
                    KeychainHelper.saveString(password, key: "loft.savedPassword")
                    biometricEnabled = enableBiometric
                } else {
                    KeychainHelper.delete(key: "loft.savedUsername")
                    KeychainHelper.delete(key: "loft.savedPassword")
                    biometricEnabled = false
                }
                authToken = auth.token
                isAuthenticated = true
            }
        } catch let err as USError {
            await MainActor.run {
                isBusy = false
                switch err {
                case .http(let code, _):
                    errorText = (code == 401) ? "Email/username or password is incorrect." : err.localizedDescription
                default:
                    errorText = err.localizedDescription
                }
            }
        } catch {
            await MainActor.run { isBusy = false; errorText = error.localizedDescription }
        }
    }

    private func impersonateFlow() async {
        let e = normalizedEmailOrUsername
        guard !e.isEmpty else {
            await MainActor.run { errorText = "Enter the customer’s username/email to impersonate." }
            return
        }
        await MainActor.run { isBusy = true; errorText = nil }
        do {
            try await auth.impersonate(username: e)
            await MainActor.run {
                isBusy = false
                isAuthenticated = true
            }
        } catch let err as USError {
            await MainActor.run {
                isBusy = false
                switch err {
                case .http(let code, _):
                    errorText = (code == 404 || code == 400) ? "No user found for that identifier." : err.localizedDescription
                default:
                    errorText = err.localizedDescription
                }
            }
        } catch {
            await MainActor.run { isBusy = false; errorText = error.localizedDescription }
        }
    }

    private func biometricFlow() async {
        let ok = await BiometricHelper.authenticate(reason: "Log in to Loft Golf")
        guard ok,
              let savedUser = KeychainHelper.readString(key: "loft.savedUsername"),
              let savedPass = KeychainHelper.readString(key: "loft.savedPassword")
        else { return }

        await MainActor.run {
            email = savedUser
            password = savedPass
            rememberMe = true
        }
        await signInFlow()
    }

    // MARK: - UI helpers

    private func customField(icon: String,
                             placeholder: String,
                             text: Binding<String>,
                             keyboardType: UIKeyboardType = .default) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(.gray).font(.body)
            TextField(placeholder, text: text)
                .font(.body)
                .foregroundStyle(.black)
                .tint(.black)
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
            Image(systemName: icon).foregroundStyle(.gray).font(.body)
            if show.wrappedValue {
                TextField(placeholder, text: text)
                    .font(.body)
                    .foregroundStyle(.black)
                    .tint(.black)
                    .textInputAutocapitalization(.never)
            } else {
                SecureField(placeholder, text: text)
                    .font(.body)
                    .foregroundStyle(.black)
                    .tint(.black)
                    .textInputAutocapitalization(.never)
            }
            Button { show.wrappedValue.toggle() } label: {
                Image(systemName: show.wrappedValue ? "eye.slash" : "eye").foregroundStyle(.gray).font(.body)
            }
        }
        .padding(13)
        .background(Color.white.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var normalizedEmailOrUsername: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
