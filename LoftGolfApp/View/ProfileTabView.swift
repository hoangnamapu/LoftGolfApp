//
//  ProfileTabView.swift
//  LoftGolfApp
//
//  Created by ZhiYue Wang on 10/14/25.
//

import SwiftUI

struct ProfileTabView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @Binding var isAuthenticated: Bool
    let authToken: String?

    @State private var showChangePasswordSheet = false
    @State private var showAvatarOptions = false
    @State private var showCardSheet: Bool = false
    @State private var savedCard: PaymentCardFormData? = nil


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
                        ProgressView("Loading profile...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let profile = viewModel.userProfile {
                        List {
                            Section {
                                ProfileSummaryCard(profile: profile) {
                                    showAvatarOptions = true
                                }
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                            }

                            Section("Account") {
                                Button {
                                    viewModel.showEditProfile = true
                                } label: {
                                    Label("Edit Personal Info", systemImage: "person.text.rectangle")
                                        .foregroundColor(.primary)
                                }

                                Button {
                                    showAvatarOptions = true
                                } label: {
                                    Label("Change Avatar", systemImage: "person.crop.circle.badge.plus")
                                        .foregroundColor(.primary)
                                }

                                Button {
                                    showChangePasswordSheet = true
                                } label: {
                                    Label("Change Password", systemImage: "key.fill")
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            Section("Payments") {
                                if let card = savedCard {
                                    SavedCardSummary(data: card) {
                                        showCardSheet = true
                                    }
                                } else {
                                    Button {
                                        showCardSheet = true
                                    } label: {
                                        Label("Add Credit/Debit Card", systemImage: "plus.circle.fill")
                                    }
                                }
                            }

                            Section("Notifications") {
                                Toggle(isOn: $viewModel.pushNotificationsEnabled) {
                                    Label("Push Notifications", systemImage: "bell.badge.fill")
                                }

                                Toggle(isOn: $viewModel.emailNotificationsEnabled) {
                                    Label("Email Updates", systemImage: "envelope.fill")
                                }
                            }

                            Section("Support") {
                                Link(destination: URL(string: "https://loftgolfstudios.com/faq")!) {
                                    Label("FAQ", systemImage: "questionmark.circle")
                                }

                                Link(destination: URL(string: "https://www.instagram.com/loftgolfstudios")!) {
                                    Label("Instagram Community", systemImage: "camera.fill")
                                }

                                Link(destination: URL(string: "https://www.facebook.com/loftgolfstudios/")!) {
                                    Label("Facebook Page", systemImage: "person.3.fill")
                                }
                            }

                            Section("Danger Zone") {
                                Button(role: .destructive) {
                                    viewModel.showLogoutConfirmation = true
                                } label: {
                                    Label("Sign Out", systemImage: "arrow.right.square")
                                }
                            }
                            

                        }
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                    } else {
                        ContentUnavailableView(
                            "No Profile Data",
                            systemImage: "person.crop.circle.badge.exclamationmark",
                            description: Text("Unable to load profile information")
                        )
                    }
                }
            }
            .navigationTitle("Profile")
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
            .confirmationDialog("Change Avatar", isPresented: $showAvatarOptions) {
                Button("Upload Photo") {
                    viewModel.startAvatarUpload()
                }
                Button("Take Photo") {
                    viewModel.startAvatarCapture()
                }
                Button("Cancel", role: .cancel) {}
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
            .sheet(isPresented: $showChangePasswordSheet) {
                ChangePasswordSheet()
            }
            .sheet(isPresented: $viewModel.showEditProfile) {
                EditProfileView(viewModel: viewModel)
            }
            .sheet(isPresented: $showCardSheet) {
                PaymentCardFormView(initial: savedCard) { data in
                    savedCard = data
                }
            }
        }
    }
}

private struct ProfileSummaryCard: View {
    let profile: UserProfile
    let onChangeAvatar: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 96, height: 96)

                Text(profileInitials)
                    .font(.title.bold())
                    .foregroundColor(.blue)
            }

            VStack(spacing: 4) {
                Text(profile.fullName)
                    .font(.title3.weight(.semibold))
                Text(profile.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if let phone = profile.phone, !phone.isEmpty {
                    Text(phone)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }

            Button {
                onChangeAvatar()
            } label: {
                Text("Change Avatar")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(20)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        .padding(.horizontal)
    }

    private var profileInitials: String {
        let firstInitial = profile.firstName.first.map(String.init) ?? ""
        let lastInitial = profile.lastName.first.map(String.init) ?? ""
        let initials = (firstInitial + lastInitial)
        return initials.isEmpty ? "?" : initials.uppercased()
    }
}

private struct ChangePasswordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isProcessing = false
    @State private var showMismatchAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Current Password") {
                    SecureField("Current Password", text: $currentPassword)
                }

                Section("New Password") {
                    SecureField("New Password", text: $newPassword)
                    SecureField("Confirm New Password", text: $confirmPassword)
                }

                Section {
                    Button {
                        attemptPasswordChange()
                    } label: {
                        if isProcessing {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Update Password")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isProcessing || currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty)
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .disabled(isProcessing)
                }
            }
            .alert("Passwords Do Not Match", isPresented: $showMismatchAlert) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func attemptPasswordChange() {
        guard newPassword == confirmPassword else {
            showMismatchAlert = true
            return
        }

        isProcessing = true
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await MainActor.run {
                isProcessing = false
                dismiss()
            }
        }
    }
}

#if DEBUG
struct ProfileTabView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileTabView(isAuthenticated: .constant(true))
    }
}
#endif
