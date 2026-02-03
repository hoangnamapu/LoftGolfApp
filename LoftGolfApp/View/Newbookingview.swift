//
//  NewBookingView.swift
//  LoftGolfApp
//
//  Created by ZhiYue Wang on 1/27/26.
//

import SwiftUI

struct NewBookingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = BookingViewModel()
    
    let authToken: String?
    let onComplete: () -> Void
    
    init(authToken: String?, onComplete: @escaping () -> Void = {}) {
        self.authToken = authToken
        self.onComplete = onComplete
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Progress indicator
                    BookingProgressView(currentStep: viewModel.currentStep)
                        .padding()
                    
                    // Content - Flow: Service -> Guests -> Bay -> DateTime -> Confirm
                    TabView(selection: $viewModel.currentStep) {
                        SelectServiceView(viewModel: viewModel)
                            .tag(BookingStep.selectService)
                        
                        SelectGuestsView(viewModel: viewModel)
                            .tag(BookingStep.selectGuests)
                        
                        SelectBayView(viewModel: viewModel)
                            .tag(BookingStep.selectBay)
                        
                        SelectDateTimeView(viewModel: viewModel)
                            .tag(BookingStep.selectDateTime)
                        
                        ConfirmBookingView(viewModel: viewModel)
                            .tag(BookingStep.confirmation)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut, value: viewModel.currentStep)
                }
            }
            .navigationTitle("New Reservation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                if let token = authToken {
                    viewModel.setAuthToken(token)
                }
                await viewModel.loadInitialData()
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
            .onChange(of: viewModel.showBookingSuccess) { success in
                if success {
                    onComplete()
                    dismiss()
                }
            }
        }
    }
}

//Progress View
struct BookingProgressView: View {
    let currentStep: BookingStep
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(BookingStep.allCases, id: \.rawValue) { step in
                VStack(spacing: 4) {
                    Circle()
                        .fill(step.rawValue <= currentStep.rawValue ? Color.black : Color.gray.opacity(0.3))
                        .frame(width: 10, height: 10)
                    
                    Text(step.title)
                        .font(.caption2)
                        .foregroundStyle(step.rawValue <= currentStep.rawValue ? .primary : .secondary)
                }
                
                if step != BookingStep.allCases.last {
                    Rectangle()
                        .fill(step.rawValue < currentStep.rawValue ? Color.black : Color.gray.opacity(0.3))
                        .frame(height: 2)
                }
            }
        }
    }
}

//Step 1: Select Service
struct SelectServiceView: View {
    @ObservedObject var viewModel: BookingViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Location selector (if multiple)
                if viewModel.locations.count > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(.headline)
                        
                        ForEach(viewModel.locations, id: \.Id) { location in
                            LocationRow(
                                location: location,
                                isSelected: viewModel.selectedLocation?.Id == location.Id
                            ) {
                                viewModel.selectedLocation = location
                            }
                        }
                    }
                }
                
                // Service selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select Service")
                        .font(.headline)
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else if viewModel.services.isEmpty {
                        Text("No services available")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ForEach(viewModel.services, id: \.Id) { service in
                            ServiceRow(
                                service: service,
                                isSelected: viewModel.selectedService?.Id == service.Id
                            ) {
                                viewModel.selectedService = service
                                if let length = service.ServiceLength {
                                    viewModel.selectedDuration = length
                                }
                            }
                        }
                    }
                }
                
                // Duration selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("Duration")
                        .font(.headline)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.durationOptions, id: \.self) { duration in
                                DurationChip(
                                    duration: duration,
                                    isSelected: viewModel.selectedDuration == duration,
                                    formatDuration: viewModel.formatDuration
                                ) {
                                    viewModel.selectedDuration = duration
                                }
                            }
                        }
                    }
                }
                
                Spacer(minLength: 100)
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                viewModel.nextStep()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.canProceedToGuests ? Color.black : Color.gray)
                    .cornerRadius(12)
            }
            .disabled(!viewModel.canProceedToGuests)
            .padding()
            .background(Color(.systemGroupedBackground))
        }
    }
}

//Step 2: Select Guests
struct SelectGuestsView: View {
    @ObservedObject var viewModel: BookingViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How Many People?")
                        .font(.headline)
                    
