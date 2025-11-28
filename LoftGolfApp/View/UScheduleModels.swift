import Foundation

// MARK: - Locations
struct USLocation: Codable, Identifiable {
    let id: Int
    let description: String?
}

// MARK: - Services
struct USService: Codable, Identifiable {
    let id: Int
    let description: String?
}

// MARK: - ResourceUnits
struct USResourceUnit: Codable, Identifiable {
    let id: Int
    let description: String?
}

// MARK: - AvailabilityResult
struct AvailabilityResult: Codable, Identifiable {
    let id = UUID()   // USchedule does not return an ID, so generate
    let startTime: String?
    let timeString: String?
    let fee: Double?
}

// MARK: - SearchAvailabilityModel
struct SearchAvailabilityModel: Codable {
    let EmployeeID: Int?
    let LocationID: Int
    let ServiceID: Int
    let ResourceID: Int?
    let ResourceUnitID: Int
    let GroupSize: Int
    let StartTime: String
    let ServiceLength: Int
    let NextAvailable: Bool
}
