//
//  BookingViewModel.swift
//  LoftGolfApp
//
//  Created by ZhiYue Wang on 1/27/26.
//

import Foundation
import SwiftUI

//Booking Flow State
// Flow: Service -> Guests -> Bay -> DateTime -> Confirm
enum BookingStep: Int, CaseIterable {
    case selectService = 0
    case selectGuests = 1
    case selectBay = 2
    case selectDateTime = 3
    case confirmation = 4
    
    var title: String {
        switch self {
        case .selectService: return "Service"
        case .selectGuests: return "Guests"
        case .selectBay: return "Bay"
        case .selectDateTime: return "Date & Time"
        case .confirmation: return "Confirm"
        }
    }
}

@MainActor
final class BookingViewModel: ObservableObject {
    
    //Flow State
    @Published var currentStep: BookingStep = .selectService
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    //Data from API
    @Published var locations: [Location] = []
    @Published var services: [Service] = []
    @Published var serviceTypes: [ServiceType] = []
    @Published var resourceUnits: [ResourceUnit] = []
    @Published var availableSlots: [AvailabilityResultModel] = []
    @Published var upcomingAppointments: [Appointment] = []
    
    //User Selections
    @Published var selectedLocation: Location?
    @Published var selectedService: Service?
    @Published var selectedDate: Date = Date()
    @Published var selectedTimeSlot: AvailabilityResultModel?
    @Published var selectedResourceUnit: ResourceUnit?
    @Published var selectedDuration: Int = 60
    @Published var groupSize: Int = 1
    @Published var notes: String = ""
    
    //Pricing
    @Published var estimatedPrice: Double?
    
    //Booking Result
    @Published var bookingResult: AppointmentResultModel?
    @Published var showBookingSuccess = false
    
    //Private Properties
    private let client = UScheduleClient()
    private var authToken: String?
    
    //Duration options (in minutes): 1, 2, 3, 4 hours
    let durationOptions = [60, 120, 180, 240]
    
    //Initialization
    init(authToken: String? = nil) {
        self.authToken = authToken
    }
    
    func setAuthToken(_ token: String) {
        self.authToken = token
    }
    
    //Data Loading
    //Load initial data (locations, services, service types, resource units)
    func loadInitialData() async {
        guard let token = authToken else {
            showErrorMessage("Not authenticated")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Load in parallel
            async let locationsTask = client.locations(authToken: token)
            async let servicesTask = client.services(authToken: token)
            async let serviceTypesTask = client.serviceTypes(authToken: token)
            async let resourceUnitsTask = client.resourceUnits(authToken: token)
            
            let (locs, svcs, types, units) = try await (locationsTask, servicesTask, serviceTypesTask, resourceUnitsTask)
            
            self.locations = locs
            self.services = svcs
            self.serviceTypes = types.filter { $0.StatusID == 1 }
            self.resourceUnits = units.filter { $0.StatusID == 1 }
            
            // Auto-select if only one location
            if self.locations.count == 1 {
                self.selectedLocation = self.locations.first
            }
            
            isLoading = false
        } catch {
            isLoading = false
            showErrorMessage(error.localizedDescription)
        }
    }
    
    //Load upcoming appointments
    func loadAppointments() async {
        guard let token = authToken else { return }
        
        do {
            let appointments = try await client.appointments(authToken: token)
            self.upcomingAppointments = appointments
                .filter { appointment in
                    guard let startTimeStr = appointment.StartTime,
                          let startTime = UScheduleClient.parseAPIDate(startTimeStr) else {
                        return false
                    }
                    return startTime > Date() && appointment.StatusID == 1
                }
                .sorted { a, b in
                    guard let aTime = UScheduleClient.parseAPIDate(a.StartTime),
                          let bTime = UScheduleClient.parseAPIDate(b.StartTime) else {
                        return false
                    }
                    return aTime < bTime
                }
        } catch {
            print("Failed to load appointments: \(error)")
        }
    }
    