                    Text("Select the number of guests for your session")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                // Guest count selector with large buttons
                VStack(spacing: 16) {
                    HStack {
                        Button {
                            if viewModel.groupSize > 1 {
                                viewModel.groupSize -= 1
                                viewModel.selectedResourceUnit = nil  // Reset bay selection when count changes
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(viewModel.groupSize > 1 ? .black : .gray)
                        }
                        .disabled(viewModel.groupSize <= 1)
                        
                        Spacer()
                        
                        Text("\(viewModel.groupSize)")
                            .font(.system(size: 72, weight: .bold))
                        
                        Spacer()
                        
                        Button {
                            viewModel.groupSize += 1
                            viewModel.selectedResourceUnit = nil  // Reset bay selection when count changes
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.black)
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    Text(viewModel.groupSize == 1 ? "person" : "people")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 30)
                
                // Warning for 9+ guests - cannot accommodate
                if viewModel.cannotAccommodate {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("We cannot accommodate more than 8 guests in a single bay. Please contact us for group bookings.")
                            .font(.subheadline)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Bay capacity info based on group size
                if !viewModel.cannotAccommodate {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bay Options")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        
                        if viewModel.groupSize <= 4 {
                            Label("Bay 1 (up to 8 guests) or Bay 2 (up to 4 guests)", systemImage: "checkmark.circle")
                                .font(.subheadline)
                                .foregroundStyle(.green)
                        } else {
                            Label("Bay 1 only (up to 8 guests)", systemImage: "info.circle")
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
                
                Spacer(minLength: 100)
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button {
                    viewModel.previousStep()
                } label: {
                    Text("Back")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .cornerRadius(12)
                }
                
                Button {
                    viewModel.nextStep()
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.canProceedToBay ? Color.black : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(!viewModel.canProceedToBay)
            }
            .padding()
            .background(Color(.systemGroupedBackground))
        }
    }
}

//Step 3: Select Bay
struct SelectBayView: View {
    @ObservedObject var viewModel: BookingViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select Bay")
                        .font(.headline)
                    
                    Text("Choose your preferred bay")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                if viewModel.availableBaysForGroupSize.isEmpty {
                    // No bays available - this shouldn't happen due to validation
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.orange)
                        
                        Text("No bays available for your group size")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ForEach(viewModel.availableBaysForGroupSize) { unit in
                        BaySelectionRow(
                            unit: unit,
                            isSelected: viewModel.selectedResourceUnit?.Id == unit.Id,
                            groupSize: viewModel.groupSize
                        ) {
                            viewModel.selectedResourceUnit = unit
                        }
                    }
                }
                
                Spacer(minLength: 100)
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button {
                    viewModel.previousStep()
                } label: {
                    Text("Back")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .cornerRadius(12)
                }
                
                Button {
                    viewModel.nextStep()
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.canProceedToDateTime ? Color.black : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(!viewModel.canProceedToDateTime)
            }
            .padding()
            .background(Color(.systemGroupedBackground))
        }
    }
}

//Step 4: Select Date & Time
struct SelectDateTimeView: View {
    @ObservedObject var viewModel: BookingViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Date picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select Date")
                        .font(.headline)
                    
                    DatePicker(
                        "Date",
                        selection: $viewModel.selectedDate,
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .onChange(of: viewModel.selectedDate) { _ in
                        viewModel.selectedTimeSlot = nil
                        Task {
                            await viewModel.loadAvailability()
                        }
                    }
                }
                
                // Time slots
                VStack(alignment: .leading, spacing: 8) {
                    Text("Available Times")
                        .font(.headline)
                    
                    if viewModel.isLoading {
                        ProgressView("Loading available times...")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else if viewModel.availableSlots.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "clock.badge.exclamationmark")
                                .font(.system(size: 40))
                                .foregroundStyle(.gray)
                            
                            Text("No times available")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Text("Try selecting a different date")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        // Time slots showing start - end time
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(viewModel.availableSlots) { slot in
                                TimeSlotChip(
                                    slot: slot,
                                    isSelected: viewModel.selectedTimeSlot?.id == slot.id,
                                    duration: viewModel.selectedDuration
                                ) {
                                    viewModel.selectedTimeSlot = slot
                                }
                            }
                        }
                    }
                }
                
                Spacer(minLength: 100)
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button {
                    viewModel.previousStep()
                } label: {
                    Text("Back")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .cornerRadius(12)
                }
                
                Button {
                    Task {
                        await viewModel.loadPricing()
                    }
                    viewModel.nextStep()
                } label: {
                    Text("Review")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.canConfirm ? Color.black : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(!viewModel.canConfirm)
            }
            .padding()
            .background(Color(.systemGroupedBackground))
        }
        .task {
            await viewModel.loadAvailability()
        }
    }
}

