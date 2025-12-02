import Foundation

struct PrepayServiceCustomer: Identifiable, Codable {
    let id: Int
    let customerID: Int
    let startDate: String?
    let endDate: String?
    let remainingUnits: Int
    let employeeId: Int?
    let receiptNo: String?
    let statusID: Int
    let cost: Double?
    let originalUnits: Int?
    let isTaxable: Bool?
    let unitName: String?
}
