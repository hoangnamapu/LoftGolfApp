import Foundation

struct UScheduleBookingModel: Codable {
    let locationID: Int
    let serviceID: Int?
    let eventOccurrenceID: Int?
    let employeeID: Int?
    let resourceUnitID: Int?
    let groupSize: Int
    let startTime: String
    let serviceLength: Int?
    let prepayServiceCustomerID: Int?
    let paymentType: Int
    let paymentCard: UScheduleCreditCard?
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case locationID = "LocationID"
        case serviceID = "ServiceID"
        case eventOccurrenceID = "EventOccurrenceID"
        case employeeID = "EmployeeID"
        case resourceUnitID = "ResourceUnitID"
        case groupSize = "GroupSize"
        case startTime = "StartTime"
        case serviceLength = "ServiceLength"
        case prepayServiceCustomerID = "PrepayServiceCustomerID"
        case paymentType = "PaymentType"
        case paymentCard = "PaymentCard"
        case notes = "Notes"
    }
}

