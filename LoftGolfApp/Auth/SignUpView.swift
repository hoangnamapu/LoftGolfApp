import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SignUpView: View {
    @State private var selectedTab: Tab = .signUp
    @State private var isLoggedIn = false
    
    // --- Sign Up fields
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false

    // --- Login fields
    @State private var loginEmail = ""
    @State private var loginPassword = ""
    @State private var showLoginPassword = false

    // network state (shared for both flows)
    @State private var isBusy = false
    @State private var errorText: String?

    enum Tab { case login, signUp }

    // Size classes for adaptive layout
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.verticalSizeClass) private var vSizeClass

    var body: some View {
        NavigationStack {
            ZStack {
                // FULL-SCREEN BACKGROUND
                LinearGradient(colors: [.black, .gray],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                GeometryReader { proxy in
                    let safeArea = proxy.safeAreaInsets

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: spacing(for: proxy.size)) {
                            Text("Welcome")
                                .font(titleFont(for: proxy.size))
                                .foregroundStyle(.white)
                                .padding(.top, topHeaderPadding(for: proxy.size))

                            Text(selectedTab == .signUp
                                 ? "Create a new account to get started"
                                 : "Log in to continue")
                                .font(subtitleFont(for: proxy.size))
                                .foregroundStyle(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)

                            // Tabs
                            HStack(spacing: 0) {
                                tabButton(title: "Login", tab: .login, size: proxy.size)
                                tabButton(title: "Sign Up", tab: .signUp, size: proxy.size)
                            }
                            .background(Color.white.opacity(0.2))
                            .clipShape(Capsule())
                            .padding(.horizontal)

                            // ----- FORMS -----
                            if selectedTab == .signUp {
                                // Sign Up form
                                VStack(spacing: fieldSpacing(for: proxy.size)) {
                                    customField(icon: "person",  placeholder: "Enter your full name", text: $fullName, size: proxy.size)
                                    customField(icon: "envelope", placeholder: "Enter your email",     text: $email, keyboardType: .emailAddress, size: proxy.size)
                                    secureField(icon: "lock",     placeholder: "Create a password",    text: $password,        show: $showPassword,        size: proxy.size)
                                    secureField(icon: "lock",     placeholder: "Confirm your password",text: $confirmPassword, show: $showConfirmPassword, size: proxy.size)
                                }
                                .padding(.horizontal)

                                Button {
                                    Task { await signUp() }
                                } label: {
                                    Group {
                                        if isBusy { ProgressView() }
                                        else {
                                            Text("Create Account")
                                                .font(buttonFont(for: proxy.size))
                                                .fontWeight(.semibold)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, buttonPadding(for: proxy.size))
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

                                // Terms
                                VStack(spacing: 4) {
                                    Text("By creating an account, you agree to our")
                                        .font(captionFont(for: proxy.size))
                                        .foregroundStyle(.white.opacity(0.85))
                                    HStack(spacing: 4) {
                                        Text("Terms of Service").underline()
                                        Text("and")
                                        Text("Privacy Policy").underline()
                                    }
                                    .font(captionFont(for: proxy.size))
                                    .foregroundStyle(.white)
                                }
                                .multilineTextAlignment(.center)
                                .padding(.top, 4)
                                .padding(.horizontal)

                            } else {
                                // Login form
                                VStack(spacing: fieldSpacing(for: proxy.size)) {
                                    customField(icon: "envelope",
                                                placeholder: "Enter your email",
                                                text: $loginEmail,
                                                keyboardType: .emailAddress,
                                                size: proxy.size)

                                    secureField(icon: "lock",
                                                placeholder: "Enter your password",
                                                text: $loginPassword,
                                                show: $showLoginPassword,
                                                size: proxy.size)
                                }
                                .padding(.horizontal)

                                // Forgot password shortcut
                                HStack {
                                    Spacer()
                                    Button {
                                        Task { await sendResetEmail() }
                                    } label: {
                                        Text("Forgot password?")
                                            .font(captionFont(for: proxy.size).weight(.medium))
                                            .foregroundStyle(.white.opacity(0.95))
                                            .underline()
                                    }
                                }
                                .padding(.horizontal)

                                Button {
                                    Task { await signIn() }
                                } label: {
                                    Group {
                                        if isBusy { ProgressView() }
                                        else {
                                            Text("Log In")
                                                .font(buttonFont(for: proxy.size))
                                                .fontWeight(.semibold)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, buttonPadding(for: proxy.size))
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
                            }

                            // Divider + social (shared)
                            HStack {
                                Rectangle().frame(height: 1).foregroundStyle(.white.opacity(0.5))
                                Text("OR CONTINUE WITH")
                                    .font(captionFont(for: proxy.size))
                                    .foregroundStyle(.white.opacity(0.8))
                                Rectangle().frame(height: 1).foregroundStyle(.white.opacity(0.5))
                            }
                            .padding(.horizontal)

                            HStack(spacing: socialSpacing(for: proxy.size)) {
                                socialButton(image: "globe", label: "Google", size: proxy.size)
                                socialButton(image: "f.circle", label: "Facebook", size: proxy.size)
                            }
                            .padding(.horizontal)
                        }
                        // Make the card fill the full screen height
                        .frame(minHeight: proxy.size.height)
                        .frame(maxWidth: .infinity)
                        .frame(width: maxCardWidth(for: proxy.size))
                        .padding(.horizontal, edgePadding(for: proxy.size))
                        .padding(.bottom, safeArea.bottom + 8)
                        .background(Color.black.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius(for: proxy.size)))
                        .shadow(radius: shadowRadius(for: proxy.size))
                        .frame(maxHeight: .infinity, alignment: .center)
                    }
                    .ignoresSafeArea(.keyboard)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $isLoggedIn) {
                MainTabView()
                    .navigationBarBackButtonHidden(true)
            }
        }
    }

    // MARK: - Firebase: Sign Up
    private func signUp() async {
        guard !fullName.isEmpty, !email.isEmpty, !password.isEmpty else {
            errorText = "Please fill in all fields."; return
        }
        guard password == confirmPassword else {
            errorText = "Passwords do not match."; return
        }

        isBusy = true; errorText = nil
        do {
            let result = try await Auth.auth().createUser(withEmail: email.lowercased(), password: password)
            let uid = result.user.uid

            let db = Firestore.firestore()
            try await db.collection("users")
                .document(uid)
                .collection("profiles")
                .addDocument(data: [
                    "owner_id": uid,
                    "fullName": fullName,
                    "email": email.lowercased(),
                    "createdAt": FieldValue.serverTimestamp()
                ])

            isBusy = false
            fullName = ""; email = ""; password = ""; confirmPassword = ""
            selectedTab = .login   // go to login after successful sign up
        } catch {
            isBusy = false
            let ns = error as NSError
            print("🔥 SignUp error ->", ns.domain, ns.code, ns.userInfo)
            switch ns.code {
            case AuthErrorCode.operationNotAllowed.rawValue:
                errorText = "Email/Password sign-in is disabled in Firebase Console."
            case AuthErrorCode.invalidEmail.rawValue:
                errorText = "The email address is invalid."
            case AuthErrorCode.emailAlreadyInUse.rawValue:
                errorText = "That email is already in use."
            case AuthErrorCode.weakPassword.rawValue:
                errorText = "Password is too weak (min 6 chars)."
            case AuthErrorCode.networkError.rawValue:
                errorText = "Network error. Check your internet connection."
            default:
                errorText = ns.localizedDescription
            }
        }
    }

    // MARK: - Firebase: Login
    private func signIn() async {
        guard !loginEmail.isEmpty, !loginPassword.isEmpty else {
            errorText = "Please enter email and password."; return
        }
        isBusy = true; errorText = nil
        do {
            _ = try await Auth.auth().signIn(withEmail: loginEmail.lowercased(), password: loginPassword)
            isBusy = false
            isLoggedIn = true
            // TODO: navigate to your home screen from outside this view
        } catch {
            isBusy = false
            let ns = error as NSError
            print("🔥 Login error ->", ns.domain, ns.code, ns.userInfo)
            switch ns.code {
            case AuthErrorCode.invalidEmail.rawValue:   errorText = "Invalid email address."
            case AuthErrorCode.wrongPassword.rawValue:  errorText = "Incorrect password."
            case AuthErrorCode.userNotFound.rawValue:   errorText = "No account found with this email."
            case AuthErrorCode.networkError.rawValue:   errorText = "Network error. Try again."
            default:                                    errorText = ns.localizedDescription
            }
        }
    }

    private func sendResetEmail() async {
        guard !loginEmail.isEmpty else { errorText = "Enter your email above, then tap “Forgot password?”"; return }
        isBusy = true; errorText = nil
        do {
            try await Auth.auth().sendPasswordReset(withEmail: loginEmail.lowercased())
            isBusy = false
            errorText = "Reset email sent. Check your inbox."
        } catch {
            isBusy = false
            let ns = error as NSError
            print("🔁 Reset error ->", ns.domain, ns.code, ns.userInfo)
            switch ns.code {
            case AuthErrorCode.invalidEmail.rawValue: errorText = "Invalid email address."
            case AuthErrorCode.userNotFound.rawValue: errorText = "No account found with this email."
            case AuthErrorCode.networkError.rawValue: errorText = "Network error. Try again."
            default: errorText = ns.localizedDescription
            }
        }
    }

    // ===== Helpers (unchanged) =====

    /// Device type detection
    private func deviceType(for size: CGSize) -> DeviceType {
        let width  = max(size.width, 1)
        let height = max(size.height, 1)
        let isLandscape = width > height

        if hSizeClass == .regular && vSizeClass == .regular {
            if width >= 1024 { return .iPadPro12_9 }
            if width >= 834  { return .iPadPro11 }
            return .iPadMini
        }
        if isLandscape {
            if width >= 932 { return .iPhoneProMaxLandscape }
            if width >= 852  { return .iPhonePlusLandscape }
            return .iPhoneLandscape
        } else {
            if height >= 932 { return .iPhoneProMax }
            if height >= 844 { return .iPhonePro }
            if height >= 812 { return .iPhoneStandard }
            if height >= 736 { return .iPhonePlus }
            return .iPhoneSE
        }
    }

    private func maxCardWidth(for size: CGSize) -> CGFloat {
        let w = max(size.width, 1)
        switch deviceType(for: size) {
        case .iPadPro12_9: return min(w * 0.5, 650)
        case .iPadPro11:   return min(w * 0.6, 550)
        case .iPadMini:    return min(w * 0.7, 480)
        case .iPhoneProMaxLandscape, .iPhonePlusLandscape: return min(w * 0.7, 550)
        case .iPhoneLandscape: return min(w * 0.75, 500)
        default:
            let pad = edgePadding(for: size)
            return max(1, w - 2 * pad)
        }
    }

    enum DeviceType {
        case iPhoneSE, iPhonePlus, iPhoneStandard, iPhonePro, iPhoneProMax
        case iPhoneLandscape, iPhonePlusLandscape, iPhoneProMaxLandscape
        case iPadMini, iPadPro11, iPadPro12_9
    }

    private func edgePadding(for size: CGSize) -> CGFloat {
        switch deviceType(for: size) {
        case .iPadPro12_9: return 60
        case .iPadPro11: return 48
        case .iPadMini: return 36
        case .iPhoneProMaxLandscape, .iPhonePlusLandscape: return 32
        case .iPhoneLandscape: return 24
        case .iPhoneProMax, .iPhonePro: return 20
        case .iPhoneStandard, .iPhonePlus: return 18
        case .iPhoneSE: return 16
        }
    }

    private func cornerRadius(for size: CGSize) -> CGFloat {
        switch deviceType(for: size) {
        case .iPadPro12_9, .iPadPro11: return 32
        case .iPadMini: return 28
        case .iPhoneProMaxLandscape, .iPhonePlusLandscape, .iPhoneLandscape: return 24
        default: return 20
        }
    }

    private func shadowRadius(for size: CGSize) -> CGFloat {
        switch deviceType(for: size) {
        case .iPadPro12_9, .iPadPro11: return 12
        case .iPadMini: return 10
        default: return 8
        }
    }

    private func titleFont(for size: CGSize) -> Font {
        switch deviceType(for: size) {
        case .iPadPro12_9: return .system(size: 42, weight: .bold)
        case .iPadPro11:   return .system(size: 36, weight: .bold)
        case .iPadMini:    return .system(size: 32, weight: .bold)
        default: return .title.bold()
        }
    }

    private func subtitleFont(for size: CGSize) -> Font {
        switch deviceType(for: size) {
        case .iPadPro12_9, .iPadPro11: return .title3
        case .iPadMini: return .body
        case .iPhoneSE: return .caption
        default: return .subheadline
        }
    }

    private func buttonFont(for size: CGSize) -> Font {
        switch deviceType(for: size) {
        case .iPadPro12_9, .iPadPro11: return .title3
        case .iPadMini: return .body
        default: return .body
        }
    }

    private func captionFont(for size: CGSize) -> Font {
        switch deviceType(for: size) {
        case .iPadPro12_9, .iPadPro11: return .subheadline
        case .iPhoneSE: return .system(size: 11)
        default: return .footnote
        }
    }

    private func spacing(for size: CGSize) -> CGFloat {
        switch deviceType(for: size) {
        case .iPadPro12_9: return 28
        case .iPadPro11, .iPadMini: return 24
        case .iPhoneSE: return 12
        case .iPhoneStandard: return 14
        default: return 16
        }
    }

    private func fieldSpacing(for size: CGSize) -> CGFloat {
        switch deviceType(for: size) {
        case .iPadPro12_9, .iPadPro11: return 16
        case .iPadMini: return 14
        case .iPhoneSE: return 10
        default: return 11
        }
    }

    private func verticalPadding(for size: CGSize) -> CGFloat {
        switch deviceType(for: size) {
        case .iPadPro12_9: return 40
        case .iPadPro11, .iPadMini: return 32
        case .iPhoneSE: return 16
        case .iPhoneStandard: return 20
        default: return 24
        }
    }

    private func topHeaderPadding(for size: CGSize) -> CGFloat {
        switch deviceType(for: size) {
        case .iPadPro12_9: return 20
        case .iPadPro11, .iPadMini: return 16
        case .iPhoneSE: return 8
        default: return 12
        }
    }

    private func buttonPadding(for size: CGSize) -> CGFloat {
        switch deviceType(for: size) {
        case .iPadPro12_9, .iPadPro11: return 18
        case .iPadMini: return 16
        case .iPhoneSE: return 11
        default: return 13
        }
    }

    private func socialSpacing(for size: CGSize) -> CGFloat {
        switch deviceType(for: size) {
        case .iPadPro12_9, .iPadPro11: return 20
        default: return 14
        }
    }

    // MARK: - Components
    private func tabButton(title: String, tab: Tab, size: CGSize) -> some View {
        Button { selectedTab = tab } label: {
            Text(title)
                .font(deviceType(for: size) == .iPhoneSE ? .subheadline.weight(.semibold) : .headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, tabPadding(for: size))
                .background(selectedTab == tab ? Color.white : Color.clear)
                .foregroundStyle(selectedTab == tab ? .black : .white)
                .clipShape(Capsule())
        }
    }

    private func tabPadding(for size: CGSize) -> CGFloat {
        switch deviceType(for: size) {
        case .iPadPro12_9, .iPadPro11: return 14
        case .iPhoneSE: return 8
        default: return 10
        }
    }

    private func customField(icon: String,
                             placeholder: String,
                             text: Binding<String>,
                             keyboardType: UIKeyboardType = .default,
                             size: CGSize) -> some View {
        HStack(spacing: iconSpacing(for: size)) {
            Image(systemName: icon)
                .foregroundStyle(.gray)
                .font(iconFont(for: size))
            TextField(placeholder, text: text)
                .font(inputFont(for: size))
                .keyboardType(keyboardType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(inputPadding(for: size))
        .background(Color.white.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: inputCornerRadius(for: size)))
    }

    private func secureField(icon: String,
                             placeholder: String,
                             text: Binding<String>,
                             show: Binding<Bool>,
                             size: CGSize) -> some View {
        HStack(spacing: iconSpacing(for: size)) {
            Image(systemName: icon)
                .foregroundStyle(.gray)
                .font(iconFont(for: size))
            if show.wrappedValue {
                TextField(placeholder, text: text)
                    .font(inputFont(for: size))
                    .textInputAutocapitalization(.never)
            } else {
                SecureField(placeholder, text: text)
                    .font(inputFont(for: size))
                    .textInputAutocapitalization(.never)
            }
            Button { show.wrappedValue.toggle() } label: {
                Image(systemName: show.wrappedValue ? "eye.slash" : "eye")
                    .foregroundStyle(.gray)
                    .font(iconFont(for: size))
            }
        }
        .padding(inputPadding(for: size))
        .background(Color.white.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: inputCornerRadius(for: size)))
    }

    private func iconFont(for size: CGSize) -> Font {
        switch deviceType(for: size) {
        case .iPadPro12_9, .iPadPro11: return .title3
        case .iPhoneSE: return .caption
        default: return .body
        }
    }

    private func inputFont(for size: CGSize) -> Font {
        switch deviceType(for: size) {
        case .iPadPro12_9, .iPadPro11: return .title3
        case .iPhoneSE: return .subheadline
        default: return .body
        }
    }

    private func inputPadding(for size: CGSize) -> CGFloat {
        switch deviceType(for: size) {
        case .iPadPro12_9, .iPadPro11: return 18
        case .iPadMini: return 16
        case .iPhoneSE: return 11
        default: return 13
        }
    }

    private func inputCornerRadius(for size: CGSize) -> CGFloat {
        switch deviceType(for: size) {
        case .iPadPro12_9, .iPadPro11: return 14
        case .iPhoneSE: return 8
        default: return 10
        }
    }

    private func iconSpacing(for size: CGSize) -> CGFloat {
        switch deviceType(for: size) {
        case .iPadPro12_9, .iPadPro11: return 14
        case .iPhoneSE: return 8
        default: return 10
        }
    }

    private func socialButton(image: String, label: String, size: CGSize) -> some View {
        HStack(spacing: iconSpacing(for: size)) {
            Image(systemName: image)
                .font(iconFont(for: size))
            Text(label)
                .font(inputFont(for: size))
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, buttonPadding(for: size))
        .background(Color.white.opacity(0.95))
        .foregroundStyle(.black)
        .clipShape(RoundedRectangle(cornerRadius: inputCornerRadius(for: size)))
    }
}

#Preview { SignUpView() }
