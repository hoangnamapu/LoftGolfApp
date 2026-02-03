//
//  HomeTabView.swift
//  LoftGolfApp
//
//  Created by ZhiYue Wang on 10/14/25.
//

import SwiftUI

struct HomeTabView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var showNewBooking = false
    
    let authToken: String?
    
    init(authToken: String? = nil) {
        self.authToken = authToken
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    //Welcome Header
                    WelcomeHeader(
                        greeting: viewModel.greeting,
                        customerName: viewModel.customerName ?? "Golfer"
                    )
                    
                    //Rewards Card (Placeholder)
                    RewardsCard()
                    
                    //Open Door Button (shows when in-venue during appointment)
                    if viewModel.hasActiveAppointment {
                        OpenDoorButton {
                            viewModel.openDoor()
                        }
                    }
                    
                    //Quick Book Section
                    QuickBookCard {
                        showNewBooking = true
                    }
                    
                    //Upcoming Appointments
                    UpcomingAppointmentsSection(
                        appointments: viewModel.upcomingAppointments,
                        isLoading: viewModel.isLoading,
                        authToken: authToken
                    )
                    
                    //In-Venue Controls (shows when in-venue during appointment)
                    if viewModel.hasActiveAppointment {
                        InVenueControlsCard()
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal)
                .padding(.top, 10)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarHidden(true)
            .refreshable {
                await viewModel.loadData()
            }
            .task {
                if let token = authToken {
                    viewModel.setAuthToken(token)
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
            // Logo from Assets
            Image("LoftGolfLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
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
        .padding(.vertical, 10)
    }
}

//Rewards Card (Placeholder)
struct RewardsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gift.fill")
                    .foregroundStyle(.green)
                
                Text("Loft Golf Rewards")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button {
                    // Info action
                } label: {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(.gray)
                }
            }
            
            Text("0")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.green)
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            HStack {
                Text("Points")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                
                Spacer()
                
                Text("Coming Soon")
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
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

//Open Door Button (Placeholder)
struct OpenDoorButton: View {
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
                
                Text(isPressed ? "Opening..." : "Open Door")
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
                .font(.headline)
                .foregroundStyle(.white)
            
            // Reserve button
            Button(action: onBookTap) {
                HStack {
                    Image(systemName: "figure.golf")
                        .font(.title2)
                    
                    Text("Reserve Simulator")
                        .font(.headline.bold())
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming")
                    .font(.headline)
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
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 40))
                        .foregroundStyle(.gray)
                    
                    Text("No upcoming reservations")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                // Appointment cards
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
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

//Upcoming Appointment Card
struct UpcomingAppointmentCard: View {
    let appointment: Appointment
    
    var body: some View {
        HStack(spacing: 16) {
            // Date badge
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
            
            // Details
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

//In-Venue Controls Card (Placeholder)
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
            
            // Control buttons
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

//ome ViewModel
@MainActor
class HomeViewModel: ObservableObject {
    @Published var customerName: String?
    @Published var upcomingAppointments: [Appointment] = []
    @Published var isLoading = false
    @Published var hasActiveAppointment = false  // For in-venue features
    
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
            // Load customer info
            if Task.isCancelled { return }
            let customer = try await client.customer(authToken: token)
            self.customerName = customer.FirstName
            
            // Load appointments
            if Task.isCancelled { return }
            let appointments = try await client.appointments(authToken: token)
            
            // Filter upcoming appointments (future + active status)
            self.upcomingAppointments = appointments
                .filter { appointment in
                    guard let startTimeStr = appointment.StartTime,
                          let startTime = UScheduleClient.parseAPIDate(startTimeStr) else {
                        return false
                    }
                    // Include appointments that are happening now or in the future
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
            
            // Check if there's an active appointment (for in-venue features)
            // TODO: Add geofencing check
            self.hasActiveAppointment = checkForActiveAppointment(appointments)
            
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
    
    //Check if user has an appointment happening right now
    private func checkForActiveAppointment(_ appointments: [Appointment]) -> Bool {
        let now = Date()
        
        for appointment in appointments {
            guard let startTimeStr = appointment.StartTime,
                  let startTime = UScheduleClient.parseAPIDate(startTimeStr),
                  appointment.StatusID == 1 else {
                continue
            }
            
            //Try to get end time from EndTime field, or calculate from duration
            var endTime: Date
            if let endStr = appointment.EndTime,
               let end = UScheduleClient.parseAPIDate(endStr) {
                endTime = end
            } else {
                // Default to 1 hour if no end time
                endTime = startTime.addingTimeInterval(60 * 60)
            }
            
            // Check if now is within the appointment window
            // Add 15 min buffer before start for early arrival
            let bufferStart = startTime.addingTimeInterval(-15 * 60)
            
            if now >= bufferStart && now <= endTime {
                return true
            }
        }
        
        return false
    }
    
    func openDoor() {
        // TODO: Implement door control via environment management API
        print("Opening door...")
    }
}

#Preview {
    HomeTabView(authToken: nil)
}
