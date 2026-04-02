import SwiftUI
import WebKit

struct ProfileTabView: View {
    @State private var showCustomerProfileDetails = false
    @StateObject private var viewModel = ProfileViewModel()
    @Binding var isAuthenticated: Bool
    let authToken: String?

    @State private var showSettings = false
    @State private var showCardSheet = false
    @State private var showForgotPasscode = false
    @State private var savedCard: PaymentCardFormData?
    @State private var showGiftCardStore = false
    @State private var showPrepaidCardStore = false

    @State private var localCard: LocalCardInfo?
    @State private var savedCards: [SavedCardDisplay] = []

    init(isAuthenticated: Binding<Bool>, authToken: String? = nil) {
        self._isAuthenticated = isAuthenticated
        self.authToken = authToken
    }

    private var infoAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.infoMessage != nil },
            set: { if !$0 { viewModel.infoMessage = nil } }
        )
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    var body: some View {
        NavigationStack {
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
                )
                .ignoresSafeArea()

                Group {
                    if viewModel.isLoading {
                        ProgressView("Loading account...")
                            .tint(.white)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let profile = viewModel.userProfile {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                Text("Account")
                                    .font(.system(size: 34, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.top, 20)

                                AccountHeaderView(profile: profile)

                                accountSection(
                                    title: "Account",
                                    rows: [
                                        .navigation("Account Information", systemImage: "creditcard.fill") {
                                            AnyView(AccountInformationView())
                                        },
                                        .button("Settings", systemImage: "gearshape.fill") {
                                            showSettings = true
                                        },
                                        .link("Help", systemImage: "questionmark.circle", url: URL(string: "https://loftgolfstudios.com/simulator-how-to")!),
                                        .button("Reset Password", systemImage: "key.fill") {
                                            showForgotPasscode = true
                                        },
                                        .destructive("Sign Out", systemImage: "arrow.right.square") {
                                            viewModel.showLogoutConfirmation = true
                                        }
                                    ]
                                )

                                accountSection(
                                    title: "Loft Golf Studios Store",
                                    rows: [
                                        .button("Buy Pre-Paid Discount Cards", systemImage: "creditcard.fill") {
                                            showPrepaidCardStore = true
                                        },
                                        .button("Buy Gift Card", systemImage: "gift") {
                                            showGiftCardStore = true
                                        }
                                    ]
                                )
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 40)
                        }
                    } else {
                        ContentUnavailableView(
                            "No Account Data",
                            systemImage: "person.crop.circle.badge.exclamationmark",
                            description: Text("Unable to load your account information")
                        )
                    }
                }
            }
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .refreshable {
                await viewModel.loadProfile()
            }
            .task {
                if let token = authToken {
                    viewModel.setAuthToken(token)
                }

                if viewModel.userProfile == nil {
                    await viewModel.loadProfile()
                }
            }
            .task {
                localCard = LocalCardStore.load()
            }
            .confirmationDialog("Sign Out", isPresented: $viewModel.showLogoutConfirmation) {
                Button("Sign Out", role: .destructive) {
                    viewModel.logout()
                    isAuthenticated = false
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Notice", isPresented: infoAlertBinding) {
                Button("OK", role: .cancel) {
                    viewModel.infoMessage = nil
                }
            } message: {
                Text(viewModel.infoMessage ?? "")
            }
            .alert("Error", isPresented: errorAlertBinding) {
                Button("OK", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(isPresented: $showSettings) {
                AccountSettingsView(viewModel: viewModel, isPresented: $showSettings)
            }
            .sheet(isPresented: $showCardSheet) {
                PaymentCardFormView(initial: savedCard) { data in
                    savedCard = data
                }
            }
            .sheet(isPresented: $viewModel.showEditProfile) {
                EditProfileView(viewModel: viewModel)
            }
            .sheet(isPresented: $showPrepaidCardStore) {
                NavigationStack {
                    WebView(url: URL(string: "https://clients.uschedule.com/loftgolfstudios/Product/PrepayServiceList")!)
                        .navigationTitle("Pre-Paid Discount Cards")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showPrepaidCardStore = false
                                }
                            }
                        }
                }
            }
            .sheet(isPresented: $showGiftCardStore) {
                NavigationStack {
                    WebView(url: URL(string: "https://clients.uschedule.com/loftgolfstudios/Product/GiftCertDetail")!)
                        .navigationTitle("Gift Cards")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showGiftCardStore = false
                                }
                            }
                        }
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
            .sheet(isPresented: $showCustomerProfileDetails) {
                NavigationStack {
                    WebView(url: URL(string: "https://clients.uschedule.com/loftgolfstudios/customerprofile/details")!)
                        .navigationTitle("Account Information")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showCustomerProfileDetails = false
                                }
                            }
                        }
                }
            }
        }
    }

    private func accountSection(title: String, rows: [AccountRow]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.gray)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    AccountRowView(row: row)

                    if index < rows.count - 1 {
                        Divider()
                            .background(Color.gray.opacity(0.3))
                            .padding(.leading, 46)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6).opacity(0.15))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

private struct AccountHeaderView: View {
    let profile: UserProfile

    var body: some View {
        HStack(spacing: 16) {
            Image("LoftGolfLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 90, height: 90)
                .clipShape(Circle())
                .accessibilityLabel("Loft Golf logo")

            Text(profile.fullName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6).opacity(0.15))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

private enum AccountRow {
    case navigation(String, systemImage: String, destination: () -> AnyView)
    case button(String, systemImage: String, action: () -> Void)
    case destructive(String, systemImage: String, action: () -> Void)
    case link(String, systemImage: String, url: URL)
}

private struct AccountRowView: View {
    let row: AccountRow

    var body: some View {
        switch row {
        case .navigation(let title, let systemImage, let destination):
            NavigationLink {
                destination()
            } label: {
                rowLabel(title: title, systemImage: systemImage, isDestructive: false)
            }
            .buttonStyle(.plain)

        case .button(let title, let systemImage, let action):
            Button(action: action) {
                rowLabel(title: title, systemImage: systemImage, isDestructive: false)
            }
            .buttonStyle(.plain)

        case .destructive(let title, let systemImage, let action):
            Button(role: .destructive, action: action) {
                rowLabel(title: title, systemImage: systemImage, isDestructive: true)
            }
            .buttonStyle(.plain)

        case .link(let title, let systemImage, let url):
            Link(destination: url) {
                rowLabel(title: title, systemImage: systemImage, isDestructive: false)
            }
            .buttonStyle(.plain)
        }
    }

    private func rowLabel(title: String, systemImage: String, isDestructive: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isDestructive ? .red : .green)
                .frame(width: 24)

            Text(title)
                .font(.body)
                .foregroundStyle(isDestructive ? .red : .white)

            Spacer()

            if !isDestructive {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
        .padding(.vertical, 14)
    }
}

private struct AccountSettingsView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "Version: \(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Notifications") {
                    Toggle("Push Notifications", isOn: $viewModel.pushNotificationsEnabled)
                }

                Section {
                    Text(appVersion)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ProfileTabView(isAuthenticated: .constant(true))
}

struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webview = WKWebView()
        webview.load(URLRequest(url: url))
        return webview
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
