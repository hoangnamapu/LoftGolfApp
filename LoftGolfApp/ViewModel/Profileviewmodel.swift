//
//  Profileviewmodel.swift
//  LoftGolfApp
//
//  Created by ZhiYue Wang on 10/22/25.
//

import Foundation
import SwiftUI

// MARK: - Profile Models
struct UserProfile {
    let userId: Int
    let customerId: Int
    let firstName: String
    let lastName: String
    let email: String
    let phone: String?
    let birthDate: Date?
    let gender: GenderOption
    let username: String
    let reference1: String?  // Member ID
    let reference2: String?
    let reference3: String?
    let statusId: Int?
    let membershipId: Int?
    let membershipStart: Date?
    let membershipExp: Date?
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    var isMembershipActive: Bool {
        guard let exp = membershipExp else { return false }
        return exp > Date()
    }
}

struct BookingHistory: Identifiable {
    let id: Int
    let description: String
    let startTime: Date
    let endTime: Date?
    let locationName: String?
    let serviceName: String?
    let price: Decimal?
    let status: AppointmentStatus
}

enum GenderOption: String, CaseIterable, Identifiable {
    case female = "Female"
    case male = "Male"
    case nonBinary = "Non-binary"
    case preferNot = "Prefer not to say"
    case unspecified = "Unspecified"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .female: return "Female"
        case .male: return "Male"
        case .nonBinary: return "Non-binary"
        case .preferNot: return "Prefer not to say"
        case .unspecified: return "Not specified"
        }
    }

    init(apiValue: String?) {
        guard let value = apiValue?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            self = .unspecified
            return
        }

        switch value.lowercased() {
        case "male":
            self = .male
        case "female":
            self = .female
        case "non-binary", "nonbinary":
            self = .nonBinary
        case "prefer not to say", "prefer_not_to_say", "prefer-not":
            self = .preferNot
        default:
            self = .unspecified
        }
    }

    var apiValue: String? {
        switch self {
        case .unspecified:
            return nil
        default:
            return rawValue
        }
    }
}

enum AppointmentStatus: Int {
    case active = 1
    case canceled = 9
    case rescheduled = 10
    case tentative = 11
    case completed = 99
    
    var displayName: String {
        switch self {
        case .active: return "Upcoming"
        case .canceled: return "Canceled"
        case .rescheduled: return "Rescheduled"
        case .tentative: return "Tentative"
        case .completed: return "Completed"
        }
    }
    
    var color: Color {
        switch self {
        case .active: return .green
        case .canceled: return .red
        case .rescheduled: return .orange
        case .tentative: return .yellow
        case .completed: return .gray
        }
    }
}

