import Foundation

struct USConfig {
    // TODO: move these into Build Settings or Keychain before shipping
    static let baseURL = URL(string: "https://clients.uschedule.com")! 
    static let alias   = "loftgolfstudios"
    static let appKey  = "c9af66c8-7e45-41f8-a00e-8324df5d3036"      // X-US-Application-Key
}

enum USError: Error, LocalizedError {
    case http(Int, String)
    case decoding(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .http(let code, let msg): return "Server \(code): \(msg)"
        case .decoding(let why):       return "Decoding failed: \(why)"
        case .unknown:                 return "Unknown error"
        }
    }
}

struct UserDetails: Codable {
    let UserId: Int
    let AuthKey: String
    let AccountID: Int
    let Username: String
    let IsCustomer: Bool
}

struct LoginModel: Codable { let UserName: String; let Password: String }
struct ImpersonateModel: Codable { let SearchField: String; let Value: String }
struct RegisterModel: Codable {
    let UserName: String, Password: String, FirstName: String, LastName: String, Email: String
    let Phone: String?
}

struct Location: Codable { let Id: Int; let Description: String }
struct Service: Codable { let Id: Int; let Description: String; let ServiceLength: Int? }

struct AvailabilityRequest: Codable {
    let LocationID: Int
    let EmployeeID: Int?
    let ServiceID: Int?
    let ResourceID: Int?
    let ResourceUnitID: Int?
    let GroupSize: Int?
    let StartDate: String
    let ServiceLength: Int?
    let NextAvailable: Bool?
}

struct BookingModel: Codable {
    let LocationID: Int
    let ServiceID: Int?
    let EventOccurrenceID: Int?
    let EmployeeID: Int?
    let ResourceUnitID: Int?
    let GroupSize: Int?
    let StartTime: String        // local ISO
    let ServiceLength: Int?
    let Notes: String?
    let PaymentType: Int?        // 1=PayAtLocation
    let PrepayServiceCustomerID: Int?
}

struct AppointmentResultModel: Codable {
    let Id: Int
    let Description: String?
    let StartTime: String?
    let Price: Double?
}


//ServiceType Model
struct ServiceType: Codable, Identifiable {
    let Id: Int
    let AccountID: Int?
    let Description: String
    let SortOrder: Int?
    let StatusID: Int?
    let PaymentOptionTypeID: Int?
    
    var id: Int { Id }
}

//Resource Models
struct Resource: Codable, Identifiable {
    let Id: Int
    let AccountID: Int?
    let Description: String
    let StatusID: Int?
    
    var id: Int { Id }
}

struct ResourceUnit: Codable, Identifiable {
    let Id: Int
    let AccountID: Int?
    let ResourceID: Int?
    let Description: String
    let StatusID: Int?
    let Capacity: Int?
    let NickName: String?
    
    var id: Int { Id }
}

struct AvailableResourceItem: Codable {
    let Resource: Resource
    let IsRequired: Bool?
    let Units: [ResourceUnit]?
}

struct ResourceWithUnitsModel: Codable, Identifiable {
    let Id: Int
    let Description: String?
    let Units: [ResourceUnit]?
    
    var id: Int { Id }
}

//Employee Model
struct Employee: Codable, Identifiable {
    let Id: Int
    let AccountID: Int?
    let UserID: Int?
    let EmailAddress: String?
    let EmployeeName: String?
    let Title: String?
    let Biography: String?
    let IsBookable: Bool?
    let IsAdmin: Bool?
    let SortOrder: Int?
    let StatusID: Int?
    
    var id: Int { Id }
}

struct AvailabilityResultModel: Codable, Identifiable {
    let EmployeeID: Int?
    let LocationID: Int?
    let StartTime: String?
    let AvailableTime: String?
    let TimeString: String?
    let Fee: Double?
    let FeeText: String?
    let FeeType: Int?
    
    var id: String { StartTime ?? UUID().uuidString }
}

