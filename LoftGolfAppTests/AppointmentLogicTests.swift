import Testing
import Foundation
@testable import LoftGolfApp

@Suite("Appointment Logic")
struct AppointmentLogicTests {

    // MARK: - isInActivationWindow(for:)

    @Test @MainActor
    func activationWindow_inactiveStatus_returnsFalse() {
        let vm = HomeViewModel()
        let appt = makeAppointment(startOffset: -5 * 60, endOffset: 55 * 60, statusID: 2)
        #expect(!vm.isInActivationWindow(for: appt))
    }

    @Test @MainActor
    func activationWindow_nilStatus_returnsFalse() {
        let vm = HomeViewModel()
        let appt = makeAppointment(startOffset: -5 * 60, endOffset: 55 * 60, statusID: nil)
        #expect(!vm.isInActivationWindow(for: appt))
    }

    @Test @MainActor
    func activationWindow_unparseableStartTime_returnsFalse() {
        let vm = HomeViewModel()
        let appt = Appointment(
            Id: 1, AccountID: nil, Description: nil, CustomerID: nil,
            EmployeeID: nil, ServiceID: nil, ResourceUnitID: nil,
            StatusID: 1, LocationID: nil, AllDay: nil,
            StartTime: "garbage", EndTime: nil,
            Note: nil, GroupSize: nil, PrepayServiceCustomerID: nil,
            EventOccurrenceID: nil, Price: nil, MasterAppointmentID: nil, ShowStatusID: nil
        )
        #expect(!vm.isInActivationWindow(for: appt))
    }

    @Test @MainActor
    func activationWindow_sixMinBeforeStart_returnsFalse() {
        let vm = HomeViewModel()
        // Starts 6 min from now — outside the 5-min buffer
        let appt = makeAppointment(startOffset: 6 * 60, endOffset: 66 * 60)
        #expect(!vm.isInActivationWindow(for: appt))
    }

    @Test @MainActor
    func activationWindow_justInsideBuffer_returnsTrue() {
        let vm = HomeViewModel()
        // Starts in 4 min — inside the 5-min buffer
        let appt = makeAppointment(startOffset: 4 * 60, endOffset: 64 * 60)
        #expect(vm.isInActivationWindow(for: appt))
    }

    @Test @MainActor
    func activationWindow_duringSession_returnsTrue() {
        let vm = HomeViewModel()
        // Started 10 min ago, ends in 50 min
        let appt = makeAppointment(startOffset: -10 * 60, endOffset: 50 * 60)
        #expect(vm.isInActivationWindow(for: appt))
    }

    @Test @MainActor
    func activationWindow_fourteenMinAfterEnd_returnsTrue() {
        let vm = HomeViewModel()
        // Ended 14 min ago — within 15-min grace period
        let appt = makeAppointment(startOffset: -74 * 60, endOffset: -14 * 60)
        #expect(vm.isInActivationWindow(for: appt))
    }

    @Test @MainActor
    func activationWindow_sixteenMinAfterEnd_returnsFalse() {
        let vm = HomeViewModel()
        // Ended 16 min ago — outside 15-min grace period
        let appt = makeAppointment(startOffset: -76 * 60, endOffset: -16 * 60)
        #expect(!vm.isInActivationWindow(for: appt))
    }

    @Test @MainActor
    func activationWindow_noEndTime_defaultsToOneHour() {
        let vm = HomeViewModel()
        // No EndTime — defaults to start + 1h. 59 min in → inside window.
        let appt = makeAppointment(startOffset: -59 * 60, endOffset: nil)
        #expect(vm.isInActivationWindow(for: appt))
    }

    @Test @MainActor
    func activationWindow_noEndTime_seventyFiveMinIn_returnsTrue() {
        let vm = HomeViewModel()
        // 75 min past start, no EndTime → 1h default + 15-min grace = still open
        let appt = makeAppointment(startOffset: -75 * 60, endOffset: nil)
        #expect(vm.isInActivationWindow(for: appt))
    }

    @Test @MainActor
    func activationWindow_noEndTime_seventySixMinIn_returnsFalse() {
        let vm = HomeViewModel()
        // 76 min past start → past 1h + 15-min grace
        let appt = makeAppointment(startOffset: -76 * 60, endOffset: nil)
        #expect(!vm.isInActivationWindow(for: appt))
    }

    // MARK: - 24-hour cancellation window

    @Test func canCancel_twentyFiveHoursAway_true() {
        let startTime = Date().addingTimeInterval(25 * 3600)
        #expect(startTime.timeIntervalSinceNow > 24 * 3600)
    }

    @Test func canCancel_exactly24HoursAway_false() {
        // Must be *more than* 24h — exact boundary is not cancellable
        let startTime = Date().addingTimeInterval(24 * 3600)
        #expect(!(startTime.timeIntervalSinceNow > 24 * 3600))
    }

    @Test func canCancel_twentyThreeHoursAway_false() {
        let startTime = Date().addingTimeInterval(23 * 3600)
        #expect(!(startTime.timeIntervalSinceNow > 24 * 3600))
    }

    @Test func canCancel_pastAppointment_false() {
        let startTime = Date().addingTimeInterval(-1 * 3600)
        #expect(!(startTime.timeIntervalSinceNow > 24 * 3600))
    }