    //Load available time slots for selected criteria
    func loadAvailability() async {
        guard let token = authToken else {
            print("loadAvailability: No auth token")
            return
        }
        
        guard let location = selectedLocation else {
            print("loadAvailability: No location selected")
            return
        }
        
        guard let service = selectedService else {
            print("loadAvailability: No service selected")
            return
        }
        
        isLoading = true
        availableSlots = []
        
        do {
            // Step 1: Get available employees and resources
            print("loadAvailability: Getting available resources for location: \(location.Id), service: \(service.Id)")
            let availableResources = try await client.availableEmployeeResources(
                authToken: token,
                locationID: location.Id,
                serviceID: service.Id
            )
            
            print("loadAvailability: Available employees: \(availableResources.AvailableEmployees?.count ?? 0)")
            print("loadAvailability: Available resources: \(availableResources.AvailableResources?.count ?? 0)")
            
            let employeeId = availableResources.AvailableEmployees?.first?.Id
            let resourceId = availableResources.AvailableResources?.first?.Resource.Id
            
            print("loadAvailability: Using employeeId: \(employeeId ?? -1), resourceId: \(resourceId ?? -1)")
            
            // Step 2: Query available time slots with the resource info
            let dateString = UScheduleClient.formatDateForAPI(selectedDate)
            print("loadAvailability: Requesting for date: \(dateString), location: \(location.Id), service: \(service.Id), duration: \(selectedDuration)")
            
            let request = AvailabilityRequest(
                LocationID: location.Id,
                EmployeeID: employeeId,
                ServiceID: service.Id,
                ResourceID: resourceId,
                ResourceUnitID: selectedResourceUnit?.Id,
                GroupSize: groupSize,
                StartDate: dateString,
                ServiceLength: selectedDuration,
                NextAvailable: false
            )
            
            let slots = try await client.getAvailabilityTyped(authToken: token, model: request)
            print("loadAvailability: Got \(slots.count) slots")
            
            if !Task.isCancelled {
                self.availableSlots = slots
                isLoading = false
            }
        } catch {
            print("loadAvailability Error: \(error)")
            if !Task.isCancelled {
                isLoading = false
                if (error as NSError).code != NSURLErrorCancelled {
                    showErrorMessage(error.localizedDescription)
                }
            }
        }
    }
    
    //Get pricing for current selection
    func loadPricing() async {
        guard let token = authToken,
              let location = selectedLocation,
              let service = selectedService,
              let timeSlot = selectedTimeSlot,
              let startTime = timeSlot.StartTime else {
            return
        }
        
        do {
            let bookingModel = BookingModel(
                LocationID: location.Id,
                ServiceID: service.Id,
                EventOccurrenceID: nil,
                EmployeeID: nil,
                ResourceUnitID: selectedResourceUnit?.Id,
                GroupSize: groupSize,
                StartTime: startTime,
                ServiceLength: selectedDuration,
                Notes: nil,
                PaymentType: PaymentType.payAtLocation.rawValue,
                PrepayServiceCustomerID: nil
            )
            
            let result = try await client.getPricing(authToken: token, booking: bookingModel)
            self.estimatedPrice = result.Price
        } catch {
            print("Failed to get pricing: \(error)")
            self.estimatedPrice = nil
        }
    }
    
    //Booking Actions
    
    //Create the booking
    func confirmBooking() async -> Bool {
        guard let token = authToken,
              let location = selectedLocation,
              let service = selectedService,
              let timeSlot = selectedTimeSlot,
              let startTime = timeSlot.StartTime else {
            showErrorMessage("Please complete all selections")
            return false
        }
        
        isLoading = true
        
        do {
            let bookingModel = BookingModel(
                LocationID: location.Id,
                ServiceID: service.Id,
                EventOccurrenceID: nil,
                EmployeeID: nil,
                ResourceUnitID: selectedResourceUnit?.Id,
                GroupSize: groupSize,
                StartTime: startTime,
                ServiceLength: selectedDuration,
                Notes: notes.isEmpty ? nil : notes,
                PaymentType: PaymentType.payAtLocation.rawValue,
                PrepayServiceCustomerID: nil
            )
            
            let result = try await client.bookIt(authToken: token, booking: bookingModel)
            
            self.bookingResult = result
            self.showBookingSuccess = true
            isLoading = false
            
            // Refresh appointments
            await loadAppointments()
            
            return true
        } catch {
            isLoading = false
            showErrorMessage(error.localizedDescription)
            return false
        }
    }
    