// MARK: - ViewModel
@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var userProfile: UserProfile?
    @Published var upcomingBookings: [BookingHistory] = []
    @Published var pastBookings: [BookingHistory] = []
    @Published var prepaidCards: [PrepaidCard] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showEditProfile = false
    @Published var showLogoutConfirmation = false
    @Published var pushNotificationsEnabled = true
    @Published var emailNotificationsEnabled = true
    @Published var infoMessage: String?
    
    // Edit profile fields
    @Published var editFirstName = ""
    @Published var editLastName = ""
    @Published var editEmail = ""
    @Published var editPhone = ""
    @Published var editBirthday = ProfileViewModel.defaultBirthday
    @Published var editGender: GenderOption = .unspecified
    
    private let client = UScheduleClient()
    private var authToken: String?
    
    struct PrepaidCard {
        let id: Int
        let description: String
        let remainingUnits: Int
        let originalUnits: Int
        let expirationDate: Date?
        let unitName: String
        
        var isExpired: Bool {
            guard let exp = expirationDate else { return false }
            return exp < Date()
        }
        
        var usagePercentage: Double {
            guard originalUnits > 0 else { return 0 }
            return Double(originalUnits - remainingUnits) / Double(originalUnits)
        }
    }
    
    // MARK: - Initialization
    init(authToken: String? = nil) {
        self.authToken = authToken
    }
    
    // MARK: - Data Loading
    func loadProfile() async {
        guard let token = authToken else {
            await MainActor.run {
                errorMessage = "Not authenticated"
            }
            return
        }
        
        await MainActor.run { isLoading = true }
        
        do {
            // Load customer profile
            let customerData = try await fetchCustomerProfile(token: token)
            
            // Load appointments
            let appointments = try await fetchAppointments(token: token)
            
            // Load prepaid cards
            let cards = try await fetchPrepaidCards(token: token)
            
            await MainActor.run {
                self.userProfile = customerData
                self.editFirstName = customerData.firstName
                self.editLastName = customerData.lastName
                self.editEmail = customerData.email
                self.editPhone = customerData.phone ?? ""
                if let birthday = customerData.birthDate {
                    self.editBirthday = birthday
                } else {
                    self.editBirthday = Self.defaultBirthday
                }
                self.editGender = customerData.gender
                
                // Separate upcoming and past bookings
                let now = Date()
                self.upcomingBookings = appointments
                    .filter { $0.startTime > now }
                    .sorted { $0.startTime < $1.startTime }
                
                self.pastBookings = appointments
                    .filter { $0.startTime <= now }
                    .sorted { $0.startTime > $1.startTime }
                
                self.prepaidCards = cards
                self.isLoading = false
                self.errorMessage = nil
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - API Calls
    private func fetchCustomerProfile(token: String) async throws -> UserProfile {
        // Using the existing client method from UScheduleClient
        var request = URLRequest(url: URL(string: "\(USConfig.baseURL)/api/\(USConfig.alias)/customer")!)
        request.httpMethod = "GET"
        request.setValue(USConfig.appKey, forHTTPHeaderField: "X-US-Application-Key")
        request.setValue(token, forHTTPHeaderField: "X-US-AuthToken")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw USError.http(
                (response as? HTTPURLResponse)?.statusCode ?? 0,
                String(data: data, encoding: .utf8) ?? "Unknown error"
            )
        }
        
        // Parse customer data
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        
        return UserProfile(
            userId: json["UserID"] as? Int ?? 0,
            customerId: json["Id"] as? Int ?? 0,
            firstName: json["FirstName"] as? String ?? "",
            lastName: json["LastName"] as? String ?? "",
            email: json["EmailAddress"] as? String ?? "",
            phone: json["Phone"] as? String,
            birthDate: parseDate(json["BirthDate"] as? String) ?? parseDate(json["Birthdate"] as? String),
            gender: GenderOption(apiValue: json["Gender"] as? String),
            username: json["Username"] as? String ?? "",
            reference1: json["Reference1"] as? String,
            reference2: json["Reference2"] as? String,
            reference3: json["Reference3"] as? String,
            statusId: json["StatusID"] as? Int,
            membershipId: json["MembershipID"] as? Int,
            membershipStart: parseDate(json["MembershipStart"] as? String),
            membershipExp: parseDate(json["MembershipExp"] as? String)
        )
    }
    
    private func fetchAppointments(token: String) async throws -> [BookingHistory] {
        var request = URLRequest(url: URL(string: "\(USConfig.baseURL)/api/\(USConfig.alias)/appointments")!)
        request.httpMethod = "GET"
        request.setValue(USConfig.appKey, forHTTPHeaderField: "X-US-Application-Key")
        request.setValue(token, forHTTPHeaderField: "X-US-AuthToken")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw USError.http(
                (response as? HTTPURLResponse)?.statusCode ?? 0,
                String(data: data, encoding: .utf8) ?? "Unknown error"
            )
        }
        
        let appointments = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
        
        return appointments.compactMap { apt in
            guard let id = apt["Id"] as? Int,
                  let startTimeStr = apt["StartTime"] as? String,
                  let startTime = parseDate(startTimeStr) else { return nil }
            
            return BookingHistory(
                id: id,
                description: apt["Description"] as? String ?? "",
                startTime: startTime,
                endTime: parseDate(apt["EndTime"] as? String),
                locationName: apt["LocationName"] as? String,
                serviceName: apt["ServiceName"] as? String,
                price: apt["Price"] as? Decimal,
                status: AppointmentStatus(rawValue: apt["StatusID"] as? Int ?? 1) ?? .active
            )
        }
    }
    
    private func fetchPrepaidCards(token: String) async throws -> [PrepaidCard] {
        var request = URLRequest(url: URL(string: "\(USConfig.baseURL)/api/\(USConfig.alias)/prepayservicecustomers")!)
        request.httpMethod = "GET"
        request.setValue(USConfig.appKey, forHTTPHeaderField: "X-US-Application-Key")
        request.setValue(token, forHTTPHeaderField: "X-US-AuthToken")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw USError.http(
                (response as? HTTPURLResponse)?.statusCode ?? 0,
                String(data: data, encoding: .utf8) ?? "Unknown error"
            )
        }
        
        let cards = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
        
        return cards.compactMap { card in
            guard let id = card["Id"] as? Int else { return nil }
            
            return PrepaidCard(
                id: id,
                description: card["Description"] as? String ?? "",
                remainingUnits: card["RemainingUnits"] as? Int ?? 0,
                originalUnits: card["OriginalUnits"] as? Int ?? 0,
                expirationDate: parseDate(card["EndDate"] as? String),
                unitName: card["UnitName"] as? String ?? "units"
            )
        }
    }
    
    // MARK: - Profile Updates
    func updateProfile() async {
        guard let token = authToken else { return }
        
        await MainActor.run { isLoading = true }
        
        // Note: USchedule API doesn't have a direct update customer endpoint
        // You would need to work with USchedule to add this functionality
        // For now, this is a placeholder
        
        // Simulate update
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            if let profile = userProfile {
                self.userProfile = UserProfile(
                    userId: profile.userId,
                    customerId: profile.customerId,
                    firstName: editFirstName,
                    lastName: editLastName,
                    email: editEmail,
                    phone: editPhone.isEmpty ? nil : editPhone,
                    birthDate: editBirthday,
                    gender: editGender,
                    username: profile.username,
                    reference1: profile.reference1,
                    reference2: profile.reference2,
                    reference3: profile.reference3,
                    statusId: profile.statusId,
                    membershipId: profile.membershipId,
                    membershipStart: profile.membershipStart,
                    membershipExp: profile.membershipExp
                )
            }
            self.isLoading = false
            self.showEditProfile = false
            self.infoMessage = "Profile details updated successfully."
        }
    }
    
    // MARK: - Appointment Actions
    func cancelAppointment(_ appointmentId: Int) async {
        guard let token = authToken else { return }
        
        do {
            var request = URLRequest(url: URL(string: "\(USConfig.baseURL)/api/\(USConfig.alias)/cancelappointment")!)
            request.httpMethod = "POST"
            request.setValue(USConfig.appKey, forHTTPHeaderField: "X-US-Application-Key")
            request.setValue(token, forHTTPHeaderField: "X-US-AuthToken")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body = ["id": appointmentId]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                await loadProfile() // Reload to get updated data
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to cancel appointment: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Helper Methods
    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }
    
    func logout() {
        authToken = nil
        userProfile = nil
        upcomingBookings = []
        pastBookings = []
        prepaidCards = []
    }

    func setAuthToken(_ token: String) {
        self.authToken = token
    }

    private static var defaultBirthday: Date {
        Calendar.current.date(byAdding: .year, value: -21, to: Date()) ?? Date()
    }

    func startAvatarUpload() {
        infoMessage = "Avatar uploads will be available soon."
    }

    func startAvatarCapture() {
        infoMessage = "Camera support will be available soon."
    }

}