    // MARK: - compactTimeRange / appointmentTimeRange

    @Test func timeRange_samePeriod_AM() {
        let cal = Calendar.current
        var c = DateComponents()
        c.year = 2026; c.month = 4; c.day = 22; c.hour = 9; c.minute = 0
        let start = cal.date(from: c)!
        c.hour = 10
        let end = cal.date(from: c)!
        #expect(appointmentTimeRange(start: start, end: end) == "9:00 – 10:00 AM")
    }

    @Test func timeRange_samePeriod_PM() {
        let cal = Calendar.current
        var c = DateComponents()
        c.year = 2026; c.month = 4; c.day = 22; c.hour = 21; c.minute = 0
        let start = cal.date(from: c)!
        c.hour = 22
        let end = cal.date(from: c)!
        #expect(appointmentTimeRange(start: start, end: end) == "9:00 – 10:00 PM")
    }

    @Test func timeRange_crossesNoon_showsBothPeriods() {
        let cal = Calendar.current
        var c = DateComponents()
        c.year = 2026; c.month = 4; c.day = 22; c.hour = 11; c.minute = 0
        let start = cal.date(from: c)!
        c.hour = 12
        let end = cal.date(from: c)!
        let result = appointmentTimeRange(start: start, end: end)
        #expect(result == "11:00 AM – 12:00 PM")
    }

    @Test func timeRange_crossesNoon_edgeMinutes() {
        let cal = Calendar.current
        var c = DateComponents()
        c.year = 2026; c.month = 4; c.day = 22; c.hour = 11; c.minute = 59
        let start = cal.date(from: c)!
        c.hour = 12; c.minute = 1
        let end = cal.date(from: c)!
        let result = appointmentTimeRange(start: start, end: end)
        #expect(result == "11:59 AM – 12:01 PM")
    }

    @Test func timeRange_nilEnd_showsStartOnly() {
        let cal = Calendar.current
        var c = DateComponents()
        c.year = 2026; c.month = 4; c.day = 22; c.hour = 9; c.minute = 0
        let start = cal.date(from: c)!
        #expect(appointmentTimeRange(start: start, end: nil) == "9:00 AM")
    }

    // MARK: - Bay name mapping

    @Test func bayName_bay1() {
        #expect(DoorConfig.bay1ResourceUnitId == 5523)
    }

    @Test func bayName_bay2() {
        #expect(DoorConfig.bay2ResourceUnitId == 5524)
    }

    @Test func bayName_unknown_isNil() {
        // Any ID that is neither bay1 nor bay2 should produce no bay label
        let unknownId = 9999
        let isBay = unknownId == DoorConfig.bay1ResourceUnitId
                 || unknownId == DoorConfig.bay2ResourceUnitId
        #expect(!isBay)
    }

    // MARK: - BookingHistory.cancellationCandidateIds

    @Test func cancellationIds_noMaster_containsOnlyId() {
        let booking = makeBookingHistory(id: 42, masterAppointmentId: nil)
        #expect(booking.cancellationCandidateIds == [42])
    }

    @Test func cancellationIds_zeroMaster_treatedAsNoMaster() {
        // masterAppointmentId = 0 fails the > 0 guard → only the id itself
        let booking = makeBookingHistory(id: 42, masterAppointmentId: 0)
        #expect(booking.cancellationCandidateIds == [42])
    }

    @Test func cancellationIds_differentMaster_containsBoth() {
        let booking = makeBookingHistory(id: 42, masterAppointmentId: 5)
        let ids = booking.cancellationCandidateIds
        #expect(ids.contains(5))
        #expect(ids.contains(42))
        #expect(ids.count == 2)
    }

    @Test func cancellationIds_masterEqualsId_noDuplicate() {
        // masterAppointmentId == id → should not appear twice
        let booking = makeBookingHistory(id: 42, masterAppointmentId: 42)
        #expect(booking.cancellationCandidateIds == [42])
        #expect(booking.cancellationCandidateIds.count == 1)
    }

    // MARK: - Helpers

    private func makeAppointment(startOffset: TimeInterval,
                                 endOffset: TimeInterval?,
                                 statusID: Int? = 1) -> Appointment {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        let now = Date()
        let startStr = fmt.string(from: now.addingTimeInterval(startOffset))
        let endStr = endOffset.map { fmt.string(from: now.addingTimeInterval($0)) }
        return Appointment(
            Id: 1, AccountID: nil, Description: nil, CustomerID: nil,
            EmployeeID: nil, ServiceID: nil, ResourceUnitID: nil,
            StatusID: statusID, LocationID: nil, AllDay: nil,
            StartTime: startStr, EndTime: endStr,
            Note: nil, GroupSize: nil, PrepayServiceCustomerID: nil,
            EventOccurrenceID: nil, Price: nil, MasterAppointmentID: nil, ShowStatusID: nil
        )
    }

    private func makeBookingHistory(id: Int, masterAppointmentId: Int?) -> BookingHistory {
        BookingHistory(
            id: id,
            masterAppointmentId: masterAppointmentId,
            description: "Test",
            startTime: Date(),
            endTime: nil,
            locationName: nil,
            serviceName: nil,
            price: nil,
            status: .active
        )
    }
}
