//
//  Bookingstabview.swift
//  LoftGolfApp
//
//  Created by ZhiYue Wang on 1/27/26.
//

import SwiftUI

struct BookingsTabView: View {
    @StateObject private var viewModel = BookingViewModel()
    @State private var showNewBooking = false
    
    let authToken: String?
    
    init(authToken: String? = nil) {
        self.authToken = authToken
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.upcomingAppointments.isEmpty {
                    ProgressView("Loading...")
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Quick Book Button
                            quickBookButton
                            
                            // Upcoming Appointments
                            upcomingSection
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Bookings")
            .refreshable {
                await viewModel.loadAppointments()
            }
            .task {
                if let token = authToken {
                    viewModel.setAuthToken(token)
                }
                await viewModel.loadAppointments()
            }
            .sheet(isPresented: $showNewBooking) {
                NewBookingView(authToken: authToken) {
                    // On booking complete, refresh list
                    Task {
                        await viewModel.loadAppointments()
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
        }
    }
    
    //Quick Book Button
    private var quickBookButton: some View {
        Button {
            showNewBooking = true
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.green)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Book a Session")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text("Reserve your golf simulator time")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    //Upcoming Section
    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming Reservations")
                .font(.title3.bold())
                .foregroundStyle(.primary)
            
            if viewModel.upcomingAppointments.isEmpty {
                emptyStateView
            } else {
                ForEach(viewModel.upcomingAppointments) { appointment in
                    AppointmentCard(
                        appointment: appointment,
                        onCancel: {
                            Task {
                                await viewModel.cancelAppointment(appointment.Id)
                            }
                        }
                    )
                }
            }
        }
    }
    
    //Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 50))
                .foregroundStyle(.gray)
            
            Text("No Upcoming Reservations")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Book a session to get started!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button {
                showNewBooking = true
            } label: {
                Text("Book Now")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.black)
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}

//Appointment Card
struct AppointmentCard: View {
    let appointment: Appointment
    let onCancel: () -> Void
    
    @State private var showCancelAlert = false
    
    private var startDate: Date? {
        UScheduleClient.parseAPIDate(appointment.StartTime)
    }
    
    private var endDate: Date? {
        UScheduleClient.parseAPIDate(appointment.EndTime)
    }
    
    private var isToday: Bool {
        guard let date = startDate else { return false }
        return Calendar.current.isDateInToday(date)
    }
    
    private var canCancel: Bool {
        guard let date = startDate else { return false }
        // Can cancel if more than 24 hours away
        return date.timeIntervalSinceNow > 24 * 60 * 60
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with date badge
            HStack(alignment: .top) {
                // Date badge
                if let date = startDate {
                    VStack(spacing: 2) {
                        Text(date.formatted(.dateTime.month(.abbreviated)))
                            .font(.caption.bold())
                            .foregroundStyle(isToday ? .white : .secondary)
                        
                        Text(date.formatted(.dateTime.day()))
                            .font(.title2.bold())
                            .foregroundStyle(isToday ? .white : .primary)
                    }
                    .frame(width: 50, height: 50)
                    .background(isToday ? Color.green : Color(.systemGray5))
                    .cornerRadius(10)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(appointment.Description ?? "Golf Simulator")
                        .font(.headline)
                    
                    if let date = startDate {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption)
                            Text(date.formatted(.dateTime.hour().minute()))
                            
                            if let end = endDate {
                                Text("- \(end.formatted(.dateTime.hour().minute()))")
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Status badge
                statusBadge
            }
            
            // Price and actions
            HStack {
                if let price = appointment.Price {
                    Text(String(format: "$%.2f", price))
                        .font(.headline)
                        .foregroundStyle(.green)
                }
                
                Spacer()
                
                if appointment.StatusID == 1 && canCancel {
                    Button {
                        showCancelAlert = true
                    } label: {
                        Text("Cancel")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        .alert("Cancel Reservation", isPresented: $showCancelAlert) {
            Button("Keep Reservation", role: .cancel) {}
            Button("Cancel Reservation", role: .destructive) {
                onCancel()
            }
        } message: {
            Text("Are you sure you want to cancel this reservation? This cannot be undone.")
        }
    }
    
    private var statusBadge: some View {
        let status = AppointmentStatusType(rawValue: appointment.StatusID ?? 1) ?? .active
        
        let (text, color): (String, Color) = {
            switch status {
            case .active: return ("Confirmed", .green)
            case .canceled: return ("Canceled", .red)
            case .rescheduled: return ("Rescheduled", .orange)
            case .tentative: return ("Pending", .yellow)
            default: return ("Unknown", .gray)
            }
        }()
        
        return Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(6)
    }
}

#Preview {
    BookingsTabView(authToken: nil)
}