    //Cancel an appointment
    func cancelAppointment(_ appointmentId: Int) async -> Bool {
        guard let token = authToken else {
            showErrorMessage("Not authenticated")
            return false
        }
        
        isLoading = true
        
        do {
            _ = try await client.cancelAppointment(authToken: token, id: appointmentId)
            isLoading = false
            
            // Refresh appointments
            await loadAppointments()
            
            return true
        } catch let error as USError {
            isLoading = false
            switch error {
            case .http(400, let message):
                showErrorMessage("Cannot cancel: \(message)")
            default:
                showErrorMessage(error.localizedDescription)
            }
            return false
        } catch {
            isLoading = false
            showErrorMessage(error.localizedDescription)
            return false
        }
    }
    
    //Navigation
    
    func nextStep() {
        guard let nextIndex = BookingStep.allCases.firstIndex(of: currentStep)?.advanced(by: 1),
              nextIndex < BookingStep.allCases.count else {
            return
        }
        withAnimation {
            currentStep = BookingStep.allCases[nextIndex]
        }
    }
    
    func previousStep() {
        guard let prevIndex = BookingStep.allCases.firstIndex(of: currentStep)?.advanced(by: -1),
              prevIndex >= 0 else {
            return
        }
        withAnimation {
            currentStep = BookingStep.allCases[prevIndex]
        }
    }
    
    func goToStep(_ step: BookingStep) {
        withAnimation {
            currentStep = step
        }
    }
    
    //Reset booking flow
    func resetBooking() {
        currentStep = .selectService
        selectedService = nil
        selectedDate = Date()
        selectedTimeSlot = nil
        selectedResourceUnit = nil
        selectedDuration = 60
        groupSize = 1
        notes = ""
        estimatedPrice = nil
        bookingResult = nil
        availableSlots = []
    }
    
    //Bay Filtering based on Group Size
    //Returns available bays filtered by group size
    //Bay 1 (Id: 5523): Capacity 8 guests
    //Bay 2 (Id: 5524): Capacity 4 guests, Golf Only
    var availableBaysForGroupSize: [ResourceUnit] {
        if groupSize > 8 {
            // 9+ guests cannot be accommodated
            return []
        } else if groupSize > 4 {
            // 5-8 guests: only show Bay 1 (capacity >= groupSize)
            return resourceUnits.filter { ($0.Capacity ?? 0) >= groupSize }
        } else {
            // 1-4 guests: show all bays
            return resourceUnits
        }
    }
    
    //Returns true if group size exceeds maximum capacity
    var cannotAccommodate: Bool {
        groupSize > 8
    }
    
    //Validation
    
    var canProceedToGuests: Bool {
        selectedLocation != nil && selectedService != nil
    }
    
    var canProceedToBay: Bool {
        canProceedToGuests && groupSize >= 1 && !cannotAccommodate
    }
    
    var canProceedToDateTime: Bool {
        canProceedToBay && (availableBaysForGroupSize.isEmpty || selectedResourceUnit != nil)
    }
    
    var canConfirm: Bool {
        canProceedToDateTime && selectedTimeSlot != nil
    }
    
    //Helpers
    
    func servicesForType(_ typeId: Int?) -> [Service] {
        guard let typeId = typeId else { return services }
        return services
    }
    
    func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else if minutes % 60 == 0 {
            let hours = minutes / 60
            return hours == 1 ? "1 hour" : "\(hours) hours"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
    }
    
    func formatPrice(_ price: Double?) -> String {
        guard let price = price else { return "—" }
        return String(format: "$%.2f", price)
    }
    
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
}
