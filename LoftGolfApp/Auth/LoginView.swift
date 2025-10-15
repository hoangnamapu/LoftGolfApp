import SwiftUI
import FirebaseAuth


struct LoginView: View {
    // Inputs
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    

    // State
    @State private var isBusy = false
    @State private var errorText: String?

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
                                        placeholder: "Enter your email",
                                        text: $email,
                                        keyboardType: .emailAddress)

                            secureField(icon: "lock",
                                        placeholder: "Enter your password",
                                        text: $password,
                                        show: $showPassword)
                        }
                        .padding(.horizontal)

                        // Forgot password
                        HStack {
                            Spacer()
                            Button(action: { Task { await sendResetEmail() } }) {
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
                    .frame(maxWidth: 560)                 // looks good on iPhone & iPad
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
        }
    }

    // MARK: - Actions

    private func signIn() async {
        let e = normalizedEmail
        guard !e.isEmpty, !password.isEmpty else {
            errorText = "Please enter email and password."
            return
        }

        isBusy = true
        errorText = nil

        do {
            _ = try await Auth.auth().signIn(withEmail: e, password: password)
            isBusy = false
            onLogin?()
        } catch let ns as NSError {
            isBusy = false
            // Handle common cases; show generic message when enumeration-safe
            switch ns.code {
            case AuthErrorCode.wrongPassword.rawValue:
                errorText = "Email or password is incorrect."
            case AuthErrorCode.userNotFound.rawValue:
                // Some projects won’t return this when enumeration protection is on.
                errorText = "Email or password is incorrect."
            case AuthErrorCode.invalidEmail.rawValue:
                errorText = "Invalid email address."
            case AuthErrorCode.operationNotAllowed.rawValue:
                errorText = "Email/Password sign-in is disabled in Firebase Console."
            case AuthErrorCode.tooManyRequests.rawValue:
                errorText = "Too many attempts. Please try again later."
            case AuthErrorCode.networkError.rawValue:
                errorText = "Network error. Check your internet connection."
            default:
                // Fallback: safe, non-enumerating message
                errorText = "Sign-in failed. Please check your email and password."
                print("🔥 Login error:", ns.domain, ns.code, ns.userInfo)
            }
        }
    }



    private func sendResetEmail() async {
        let e = normalizedEmail
        guard !e.isEmpty else {
            errorText = "Enter your email above, then tap “Forgot password?”"
            return
        }

        isBusy = true
        errorText = nil
        do {
            try await Auth.auth().sendPasswordReset(withEmail: e)
            isBusy = false
            // Generic confirmation to avoid revealing account existence
            errorText = "If an account exists for \(e), you’ll receive a reset email shortly."
        } catch let ns as NSError {
            isBusy = false
            switch ns.code {
            case AuthErrorCode.invalidEmail.rawValue:
                errorText = "Invalid email address."
            case AuthErrorCode.networkError.rawValue:
                errorText = "Network error. Try again."
            default:
                // Keep messaging generic for safety
                errorText = "If an account exists for \(e), you’ll receive a reset email shortly."
                print("🔁 Reset error:", ns.domain, ns.code, ns.userInfo)
            }
        }
    }


    // MARK: - UI helpers (kept minimal; matches your SignUp look)

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
    
    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }


}

#Preview {
    LoginView()
}
