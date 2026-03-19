//
//  HomeTabView.swift
//  LoftGolfApp
//
//  Created by ZhiYue Wang on 10/14/25.
//

import SwiftUI
import CoreLocation

struct HomeTabView: View {
    @StateObject private var viewModel: HomeViewModel
    @State private var showNewBooking = false
    @State private var freeHours: Int = 0
    @State private var prepaidCards: [USPrepayServiceCustomer] = []
    let authToken: String?
    @Binding var selectedTab: Int

    init(authToken: String? = nil,
         selectedTab: Binding<Int> = .constant(0),
         viewModel: HomeViewModel? = nil) {
        self.authToken = authToken
        self._selectedTab = selectedTab
        _viewModel = StateObject(wrappedValue: viewModel ?? HomeViewModel())
    }

    private func loadPrepaidCards() {
        guard let token = authToken else {
            print("❌ HomeTabView: authToken is nil")
            return
        }

        PrepaidCreditsService.fetchPrepaidCards(authToken: token) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let cards):
                    self.prepaidCards = cards.filter { $0.RemainingUnits > 0 }
                    self.freeHours = self.prepaidCards.reduce(0) { $0 + $1.RemainingUnits }
                case .failure(let err):
                    print("❌ Prepaid cards error:", err)
                    self.prepaidCards = []
                    self.freeHours = 0
                }
            }
        }
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

                Image("image2")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 900)
                    .opacity(0.4)
                    .offset(y: 10)
                    .allowsHitTesting(false)

                ScrollView {
                    VStack(spacing: 20) {
                        WelcomeHeader(
                            greeting: viewModel.greeting,
                            customerName: viewModel.customerName ?? "Golfer"
                        )

                        RewardsCard(
                            progressPoints: viewModel.currentProgressPoints,
                            anytimeCredits: viewModel.anytimeCredits,
                            onViewRewards: {
                                selectedTab = 1
                            }
                        )

                        PrepaidCardsSection(cards: prepaidCards)

                        if viewModel.hasActiveAppointment {
                            let bay = viewModel.activeBayNumber
                            OpenDoorButton(bayId: bay) { viewModel.openDoor(bayId: bay) }
                        }

                        QuickBookCard { showNewBooking = true }

                        UpcomingAppointmentsSection(
                            appointments: viewModel.upcomingAppointments,
                            isLoading: viewModel.isLoading,
                            authToken: authToken
                        )

                        if viewModel.hasActiveAppointment {
                            InVenueControlsCard()
                        }

                        Spacer(minLength: 250)
                    }
                    .padding(.horizontal)
                    .padding(.top, 50)
                }
            }

            .frame(maxWidth: .infinity)
            .frame(minHeight: UIScreen.main.bounds.height, alignment: .top)
            .navigationBarHidden(true)
            .refreshable {
                await viewModel.loadData()
            }
            .task {
                if let token = authToken {
                    viewModel.setAuthToken(token)
                    loadPrepaidCards()
                }
                await viewModel.loadData()
            }
            .sheet(isPresented: $showNewBooking) {
                NewBookingView(authToken: authToken) {
                    Task {
                        await viewModel.loadData()
                    }
                }
            }
        }
    }
}

//Welcome Header
struct WelcomeHeader: View {
    let greeting: String
    let customerName: String

    var body: some View {
        HStack {
            Image("image2")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 70)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.subheadline)
                    .foregroundStyle(.gray)

                Text(customerName)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }

            Spacer()
        }
        .padding(.vertical, 13)
    }
}

struct RewardsCard: View {
    let progressPoints: Int
    let anytimeCredits: Int
    let onViewRewards: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gift.fill")
                    .foregroundStyle(.green)

                Text("Loft Golf Rewards")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    onViewRewards()
                } label: {
                    Text("View Rewards")
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }

            Text("\(progressPoints) pts")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.green)

            Divider()
                .background(Color.gray.opacity(0.3))

            HStack {
                Text("\(anytimeCredits) credits")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.gray)

                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.15))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.9), lineWidth: 1)
        )
    }
}

struct PrepaidCardsSection: View {
    let cards: [USPrepayServiceCustomer]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(cards, id: \.Id) { card in
                PrepaidCardRow(card: card)
            }
        }
    }
}

struct PrepaidCardRow: View {
    let card: USPrepayServiceCustomer

    private var title: String {
        if let name = card.UnitName, !name.isEmpty { return name }
        return "Prepaid Credit"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "gift.fill")
                    .foregroundStyle(.green)

                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()
            }

            Text("\(card.RemainingUnits)")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.green)

            Text("Hours left")
                .font(.subheadline)
                .foregroundStyle(.gray)
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.15))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.9), lineWidth: 1)
        )
    }
}

struct OpenDoorButton: View {
    let bayId: Int
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button {
            isPressed = true
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isPressed = false
            }
        } label: {
            HStack {
                Image(systemName: isPressed ? "door.left.hand.open" : "door.left.hand.closed")
                    .font(.title2)

                Text(isPressed ? "Opening..." : "Open Bay \(bayId) Door")
                    .font(.headline.bold())
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .cornerRadius(12)
        }
        .disabled(isPressed)
    }
}

