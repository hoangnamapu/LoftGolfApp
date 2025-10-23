//
//  Editprofileview.swift
//  LoftGolfApp
//
//  Created by ZhiYue Wang on 10/22/25.
//

import SwiftUI

struct EditProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    
    enum Field {
        case firstName, lastName, email, phone
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Personal Information") {
                    TextField("First Name", text: $viewModel.editFirstName)
                        .focused($focusedField, equals: .firstName)
                        .textContentType(.givenName)
                        .textInputAutocapitalization(.words)

                    TextField("Last Name", text: $viewModel.editLastName)
                        .focused($focusedField, equals: .lastName)
                        .textContentType(.familyName)
                        .textInputAutocapitalization(.words)

                    DatePicker("Birthday", selection: $viewModel.editBirthday, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact)

                    Picker("Gender", selection: $viewModel.editGender) {
                        ForEach(GenderOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                }

                Section("Contact Information") {
                    TextField("Email", text: $viewModel.editEmail)
                        .focused($focusedField, equals: .email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                    
                    TextField("Phone", text: $viewModel.editPhone)
                        .focused($focusedField, equals: .phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                }
                
                if let profile = viewModel.userProfile {
                    Section("Account Information") {
                        LabeledContent("Username", value: profile.username)
                        
                        if let memberId = profile.reference1 {
                            LabeledContent("Member ID", value: memberId)
                        }
                        
                        if let membershipExp = profile.membershipExp {
                            LabeledContent("Membership Expires") {
                                Text(membershipExp, style: .date)
                                    .foregroundColor(profile.isMembershipActive ? .green : .red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.updateProfile()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.isLoading || !isFormValid)
                }
            }
            .overlay {
                if viewModel.isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("Updating...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 4)
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !viewModel.editFirstName.isEmpty &&
        !viewModel.editLastName.isEmpty &&
        !viewModel.editEmail.isEmpty &&
        viewModel.editEmail.contains("@") &&
        viewModel.editBirthday <= Date()
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Binding var isAuthenticated: Bool
    @Binding var showSettings: Bool
    @State private var showDeleteAccount = false
    @State private var showPrivacyPolicy = false
    @State private var showTerms = false
    @State private var notificationsEnabled = true
    @State private var emailNotifications = true
    
    var body: some View {
        NavigationStack {
            List {
                // Account Section
                Section("Account") {
                    Button {
                        viewModel.showEditProfile = true
                        showSettings = false
                    } label: {
                        Label("Edit Profile", systemImage: "person.circle")
                            .foregroundColor(.primary)
                    }
                    
                    Button {
                        // Change password functionality
                    } label: {
                        Label("Change Password", systemImage: "lock.rotation")
                            .foregroundColor(.primary)
                    }
                }
                
                // Notifications
                Section("Notifications") {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("Push Notifications", systemImage: "bell")
                    }
                    
                    Toggle(isOn: $emailNotifications) {
                        Label("Email Updates", systemImage: "envelope")
                    }
                    
                }

                // Legal
                Section("Legal") {
                    Button {
                        showPrivacyPolicy = true
                    } label: {
                        Label("Privacy Policy", systemImage: "hand.raised")
                            .foregroundColor(.primary)
                    }
                    
                    Button {
                        showTerms = true
                    } label: {
                        Label("Terms of Service", systemImage: "doc.text")
                            .foregroundColor(.primary)
                    }
                }
                
                // Support
                Section("Support") {
                    Link(destination: URL(string: "mailto:info@loftgolfstudios.com")!) {
                        Label("Contact Support", systemImage: "envelope")
                            .foregroundColor(.primary)
                    }
                    
                    Link(destination: URL(string: "https://loftgolfstudios.com/faq")!) {
                        Label("FAQ", systemImage: "questionmark.circle")
                            .foregroundColor(.primary)
                    }
                }
                
                // Danger Zone
                Section {
                    Button {
                        viewModel.showLogoutConfirmation = true
                    } label: {
                        Label("Sign Out", systemImage: "arrow.right.square")
                            .foregroundColor(.red)
                    }
                    
                    Button {
                        showDeleteAccount = true
                    } label: {
                        Label("Delete Account", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
                
                // App Info
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("100")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showSettings = false
                    }
                }
            }
            .confirmationDialog("Sign Out", isPresented: $viewModel.showLogoutConfirmation) {
                Button("Sign Out", role: .destructive) {
                    viewModel.logout()
                    isAuthenticated = false
                    showSettings = false
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Delete Account", isPresented: $showDeleteAccount) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    // Handle account deletion
                }
            } message: {
                Text("This action cannot be undone. All your data will be permanently deleted.")
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                SafariView(url: URL(string: "https://loftgolfstudios.com/privacy")!)
            }
            .sheet(isPresented: $showTerms) {
                SafariView(url: URL(string: "https://loftgolfstudios.com/terms")!)
            }
        }
    }
}

// MARK: - Booking Details View
struct BookingDetailsView: View {
    let booking: BookingHistory
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showCancelConfirmation = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Status Header
                    HStack {
                        StatusBadge(status: booking.status)
                        Spacer()
                        if let price = booking.price {
                            Text("$\(price)")
                                .font(.title2.bold())
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Booking Details
                    VStack(alignment: .leading, spacing: 16) {
                        DetailRow(
                            icon: "sportscourt",
                            title: "Service",
                            value: booking.description
                        )
                        
                        DetailRow(
                            icon: "calendar",
                            title: "Date",
                            value: booking.startTime.formatted(date: .complete, time: .omitted)
                        )
                        
                        DetailRow(
                            icon: "clock",
                            title: "Time",
                            value: booking.startTime.formatted(date: .omitted, time: .shortened)
                        )
                        
                        if let location = booking.locationName {
                            DetailRow(
                                icon: "location",
                                title: "Location",
                                value: location
                            )
                        }
                        
                        if let service = booking.serviceName {
                            DetailRow(
                                icon: "star",
                                title: "Package",
                                value: service
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 1)
                    
                    // Actions
                    if booking.status == .active && booking.startTime > Date() {
                        VStack(spacing: 12) {
                            Button {
                                // Reschedule functionality
                            } label: {
                                Label("Reschedule", systemImage: "calendar.badge.clock")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            
                            Button {
                                showCancelConfirmation = true
                            } label: {
                                Label("Cancel Booking", systemImage: "xmark.circle")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red.opacity(0.1))
                                    .foregroundColor(.red)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    
                    // Add to Calendar
                    if booking.status == .active {
                        Button {
                            // Add to calendar functionality
                        } label: {
                            Label("Add to Calendar", systemImage: "calendar.badge.plus")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Booking Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog("Cancel Booking", isPresented: $showCancelConfirmation) {
                Button("Cancel Booking", role: .destructive) {
                    Task {
                        await viewModel.cancelAppointment(booking.id)
                        dismiss()
                    }
                }
                Button("Keep Booking", role: .cancel) {}
            } message: {
                Text("Are you sure you want to cancel this booking? This action cannot be undone.")
            }
        }
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
            }
            
            Spacer()
        }
    }
}

struct StatusBadge: View {
    let status: AppointmentStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.2))
            .foregroundColor(status.color)
            .cornerRadius(8)
    }
}

// MARK: - Safari View
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Previews
struct EditProfileView_Previews: PreviewProvider {
    static var previews: some View {
        EditProfileView(viewModel: ProfileViewModel.preview)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(
            viewModel: ProfileViewModel.preview,
            isAuthenticated: .constant(true),
            showSettings: .constant(true)
        )
    }
}
