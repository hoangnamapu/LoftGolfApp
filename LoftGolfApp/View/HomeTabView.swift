//
//  HomeTabView.swift
//  LoftGolfApp
//
//  Created by ZhiYue Wang on 10/14/25.
//

import SwiftUI

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

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
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
                    for card in cards {
                        print("PREPAID CARD -> id:", card.Id)
                        print("name:", card.UnitName ?? "nil")
                        print("remaining units:", card.RemainingUnits)
                    }

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

                        QuickBookCard { selectedTab = 2 }

                        UpcomingAppointmentsSection(
                            appointments: viewModel.upcomingAppointments,
                            isLoading: viewModel.isLoading,
                            authToken: authToken,
                            viewModel: viewModel
                        )

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
                    print("HOME TOKEN:", token)
                    viewModel.setAuthToken(token)
                    loadPrepaidCards()
                }
                await viewModel.loadData()
            }
            .alert("Error", isPresented: errorAlertBinding) {
                Button("OK", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "Something went wrong.")
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

        }
        .padding()
        .background(Color(.systemGray6).opacity(0.15))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

struct PrepaidCardsSection: View {
    let cards: [USPrepayServiceCustomer]

    private var anytimeUnits: Int {
        units(matching: ["anytime", "any time"], fallbackIndex: 0)
    }

    private var weekdayUnits: Int {
        units(matching: ["weekday", "week day"], fallbackIndex: 1)
    }

    private var hasNamedCreditBuckets: Bool {
        cards.contains { card in
            let label = card.displayName.lowercased()
            return label.contains("anytime")
                || label.contains("any time")
                || label.contains("weekday")
                || label.contains("week day")
        }
    }

    private func units(matching keywords: [String], fallbackIndex: Int) -> Int {
        let matchedCards = cards.filter { card in
            let label = card.displayName.lowercased()
            return keywords.contains { label.contains($0) }
        }

        if !matchedCards.isEmpty {
            return matchedCards.reduce(0) { $0 + $1.RemainingUnits }
        }

        if !hasNamedCreditBuckets, cards.indices.contains(fallbackIndex) {
            return cards[fallbackIndex].RemainingUnits
        }

        return 0
    }

    var body: some View {
        if cards.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "creditcard.fill")
                        .foregroundStyle(.green)
                    
                    Text("Prepaid Credits")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    Spacer()
                }
                
                HStack(spacing: 20) {
                    
                    // Anytime
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(anytimeUnits)")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(.green)
                        
                        Text("Anytime")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                    
                    // Weekday
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(weekdayUnits)")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(.green)
                        
                        Text("Weekday")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(Color(.systemGray6).opacity(0.15))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

struct OpenDoorButton: View {
    var isEnabled: Bool = true
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button {
            guard isEnabled else { return }
            isPressed = true
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isPressed = false
            }
        } label: {
            HStack {
                Image(systemName: isPressed ? "door.left.hand.open" : "door.left.hand.closed")
                    .font(.title2)

                Text(isPressed ? "Opening..." : "Open Door")
                    .font(.headline.bold())
            }
            .foregroundStyle(isEnabled ? .black : .white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isEnabled ? Color.green : Color.gray.opacity(0.4))
            .cornerRadius(12)
        }
        .disabled(isPressed || !isEnabled)
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
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
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
    @ObservedObject var viewModel: HomeViewModel

    @State private var showAppointmentsSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(.white)

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
                    VStack(spacing: 6) {
                        AppointmentCard(
                            appointment: appointment,
                            onCancel: {
                                Task { await viewModel.cancelAppointment(appointment) }
                            }
                        )
                        OpenDoorButton(
                            isEnabled: viewModel.isInActivationWindow(for: appointment)
                        ) {
                            showAppointmentsSheet = true
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.15))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .sheet(isPresented: $showAppointmentsSheet) {
            BookingWebView(
                authToken: authToken,
                showNavBar: true,
                targetURL: "https://clients.uschedule.com/loftgolfstudios/customerprofile/appointments",
                title: "My Appointments",
                showDismissButton: true
            )
        }
    }
}

@MainActor
class HomeViewModel: ObservableObject {
    @Published var customerName: String?
    @Published var upcomingAppointments: [Appointment] = []
    @Published var isLoading = false
    @Published var currentProgressPoints = 0
    @Published var anytimeCredits = 0
    @Published var errorMessage: String?

    private let client = UScheduleClient()
    private var authToken: String?

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
            self.currentProgressPoints = loyaltyPoints
            self.anytimeCredits = 0

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

    // MARK: - Activation window

    func isInActivationWindow(for appointment: Appointment) -> Bool {
        let now = Date()
        guard let startStr = appointment.StartTime,
              let startTime = UScheduleClient.parseAPIDate(startStr),
              appointment.StatusID == 1 else { return false }
        let endTime = UScheduleClient.parseAPIDate(appointment.EndTime)
                      ?? startTime.addingTimeInterval(3600)
        let bufferStart = startTime.addingTimeInterval(-15 * 60)
        return now >= bufferStart && now <= endTime
    }

    func cancelAppointment(_ appointment: Appointment) async {
        guard let token = authToken else {
            errorMessage = "Not authenticated"
            return
        }

        errorMessage = nil

        do {
            _ = try await client.cancelAppointment(authToken: token, id: appointment.Id)
            await loadData()
        } catch let error as USError {
            switch error {
            case .http(400, let message):
                let detail = message.isEmpty ? "The reservation could not be cancelled." : message
                errorMessage = "Cancellation failed: \(detail)"
            case .http(let code, let message):
                errorMessage = "Cancellation failed (error \(code)): \(message)"
            default:
                errorMessage = "Cancellation failed: \(error.localizedDescription)"
            }
        } catch {
            errorMessage = "Cancellation failed: \(error.localizedDescription)"
        }
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
