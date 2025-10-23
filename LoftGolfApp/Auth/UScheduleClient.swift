import Foundation

struct USConfig {
    // TODO: move these into Build Settings or Keychain before shipping
    static let baseURL = URL(string: "https://beta.uschedule.com")!  // or https://clients.uschedule.com
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
    let StartDate: String        // e.g. "2025-10-25T00:00:00"
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
}