//Quick Book Card
struct QuickBookCard: View {
    let onBookTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Book Now")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(.white)

            Button(action: onBookTap) {
                HStack {
                    Image(systemName: "figure.golf")
                        .font(.title2)

                    Text("Reserve Simulator")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.15))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.9), lineWidth: 1)
        )
    }
}

//Service Type Button
struct ServiceTypeButton: View {
    let icon: String
    let title: String
    var isSelected: Bool = false
    var isDisabled: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)

            Text(title)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(isSelected ? .black : (isDisabled ? .gray : .white))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(isSelected ? Color.green : Color(.systemGray6).opacity(0.3))
        .cornerRadius(12)
        .opacity(isDisabled ? 0.5 : 1)
    }
}

//Upcoming Appointments Section
struct UpcomingAppointmentsSection: View {
    let appointments: [Appointment]
    let isLoading: Bool
    let authToken: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                if !appointments.isEmpty {
                    NavigationLink {
                        BookingsTabView(authToken: authToken)
                    } label: {
                        Text("See All")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    }
                }
            }

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                    Spacer()
                }
                .padding(.vertical, 30)
            } else if appointments.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 60))
                        .foregroundStyle(.green)

                    Text("No upcoming reservations")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                ForEach(appointments.prefix(3)) { appointment in
                    UpcomingAppointmentCard(appointment: appointment)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.15))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.9), lineWidth: 1)
        )
    }
}

//Upcoming Appointment Card
struct UpcomingAppointmentCard: View {
    let appointment: Appointment

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 2) {
                Text(monthString)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.green)

                Text(dayString)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            .frame(width: 50)
            .padding(.vertical, 8)
            .background(Color(.systemGray6).opacity(0.5))
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(appointment.Description ?? "Simulator Rental")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(timeString)
                        .font(.caption)
                }
                .foregroundStyle(.gray)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.gray)
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(12)
    }

    private var monthString: String {
        guard let startTime = appointment.StartTime,
              let date = UScheduleClient.parseAPIDate(startTime) else {
            return "---"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date).uppercased()
    }

    private var dayString: String {
        guard let startTime = appointment.StartTime,
              let date = UScheduleClient.parseAPIDate(startTime) else {
            return "--"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private var timeString: String {
        guard let startTime = appointment.StartTime,
              let date = UScheduleClient.parseAPIDate(startTime) else {
            return "--:--"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

//In-Venue Controls Card
struct InVenueControlsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(.green)

                Text("Bay Controls")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Text("In-Venue")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(4)
            }

            HStack(spacing: 12) {
                InVenueControlButton(icon: "lightbulb.fill", title: "Lights")
                InVenueControlButton(icon: "thermometer.medium", title: "Climate")
                InVenueControlButton(icon: "tv.fill", title: "TV")
                InVenueControlButton(icon: "plus.circle.fill", title: "Extend")
            }

            Text("Controls available during your appointment")
                .font(.caption)
                .foregroundStyle(.gray)
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.15))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
}

//In-Venue Control Button
struct InVenueControlButton: View {
    let icon: String
    let title: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.white)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(10)
    }
}