//Request Models
struct AvailableServiceListModel: Codable {
    let LocationID: Int
    let PrepaidServiceID: Int?
}

struct EmployeeResourceParamModel: Codable {
    let LocationID: Int
    let ServiceID: Int
}

struct GetAppointmentModel: Codable {
    let StartDate: String?
    let EndDate: String?
    let LocationId: Int?
}

//Response Models
struct AvailabilityEmployeeResourceModel: Codable {
    let AvailableEmployees: [Employee]?
    let AvailableResources: [AvailableResourceItem]?
}

//Appointment Model
struct Appointment: Codable, Identifiable {
    let Id: Int
    let AccountID: Int?
    let Description: String?
    let CustomerID: Int?
    let EmployeeID: Int?
    let ServiceID: Int?
    let ResourceUnitID: Int?
    let StatusID: Int?
    let LocationID: Int?
    let AllDay: Bool?
    let StartTime: String?
    let EndTime: String?
    let Note: String?
    let GroupSize: Int?
    let PrepayServiceCustomerID: Int?
    let EventOccurrenceID: Int?
    let Price: Double?
    let MasterAppointmentID: Int?
    let ShowStatusID: Int?
    
    var id: Int { Id }
}

//Customer Model
struct Customer: Codable, Identifiable {
    let Id: Int
    let AccountID: Int?
    let UserID: Int?
    let EmailAddress: String?
    let DOB: String?
    let FirstName: String?
    let LastName: String?
    let StatusID: Int?
    let EmployeeID: Int?
    let MembershipID: Int?
    let MembershipExp: String?
    let EmailVerificationLevel: Int?
    let Reference1: String?
    let Reference2: String?
    let Reference3: String?
    let ParentCustomerID: Int?
    let MembershipStart: String?
    let Phone: String?
    
    var id: Int { Id }
    
    var fullName: String {
        [FirstName, LastName].compactMap { $0 }.joined(separator: " ")
    }
}

//Prepay Service Models
struct PrepayService: Codable, Identifiable {
    let Id: Int
    let AccountID: Int?
    let Description: String?
    let ExtDescription: String?
    let Cost: Double?
    let TotalUnits: Int?
    let SortOrder: Int?
    let StatusID: Int?
    let AvailableForPurchase: Int?
    let ExpirationDate: String?
    let IsTaxable: Bool?
    let UnitName: String?
    
    var id: Int { Id }
}

struct PrepayServiceCustomerModel: Codable, Identifiable {
    let Id: Int
    let CustomerID: Int?
    let StartDate: String?
    let EndDate: String?
    let RemainingUnits: Int?
    let EmployeeId: Int?
    let ReceiptNo: String?
    let StatusID: Int?
    let Cost: Double?
    let OriginalUnits: Int?
    let IsTaxable: Bool?
    let UnitName: String?
    
    var id: Int { Id }
}

//Enums
enum PaymentType: Int, Codable {
    case notChosen = 0
    case payAtLocation = 1
    case payWithCreditCard = 2
    case payWithPrepayService = 4
}

enum AppointmentStatusType: Int, Codable {
    case statusNotSet = 0
    case active = 1
    case inactive = 2
    case canceled = 9
    case rescheduled = 10
    case tentative = 11
}
//

final class UScheduleClient {
    private let json = JSONDecoder()
    private let enc  = JSONEncoder()

    private func url(_ method: String) -> URL {
        USConfig.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent(USConfig.alias)
            .appendingPathComponent(method)
    }