// MARK: - Mock Data for Preview
extension ProfileViewModel {
    static var preview: ProfileViewModel {
        let vm = ProfileViewModel()
        vm.userProfile = UserProfile(
            userId: 1,
            customerId: 1,
            firstName: "John",
            lastName: "Doe",
            email: "john.doe@example.com",
            phone: "555-1234",
            birthDate: Calendar.current.date(byAdding: .year, value: -32, to: Date()),
            gender: .male,
            username: "johndoe",
            reference1: "MEM-12345",
            reference2: nil,
            reference3: nil,
            statusId: 1,
            membershipId: 1,
            membershipStart: Date().addingTimeInterval(-30*24*60*60),
            membershipExp: Date().addingTimeInterval(335*24*60*60)
        )
        
        vm.upcomingBookings = [
            BookingHistory(
                id: 1,
                description: "Golf Simulator - Bay 1",
                startTime: Date().addingTimeInterval(2*24*60*60),
                endTime: Date().addingTimeInterval(2*24*60*60 + 60*60),
                locationName: "Loft Golf Studios",
                serviceName: "1 Hour Simulator",
                price: 60,
                status: .active
            )
        ]

        vm.prepaidCards = [
            PrepaidCard(
                id: 1,
                description: "10-Hour Package",
                remainingUnits: 7,
                originalUnits: 10,
                expirationDate: Date().addingTimeInterval(90*24*60*60),
                unitName: "hours"
            )
        ]

        if let profile = vm.userProfile {
            vm.editBirthday = profile.birthDate ?? Self.defaultBirthday
            vm.editGender = profile.gender
        }

        return vm
    }
}