@MainActor
class HomeViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var customerName: String?
    @Published var upcomingAppointments: [Appointment] = []
    @Published var isLoading = false
    @Published var hasActiveAppointment = false
    @Published var isNearVenue = false
    @Published var currentProgressPoints = 0
    @Published var anytimeCredits = 0

    private let client = UScheduleClient()
    private var authToken: String?

    private let locationManager = CLLocationManager()
    private let venueLocation   = CLLocation(latitude: 33.3954, longitude: -111.9256)
    private let geofenceRadius: CLLocationDistance = 150  // meters

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    func setAuthToken(_ token: String) {
        self.authToken = token
    }

    func loadData() async {
        guard let token = authToken else { return }

        isLoading = true

        do {
            if Task.isCancelled { return }
            let customer = try await client.customer(authToken: token)
            self.customerName = customer.FirstName
            let loyaltyPoints = customer.LoyaltyPointTotal ?? 0
            self.currentProgressPoints = loyaltyPoints % 50
            self.anytimeCredits = loyaltyPoints / 50

            if Task.isCancelled { return }
            let appointments = try await client.appointments(authToken: token)

            self.upcomingAppointments = appointments
                .filter { appointment in
                    guard let startTimeStr = appointment.StartTime,
                          let startTime = UScheduleClient.parseAPIDate(startTimeStr) else {
                        return false
                    }
                    let now = Date()
                    if let endStr = appointment.EndTime,
                       let endTime = UScheduleClient.parseAPIDate(endStr) {
                        return endTime > now && appointment.StatusID == 1
                    }
                    return startTime > now && appointment.StatusID == 1
                }
                .sorted { a, b in
                    guard let aTime = UScheduleClient.parseAPIDate(a.StartTime),
                          let bTime = UScheduleClient.parseAPIDate(b.StartTime) else {
                        return false
                    }
                    return aTime < bTime
                }

            // Trigger location check — delegate will set hasActiveAppointment
            locationManager.requestWhenInUseAuthorization()
            locationManager.requestLocation()

            if !Task.isCancelled {
                isLoading = false
            }
        } catch {
            print("Failed to load home data: \(error)")
            if !Task.isCancelled {
                isLoading = false
            }
        }
    }

    private func checkForActiveAppointment(_ appointments: [Appointment]) -> Bool {
        let now = Date()

        for appointment in appointments {
            guard let startTimeStr = appointment.StartTime,
                  let startTime = UScheduleClient.parseAPIDate(startTimeStr),
                  appointment.StatusID == 1 else {
                continue
            }

            var endTime: Date
            if let endStr = appointment.EndTime,
               let end = UScheduleClient.parseAPIDate(endStr) {
                endTime = end
            } else {
                endTime = startTime.addingTimeInterval(60 * 60)
            }

            let bufferStart = startTime.addingTimeInterval(-15 * 60)

            if now >= bufferStart && now <= endTime {
                return true
            }
        }

        return false
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let distance = loc.distance(from: venueLocation)
        Task { @MainActor in
            self.isNearVenue = distance <= geofenceRadius
            self.hasActiveAppointment = self.isNearVenue && self.checkForActiveAppointment(self.upcomingAppointments)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Location unavailable — require geofence, so hide the door button
        Task { @MainActor in
            self.isNearVenue = false
            self.hasActiveAppointment = false
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            // Permission denied — hide door button until location is granted
            Task { @MainActor in
                self.isNearVenue = false
                self.hasActiveAppointment = false
            }
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    // MARK: - Bay detection

    var activeBayNumber: Int {
        let now = Date()
        for appt in upcomingAppointments {
            guard let startStr = appt.StartTime,
                  let startTime = UScheduleClient.parseAPIDate(startStr),
                  appt.StatusID == 1 else { continue }
            let endTime: Date
            if let endStr = appt.EndTime, let end = UScheduleClient.parseAPIDate(endStr) {
                endTime = end
            } else {
                endTime = startTime.addingTimeInterval(3600)
            }
            let bufferStart = startTime.addingTimeInterval(-15 * 60)
            if now >= bufferStart && now <= endTime {
                if appt.ResourceUnitID == DoorConfig.bay1ResourceUnitId { return 1 }
                return 2
            }
        }
        return 1
    }

    // MARK: - Door control

    func openDoor(bayId: Int) {
        Task {
            do {
                let jwt = try await fetchAvigilonJWT()
                let urlStr = "https://api.openpath.com/api/v1/orgs/\(DoorConfig.orgId)/entries/\(DoorConfig.entryId)/remoteUnlocks"
                guard let url = URL(string: urlStr) else { return }
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue(jwt, forHTTPHeaderField: "Authorization")
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                URLSession.shared.dataTask(with: req).resume()
            } catch {
                print("Door open failed: \(error)")
            }
        }
    }

    // Returns a valid Avigilon Alta JWT, re-logging in only when the cached token has expired
    private func fetchAvigilonJWT() async throws -> String {
        if AvigilonTokenCache.isValid, let cached = AvigilonTokenCache.jwt {
            return cached
        }

        guard let url = URL(string: "https://api.openpath.com/auth/login") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "email": DoorConfig.botEmail,
            "password": DoorConfig.botPassword
        ])

        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json  = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let inner = json["data"] as? [String: Any],
              let token = inner["token"] as? String else {
            throw URLError(.badServerResponse)
        }

        AvigilonTokenCache.jwt = token
        if let expiresAtStr = inner["expiresAt"] as? String {
            AvigilonTokenCache.expiresAt = ISO8601DateFormatter().date(from: expiresAtStr)
        }
        return token
    }
}

// MARK: - Preview Helpers
@MainActor
func mockHomeVM(points: Int) -> HomeViewModel {
    let vm = HomeViewModel()
    vm.customerName = "Mattias"
    vm.currentProgressPoints = points % 50
    vm.anytimeCredits = points / 50
    return vm
}

#Preview("0 Points") {
    HomeTabView(
        authToken: nil,
        selectedTab: .constant(0),
        viewModel: mockHomeVM(points: 0)
    )
    .preferredColorScheme(.dark)
}

#Preview("100 Points → 2 Credits") {
    HomeTabView(
        authToken: nil,
        selectedTab: .constant(0),
        viewModel: mockHomeVM(points: 100)
    )
    .preferredColorScheme(.dark)
}

#Preview("125 Points → Progress") {
    HomeTabView(
        authToken: nil,
        selectedTab: .constant(0),
        viewModel: mockHomeVM(points: 125)
    )
    .preferredColorScheme(.dark)
}