//Step 5: Confirmation
struct ConfirmBookingView: View {
    @ObservedObject var viewModel: BookingViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Summary card
                VStack(alignment: .leading, spacing: 16) {
                    Text("Reservation Summary")
                        .font(.headline)
                    
                    Divider()
                    
                    SummaryRow(label: "Service", value: viewModel.selectedService?.Description ?? "—")
                    SummaryRow(label: "Date", value: formatDate(viewModel.selectedDate))
                    SummaryRow(label: "Time", value: formatTimeSlot(viewModel.selectedTimeSlot, duration: viewModel.selectedDuration))
                    SummaryRow(label: "Duration", value: viewModel.formatDuration(viewModel.selectedDuration))
                    SummaryRow(label: "Guests", value: "\(viewModel.groupSize)")
                    
                    if let unit = viewModel.selectedResourceUnit {
                        SummaryRow(label: "Bay", value: unit.NickName ?? unit.Description)
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Total")
                            .font(.headline)
                        Spacer()
                        Text(viewModel.formatPrice(viewModel.estimatedPrice))
                            .font(.title2.bold())
                            .foregroundStyle(.green)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                
                // Notes
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes (Optional)")
                        .font(.headline)
                    
                    TextField("Any special requests?", text: $viewModel.notes, axis: .vertical)
                        .lineLimit(3...6)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                }
                
                // Payment info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Payment")
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: "building.columns")
                            .foregroundStyle(.secondary)
                        Text("Pay at location")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
                
                Spacer(minLength: 100)
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                Button {
                    Task {
                        await viewModel.confirmBooking()
                    }
                } label: {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Confirm Reservation")
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
                }
                .disabled(viewModel.isLoading)
                
                Button {
                    viewModel.previousStep()
                } label: {
                    Text("Back")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGroupedBackground))
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
    
    //Format time slot with start and end time
    private func formatTimeSlot(_ slot: AvailabilityResultModel?, duration: Int) -> String {
        guard let slot = slot else { return "—" }
        
        guard let startTime = slot.StartTime,
              let startDate = UScheduleClient.parseAPIDate(startTime) else {
            return slot.TimeString ?? "—"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        let startString = formatter.string(from: startDate)
        let endDate = startDate.addingTimeInterval(TimeInterval(duration * 60))
        let endString = formatter.string(from: endDate)
        
        return "\(startString) - \(endString)"
    }
}

//Helper Views

struct LocationRow: View {
    let location: Location
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(isSelected ? .white : .secondary)
                
                Text(location.Description)
                    .foregroundStyle(isSelected ? .white : .primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                }
            }
            .padding()
            .background(isSelected ? Color.black : Color(.systemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct ServiceRow: View {
    let service: Service
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(service.Description)
                        .font(.headline)
                        .foregroundStyle(isSelected ? .white : .primary)
                    
                    if let length = service.ServiceLength {
                        Text("Starting from \(length) min")
                            .font(.subheadline)
                            .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                }
            }
            .padding()
            .background(isSelected ? Color.black : Color(.systemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct DurationChip: View {
    let duration: Int
    let isSelected: Bool
    let formatDuration: (Int) -> String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(formatDuration(duration))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? Color.black : Color(.systemBackground))
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

struct TimeSlotChip: View {
    let slot: AvailabilityResultModel
    let isSelected: Bool
    let duration: Int
    let onTap: () -> Void
    
    private var displayTime: String {
        guard let startTime = slot.StartTime,
              let startDate = UScheduleClient.parseAPIDate(startTime) else {
            return slot.TimeString ?? "—"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        let startString = formatter.string(from: startDate)
        
        // Calculate end time based on duration
        let endDate = startDate.addingTimeInterval(TimeInterval(duration * 60))
        let endString = formatter.string(from: endDate)
        
        return "\(startString) - \(endString)"
    }
    
    var body: some View {
        Button(action: onTap) {
            Text(displayTime)
                .font(.caption.weight(.medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color.black : Color(.systemBackground))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

//Bay selection row with capacity info
struct BaySelectionRow: View {
    let unit: ResourceUnit
    let isSelected: Bool
    let groupSize: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(unit.NickName ?? unit.Description)
                        .font(.headline)
                        .foregroundStyle(isSelected ? .white : .primary)
                    
                    if let capacity = unit.Capacity {
                        Text("Capacity: up to \(capacity) guests")
                            .font(.subheadline)
                            .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                    }
                    
                    // Bay 2 specific note
                    if unit.Id == 5524 {
                        Text("4 person max, Golf Only")
                            .font(.caption)
                            .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            }
            .padding()
            .background(isSelected ? Color.black : Color(.systemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct SummaryRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    NewBookingView(authToken: nil)
}
