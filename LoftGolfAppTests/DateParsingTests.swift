import Testing
import Foundation
@testable import LoftGolfApp

@Suite("Date Parsing")
struct DateParsingTests {

    // MARK: - parseAPIDate — nil / invalid inputs

    @Test func parseNil() {
        #expect(UScheduleClient.parseAPIDate(nil) == nil)
    }

    @Test func parseEmptyString() {
        #expect(UScheduleClient.parseAPIDate("") == nil)
    }

    @Test func parseMalformedString() {
        #expect(UScheduleClient.parseAPIDate("not-a-date") == nil)
        #expect(UScheduleClient.parseAPIDate("2026/04/22") == nil)
        #expect(UScheduleClient.parseAPIDate("April 22, 2026") == nil)
    }

    // MARK: - parseAPIDate — all 6 supported formats produce a valid Date

    @Test func parseFormat1_noMillisNoTimezone() {
        let result = UScheduleClient.parseAPIDate("2026-04-22T07:00:00")
        #expect(result != nil)
    }

    @Test func parseFormat2_millisecondsNoTimezone() {
        let result = UScheduleClient.parseAPIDate("2026-04-22T07:00:00.000")
        #expect(result != nil)
    }

    @Test func parseFormat3_utcTimezone() {
        let result = UScheduleClient.parseAPIDate("2026-04-22T07:00:00Z")
        #expect(result != nil)
    }

    @Test func parseFormat4_fractionalSecondsUTC() {
        let result = UScheduleClient.parseAPIDate("2026-04-22T07:00:00.000Z")
        #expect(result != nil)
    }

    @Test func parseFormat4_fractionalSeconds999() {
        let result = UScheduleClient.parseAPIDate("2026-04-22T07:00:00.999Z")
        #expect(result != nil)
    }

    @Test func parseFormat_timezoneOffset() {
        let result = UScheduleClient.parseAPIDate("2026-04-22T07:00:00-07:00")
        #expect(result != nil)
    }

    // MARK: - parseAPIDate — UTC formats agree on the same instant

    @Test func utcFormatsProduceSameInstant() throws {
        // Both strings represent the same moment in UTC; parsed dates must match.
        let withMillis    = try #require(UScheduleClient.parseAPIDate("2026-04-22T14:30:00.000Z"))
        let withoutMillis = try #require(UScheduleClient.parseAPIDate("2026-04-22T14:30:00Z"))
        #expect(withMillis == withoutMillis)
    }

    @Test func differentMillisecondsParseToDifferentInstants() throws {
        let t0 = try #require(UScheduleClient.parseAPIDate("2026-04-22T14:30:00.000Z"))
        let t1 = try #require(UScheduleClient.parseAPIDate("2026-04-22T14:30:00.999Z"))
        #expect(t1 > t0)
    }

    // MARK: - formatDateForAPI

    @Test func formatDateForAPI_producesStartOfDay() {
        // Regardless of input time, output should represent start of day
        var components = DateComponents()
        components.year = 2026; components.month = 4; components.day = 22
        components.hour = 14; components.minute = 37; components.second = 55
        let date = Calendar.current.date(from: components)!

        let result = UScheduleClient.formatDateForAPI(date)
        // Must start with the date portion and have 00:00:00 time
        #expect(result.hasPrefix("2026-04-22T00:00:00"))
    }

    @Test func formatDateForAPI_noTimezoneMarker() {
        let date = Date()
        let result = UScheduleClient.formatDateForAPI(date)
        #expect(!result.contains("Z"))
        #expect(!result.contains("+"))
    }

    @Test func formatDateForAPI_roundTrips() {
        // A formatted date should parse back to a valid Date
        let original = Date()
        let formatted = UScheduleClient.formatDateForAPI(original)
        let parsed = UScheduleClient.parseAPIDate(formatted)
        #expect(parsed != nil)
    }
}
