import SwiftUI

struct SignUpView: View {
    @StateObject private var auth = AuthViewModel()

    enum Route: Hashable { case home }

    @State private var path: [Route] = []

    // --- Sign Up fields
    @State private var firstName = ""
    @State private var lastName  = ""
    @State private var email     = ""
    @State private var phone     = ""
    @State private var username  = ""
    @State private var password  = ""
    @State private var confirmPassword = ""
    @State private var birthday  = Date()
    @State private var smsOptIn  = false
    @State private var showPassword = false
    @State private var showConfirmPassword = false

    // UI state
    @State private var isBusy = false
    @State private var errorText: String?

    // Waiver sheet
    @State private var showWaiverSheet = false

    // For returning to Login (when SignUpView is presented modally)
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .top) {
                Color(red: 0.10, green: 0.11, blue: 0.14).ignoresSafeArea()
                LinearGradient(colors: [Color.white.opacity(0.06), .clear],
                               startPoint: .top, endPoint: .center)
                    .frame(height: 180)
                    .allowsHitTesting(false)

                ScrollView {
                    VStack(spacing: 16) {
                        // Header
                        VStack(spacing: 6) {
                            Text("Create Your Account")
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .foregroundStyle(.white)
                            Text("Fill in your details to get started.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        .padding(.top, 16)

                        // Card
                        VStack(spacing: 14) {
                            signUpForm

                            if let errorText {
                                ErrorBanner(text: errorText)
                            }

                            PrimaryButton(title: isBusy ? nil : "Create Account", isLoading: isBusy) {
                                Task { await handleSignUp() }
                            }

                            // Return to Login
                            Button {
                                dismiss()  // closes SignUpView if shown as a sheet/fullScreenCover
                            } label: {
                                Text("Already have an account? Log in")
                                    .font(.footnote.weight(.medium))
                                    .underline()
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            .padding(.top, 4)
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.06)))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.12)))
                        .shadow(color: .black.opacity(0.25), radius: 10, y: 6)
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)

            .navigationDestination(for: Route.self) { route in
                switch route {
                case .home:
                    MainTabView()
                        .navigationBarBackButtonHidden(true)
                }
            }

            .sheet(isPresented: $showWaiverSheet, onDismiss: {
                // After waiver, go home
                path = [.home]
            }) {
                WaiverView()
            }

            // Clear field-specific errors when user edits
            .onChange(of: username) { _ in
                if errorText?.localizedCaseInsensitiveContains("username") == true { errorText = nil }
            }
            .onChange(of: email) { _ in
                if errorText?.localizedCaseInsensitiveContains("email") == true { errorText = nil }
            }
            .onChange(of: phone) { _ in
                if errorText?.localizedCaseInsensitiveContains("phone") == true { errorText = nil }
            }
        }
    }

    // MARK: - Form
    private var signUpForm: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                FieldRow(icon: "person", label: "First name *") {
                    TextField("Jane", text: $firstName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }
                FieldRow(icon: "person", label: "Last name *") {
                    TextField("Doe", text: $lastName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }
            }

            FieldRow(icon: "envelope", label: "Email *") {
                TextField("name@example.com", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            FieldRow(icon: "phone", label: "Cell phone") {
                TextField("(555) 123-4567", text: $phone)
                    .keyboardType(.phonePad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Toggle(isOn: $smsOptIn) {
                Text("Receive SMS updates (msg & data rates may apply)")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .tint(.white.opacity(0.9))

            FieldRow(icon: "at", label: "Username *") {
                TextField("your_username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            FieldRow(icon: "lock", label: "Password *", trailing: {
                Button { showPassword.toggle() } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
            }) {
                Group {
                    if showPassword { TextField("••••••••", text: $password) }
                    else { SecureField("••••••••", text: $password) }
                }
                .textInputAutocapitalization(.never)
            }

            FieldRow(icon: "lock.shield", label: "Confirm password *", trailing: {
                Button { showConfirmPassword.toggle() } label: {
                    Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
            }) {
                Group {
                    if showConfirmPassword { TextField("••••••••", text: $confirmPassword) }
                    else { SecureField("••••••••", text: $confirmPassword) }
                }
                .textInputAutocapitalization(.never)
            }

            FieldRow(icon: "calendar", label: "Birthday *") {
                DatePicker("Select date", selection: $birthday, displayedComponents: .date)
                    .labelsHidden()
            }
        }
    }

    // MARK: - Actions
    private func handleSignUp() async {
        guard !firstName.isEmpty,
              !lastName.isEmpty,
              !email.isEmpty,
              !username.isEmpty,
              !password.isEmpty,
              !confirmPassword.isEmpty else {
            errorText = "Please fill in all required fields (*)."
            return
        }
        guard password == confirmPassword else {
            errorText = "Passwords do not match."
            return
        }

        isBusy = true
        errorText = nil

        do {
            try await auth.register(
                fullName: "\(firstName) \(lastName)",
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                phone: phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : phone,
                userName: username.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            isBusy = false
            showWaiverSheet = true
        } catch let err as USAuthError {
            isBusy = false

            let bodyLower: String
            switch err {
            case .http(_, let sample):
                bodyLower = sample.lowercased()
            default:
                bodyLower = err.localizedDescription.lowercased()
            }

            var parts: [String] = []
            if bodyLower.contains("username") && (bodyLower.contains("exist") || bodyLower.contains("taken")) {
                username = ""
                parts.append("That username is already taken.")
            }
            if bodyLower.contains("email") && (bodyLower.contains("exist") || bodyLower.contains("already")) {
                email = ""
                parts.append("That email is already in use.")
            }
            if bodyLower.contains("phone") && (bodyLower.contains("exist") || bodyLower.contains("already")) {
                phone = ""
                parts.append("That phone number is already in use.")
            }

            errorText = parts.isEmpty
                ? "We couldn’t create your account. Please check your details and try again."
                : parts.joined(separator: " ")
        } catch {
            isBusy = false
            errorText = error.localizedDescription
        }
    }
}

// MARK: - Reusable UI (unchanged from your file)
private struct FieldRow<Content: View, Trailing: View>: View {
    let icon: String
    let label: String
    @ViewBuilder let content: Content
    @ViewBuilder let trailing: Trailing

    init(icon: String, label: String,
         @ViewBuilder trailing: () -> Trailing,
         @ViewBuilder content: () -> Content) {
        self.icon = icon; self.label = label
        self.trailing = trailing(); self.content = content()
    }

    init(icon: String, label: String,
         @ViewBuilder content: () -> Content) where Trailing == EmptyView {
        self.icon = icon; self.label = label
        self.trailing = EmptyView(); self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .foregroundStyle(.white.opacity(0.95))
                .font(.footnote.weight(.semibold))
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 22)
                content.foregroundStyle(.white)
                trailing
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.15)))
        }
    }
}

private struct PrimaryButton: View {
    var title: String?
    var isLoading: Bool
    var action: () -> Void

    init(title: String?, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title; self.isLoading = isLoading; self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading { ProgressView().tint(.black) }
                else if let title { Text(title).font(.body.weight(.semibold)).foregroundStyle(.black) }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 12).fill(.white))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.25)))
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        }
        .disabled(isLoading)
    }
}

private struct ErrorBanner: View {
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
            Text(text).foregroundStyle(.white).font(.footnote)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.55)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.2)))
    }
}

#Preview { SignUpView() }
