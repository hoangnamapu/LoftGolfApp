import SwiftUI

struct ProfileTabView: View {
    //Credit card
    @State private var showCustomerProfileDetails = false
    
    
    
    @StateObject private var viewModel = ProfileViewModel()
    @Binding var isAuthenticated: Bool
    let authToken: String?

    @State private var showSettings = false
    @State private var showCardSheet = false
    @State private var showForgotPasscode = false
    @State private var savedCard: PaymentCardFormData?
    @State private var showGiftCardStore = false
    
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
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                Group {
                    if viewModel.isLoading {
                        ProgressView("Loading account...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let profile = viewModel.userProfile {
                        List {
                            AccountHeaderView(profile: profile)
                                .listRowInsets(EdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)

                            Section {
                                
                                NavigationLink {
                                    AccountInformationView()
                                } label: {
                                    Label("Account Information", systemImage: "creditcard.fill")
                                }
                                Button {
                                    showSettings = true
                                } label: {
                                    Label("Settings", systemImage: "gearshape.fill")
                                }

                                Link(destination: URL(string: "https://loftgolfstudios.com/faq")!) {
                                    Label("Help", systemImage: "questionmark.circle")
                                }
                                
                                Button {
                                    showForgotPasscode = true
                                } label: {
                                    Label("Reset Password", systemImage: "key.fill")
                                }

                                Button(role: .destructive) {
                                    viewModel.showLogoutConfirmation = true
                                } label: {
                                    Label("Sign Out", systemImage: "arrow.right.square")
                                }
                            }

                            Section("Loft Golf Studios Store") {
                                Button {
                                    showGiftCardStore = true
                                } label: {
                                    Label("Buy Gift Card", systemImage: "gift")
                                }
                            }

                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    } else {
                        ContentUnavailableView(
                            "No Account Data",
                            systemImage: "person.crop.circle.badge.exclamationmark",
                            description: Text("Unable to load your account information")
                        )
                    }
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.large)
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
                .foregroundColor(.primary)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
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

import WebKit

struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webview = WKWebView()
        webview.load(URLRequest(url: url))
        return webview
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