    private func request(_ method: String,
                         authToken: String? = nil,
                         httpMethod: String = "POST",
                         body: Data? = nil) -> URLRequest {
        var req = URLRequest(url: url(method))
        req.httpMethod = httpMethod
        if httpMethod == "POST" { req.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        req.setValue(USConfig.appKey, forHTTPHeaderField: "X-US-Application-Key")
        if let token = authToken { req.setValue(token, forHTTPHeaderField: "X-US-AuthToken") }
        req.httpBody = body
        return req
    }

    private func send<T: Decodable>(_ req: URLRequest, _ type: T.Type) async throws -> T {
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw USError.unknown }
        guard http.statusCode == 200 else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw USError.http(http.statusCode, text)
        }
        do { return try json.decode(T.self, from: data) }
        catch { throw USError.decoding(error.localizedDescription) }
    }

    // -------- Auth (Anonymous) --------
    func validateUser(username: String, password: String) async throws -> UserDetails {
        let body = try enc.encode(LoginModel(UserName: username, Password: password))
        let req  = request("validateuser", httpMethod: "POST", body: body)
        return try await send(req, UserDetails.self)
    }

    func impersonate(searchField: String = "username", value: String) async throws -> UserDetails {
        let body = try enc.encode(ImpersonateModel(SearchField: searchField, Value: value))
        let req  = request("impersonateuser", httpMethod: "POST", body: body)
        return try await send(req, UserDetails.self)
    }

    func registerUser(username: String, password: String, first: String, last: String, email: String, phone: String?) async throws -> UserDetails {
        let model = RegisterModel(UserName: username, Password: password, FirstName: first, LastName: last, Email: email, Phone: phone)
        let req   = request("registeruser", httpMethod: "POST", body: try enc.encode(model))
        return try await send(req, UserDetails.self)
    }

    // -------- Core (Authenticated) --------
    func locations(authToken: String) async throws -> [Location] {
        try await send(request("locations", authToken: authToken, httpMethod: "GET"), [Location].self)
    }

    func services(authToken: String) async throws -> [Service] {
        try await send(request("services", authToken: authToken, httpMethod: "GET"), [Service].self)
    }

    func getAvailability(authToken: String, model: AvailabilityRequest) async throws -> [Any] {
        let req = request("getavailability", authToken: authToken, httpMethod: "POST", body: try enc.encode(model))
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw USError.unknown }
        return (try JSONSerialization.jsonObject(with: data) as? [Any]) ?? []
    }

    func getPricing(authToken: String, booking: BookingModel) async throws -> AppointmentResultModel {
        try await send(request("getpricing", authToken: authToken, httpMethod: "POST", body: try enc.encode(booking)), AppointmentResultModel.self)
    }

    func bookIt(authToken: String, booking: BookingModel) async throws -> AppointmentResultModel {
        try await send(request("bookit", authToken: authToken, httpMethod: "POST", body: try enc.encode(booking)), AppointmentResultModel.self)
    }
    
    //Service Types
    func serviceTypes(authToken: String) async throws -> [ServiceType] {
        try await send(request("servicetypes", authToken: authToken, httpMethod: "GET"), [ServiceType].self)
    }
        
    //Employee Methods
    func employees(authToken: String) async throws -> [Employee] {
        try await send(request("employees", authToken: authToken, httpMethod: "GET"), [Employee].self)
    }
        
    //Resource Methods
    func resources(authToken: String) async throws -> [Resource] {
        try await send(request("resources", authToken: authToken, httpMethod: "GET"), [Resource].self)
    }
        
    func resourceUnits(authToken: String) async throws -> [ResourceUnit] {
        try await send(request("resourceunits", authToken: authToken, httpMethod: "GET"), [ResourceUnit].self)
    }
        
    //Available Employee Resources
    func availableEmployeeResources(authToken: String, locationID: Int, serviceID: Int) async throws -> AvailabilityEmployeeResourceModel {
        let model = EmployeeResourceParamModel(LocationID: locationID, ServiceID: serviceID)
        let req = request("availableemployeeresources", authToken: authToken, httpMethod: "POST", body: try enc.encode(model))
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        let responseString = String(data: data, encoding: .utf8) ?? "nil"
        print("availableEmployeeResources raw response: \(responseString)")
        
        guard let http = resp as? HTTPURLResponse else { throw USError.unknown }
        guard http.statusCode == 200 else {
            throw USError.http(http.statusCode, responseString)
        }
        
        do { return try json.decode(AvailabilityEmployeeResourceModel.self, from: data) }
        catch { throw USError.decoding(error.localizedDescription) }
    }
        
    //Get Availability
    func getAvailabilityTyped(authToken: String, model: AvailabilityRequest) async throws -> [AvailabilityResultModel] {
        let req = request("getavailability", authToken: authToken, httpMethod: "POST", body: try enc.encode(model))
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        let responseString = String(data: data, encoding: .utf8) ?? "nil"
        print("getAvailability raw response: \(responseString)")
        
        guard let http = resp as? HTTPURLResponse else { throw USError.unknown }
        guard http.statusCode == 200 else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw USError.http(http.statusCode, text)
        }
        
        do { return try json.decode([AvailabilityResultModel].self, from: data) }
        catch { throw USError.decoding(error.localizedDescription) }
    }
        
    //Appointment Methods
    func appointments(authToken: String) async throws -> [Appointment] {
        try await send(request("appointments", authToken: authToken, httpMethod: "GET"), [Appointment].self)
    }
        
    func appointments(authToken: String, startDate: String?, endDate: String?, locationId: Int? = nil) async throws -> [Appointment] {
        let model = GetAppointmentModel(StartDate: startDate, EndDate: endDate, LocationId: locationId)
        let req = request("appointments", authToken: authToken, httpMethod: "POST", body: try enc.encode(model))
        return try await send(req, [Appointment].self)
    }
        
    func getAppointment(authToken: String, id: Int) async throws -> Appointment {
        struct IdModel: Codable { let id: Int }
        let req = request("getappointment", authToken: authToken, httpMethod: "POST", body: try enc.encode(IdModel(id: id)))
        return try await send(req, Appointment.self)
    }
        
    func cancelAppointment(authToken: String, id: Int) async throws -> String {
        struct IdModel: Codable { let id: Int }
        let req = request("cancelappointment", authToken: authToken, httpMethod: "POST", body: try enc.encode(IdModel(id: id)))
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw USError.unknown }
            
        let responseText = String(data: data, encoding: .utf8) ?? ""
            
        if http.statusCode == 200 {
            return "Ok"
        } else if http.statusCode == 400 {
            throw USError.http(400, responseText)
        } else {
            throw USError.http(http.statusCode, responseText)
        }
    }
        
    //Customer Methods
    func customer(authToken: String) async throws -> Customer {
        try await send(request("customer", authToken: authToken, httpMethod: "GET"), Customer.self)
    }
        
    //Prepay Service Methods
    func prepayServices(authToken: String) async throws -> [PrepayService] {
        try await send(request("prepayservices", authToken: authToken, httpMethod: "GET"), [PrepayService].self)
    }
        
    func prepayServiceCustomers(authToken: String) async throws -> [PrepayServiceCustomerModel] {
        try await send(request("prepayservicecustomers", authToken: authToken, httpMethod: "GET"), [PrepayServiceCustomerModel].self)
    }
    
}

//Date Formatting Helpers
extension UScheduleClient {
    static func formatDateForAPI(_ date: Date) -> String {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = .current
        return formatter.string(from: startOfDay)
    }
    
    static func parseAPIDate(_ string: String?) -> Date? {
        guard let string = string else { return nil }
        
        let formatters: [DateFormatter] = {
            let formats = [
                "yyyy-MM-dd'T'HH:mm:ss",
                "yyyy-MM-dd'T'HH:mm:ss.SSS",
                "yyyy-MM-dd'T'HH:mm:ssZ",
                "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            ]
            return formats.map { format in
                let formatter = DateFormatter()
                formatter.dateFormat = format
                formatter.locale = Locale(identifier: "en_US_POSIX")
                return formatter
            }
        }()
        
        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: string) {
            return date
        }
        
        isoFormatter.formatOptions = [.withInternetDateTime]
        return isoFormatter.date(from: string)
    }
}
