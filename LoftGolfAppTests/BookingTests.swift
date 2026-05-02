import Testing
@testable import LoftGolfApp

@Suite("Booking Logic")
@MainActor
struct BookingTests {

    // MARK: - State machine navigation

    @Test func nextStep_advancesForward() {
        let vm = BookingViewModel()
        #expect(vm.currentStep == .selectService)
        vm.nextStep()
        #expect(vm.currentStep == .selectGuests)
    }

    @Test func nextStep_doesNotWrapPastConfirmation() {
        let vm = BookingViewModel()
        vm.goToStep(.confirmation)
        vm.nextStep()
        #expect(vm.currentStep == .confirmation)
    }

    @Test func previousStep_goesBack() {
        let vm = BookingViewModel()
        vm.goToStep(.selectGuests)
        vm.previousStep()
        #expect(vm.currentStep == .selectService)
    }

    @Test func previousStep_doesNotWrapBeforeFirst() {
        let vm = BookingViewModel()
        #expect(vm.currentStep == .selectService)
        vm.previousStep()
        #expect(vm.currentStep == .selectService)
    }

    @Test func goToStep_jumpsDirectly() {
        let vm = BookingViewModel()
        vm.goToStep(.confirmation)
        #expect(vm.currentStep == .confirmation)
    }

    // MARK: - Validation chain

    @Test func canProceedToGuests_requiresLocationAndService() {
        let vm = BookingViewModel()
        #expect(!vm.canProceedToGuests)

        vm.selectedLocation = Location(Id: 1, Description: "Loft")
        #expect(!vm.canProceedToGuests)

        vm.selectedService = Service(Id: 1, Description: "Simulator", ServiceLength: 60)
        #expect(vm.canProceedToGuests)
    }

    @Test func canProceedToBay_requiresGroupSizeAtLeastOne() {
        let vm = BookingViewModel()
        vm.selectedLocation = Location(Id: 1, Description: "Loft")
        vm.selectedService = Service(Id: 1, Description: "Simulator", ServiceLength: 60)
        vm.groupSize = 0
        #expect(!vm.canProceedToBay)

        vm.groupSize = 1
        #expect(vm.canProceedToBay)
    }

    @Test func cannotAccommodate_nineOrMoreGuests() {
        let vm = BookingViewModel()
        vm.groupSize = 8
        #expect(!vm.cannotAccommodate)

        vm.groupSize = 9
        #expect(vm.cannotAccommodate)
        #expect(!vm.canProceedToBay)
    }

    // MARK: - Bay capacity filtering

    @Test func bayFiltering_oneToFourGuests_showsBothBays() {
        let vm = bookingVMWithBays()
        for size in 1...4 {
            vm.groupSize = size
            #expect(vm.availableBaysForGroupSize.count == 2,
                    "groupSize \(size) should show both bays")
        }
    }

    @Test func bayFiltering_fiveGuests_onlyBayOne() {
        let vm = bookingVMWithBays()
        vm.groupSize = 5
        let bays = vm.availableBaysForGroupSize
        #expect(bays.count == 1)
        #expect(bays.first?.Id == DoorConfig.bay1ResourceUnitId)
    }

    @Test func bayFiltering_boundary_fourVsFive() {
        let vm = bookingVMWithBays()

        vm.groupSize = 4
        #expect(vm.availableBaysForGroupSize.count == 2)

        vm.groupSize = 5
        #expect(vm.availableBaysForGroupSize.count == 1)
    }

    @Test func bayFiltering_eightGuests_onlyBayOne() {
        let vm = bookingVMWithBays()
        vm.groupSize = 8
        let bays = vm.availableBaysForGroupSize
        #expect(bays.count == 1)
        #expect(bays.first?.Id == DoorConfig.bay1ResourceUnitId)
    }

    @Test func bayFiltering_nineGuests_noBays() {
        let vm = bookingVMWithBays()
        vm.groupSize = 9
        #expect(vm.availableBaysForGroupSize.isEmpty)
    }

    // MARK: - formatDuration

    @Test func formatDuration_underOneHour() {
        let vm = BookingViewModel()
        #expect(vm.formatDuration(45) == "45 min")
        #expect(vm.formatDuration(30) == "30 min")
        #expect(vm.formatDuration(1)  == "1 min")
    }

    @Test func formatDuration_exactHours() {
        let vm = BookingViewModel()
        #expect(vm.formatDuration(60)  == "1 hour")
        #expect(vm.formatDuration(120) == "2 hours")
        #expect(vm.formatDuration(180) == "3 hours")
        #expect(vm.formatDuration(240) == "4 hours")
    }

    @Test func formatDuration_hoursAndMinutes() {
        let vm = BookingViewModel()
        #expect(vm.formatDuration(90) == "1h 30m")
        #expect(vm.formatDuration(61) == "1h 1m")
        #expect(vm.formatDuration(75) == "1h 15m")
    }

    // MARK: - formatPrice

    @Test func formatPrice_nil() {
        #expect(BookingViewModel().formatPrice(nil) == "—")
    }

    @Test func formatPrice_zero() {
        #expect(BookingViewModel().formatPrice(0.0) == "$0.00")
    }

    @Test func formatPrice_standard() {
        #expect(BookingViewModel().formatPrice(59.99)  == "$59.99")
        #expect(BookingViewModel().formatPrice(100.0)  == "$100.00")
        #expect(BookingViewModel().formatPrice(0.01)   == "$0.01")
    }

    // MARK: - Helpers

    private func bookingVMWithBays() -> BookingViewModel {
        let vm = BookingViewModel()
        let bay1 = ResourceUnit(Id: DoorConfig.bay1ResourceUnitId,
                                AccountID: nil, ResourceID: nil,
                                Description: "Bay 1", StatusID: 1,
                                Capacity: 8, NickName: nil)
        let bay2 = ResourceUnit(Id: DoorConfig.bay2ResourceUnitId,
                                AccountID: nil, ResourceID: nil,
                                Description: "Bay 2", StatusID: 1,
                                Capacity: 4, NickName: nil)
        vm.resourceUnits = [bay1, bay2]
        return vm
    }
}
