import Foundation
import Combine

// MARK: - Error Handling
enum USAuthError: LocalizedError {
    case http(Int, String)           // status + body sample
    case emptyBody
    case decoding(String, sample: String)
    case badURL
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .http(let code, let body): return "HTTP \(code): \(body)"
        case .emptyBody: return "Empty response body"
        case .decoding(let msg, let sample): return "Decoding failed: \(msg)\nSample: \(sample)"
        case .badURL: return "Bad URL"
        case .unknown(let e): return e.localizedDescription
        }
    }
}

// MARK: - Config
struct USAuthConfig {
    static let alias  = "loftgolfstudios"                       // your account alias
    static let apiKey = "c9af66c8-7e45-41f8-a00e-8324df5d3036"  // X-US-Application-Key
    static let bases  = [
        "https://beta.uschedule.com",      // staging
        "https://clients.uschedule.com"    // production
    ]
}

// MARK: - Wire Models
private struct USLoginRequest: Encodable {
    let UserName: String
    let Password: String
}

private struct USRegisterRequest: Encodable {
    let UserName: String
    let Password: String
    let FirstName: String
    let LastName: String
    let Email: String
    let Phone: String?
}

// Loose decoder so schema changes don't crash
private struct USUserDetailsLoose: Decodable {
    let UserId: Int?
    let AuthKey: String?
    let AccountID: Int?
    let Username: String?
    let IsCustomer: Bool?
}

// MARK: - ViewModel
@MainActor
final class AuthViewModel: ObservableObject {
    @Published var token: String?
    @Published var lastHTTPStatus: Int?
    @Published var lastBodySample: String?

    // ---------- Public API ----------

    /// Register a user. Server enforces uniqueness (username/email/phone) and returns HTTP 400 with a reason if taken.
    func register(fullName: String,
                  email: String,
                  password: String,
                  phone: String? = nil,
                  userName: String) async throws {

        // Split full name into first/last as required by USchedule payload
        let parts = fullName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        let first = parts.first.map(String.init) ?? fullName
        let last  = parts.dropFirst().first.map(String.init) ?? ""

        // Try beta then prod
        for base in USAuthConfig.bases {
            do {
                let key = try await registerUser(
                    base: base,
                    username: userName,
                    password: password,
                    firstName: first,
                    lastName: last,
                    email: email,
                    phone: phone
                )
                self.token = key
                return
            } catch {
                if base == USAuthConfig.bases.last { throw error }
            }
        }
        throw USAuthError.unknown(URLError(.badURL))
    }

    /// ValidateUser (username + password) → AuthKey
    func login(username: String, password: String) async throws {
        for base in USAuthConfig.bases {
            do {
                let key = try await validateUser(base: base, username: username, password: password)
                self.token = key
                return
            } catch {
                if base == USAuthConfig.bases.last { throw error }
            }
        }
    }

    /// ImpersonateUser (no password; front-desk flow) → AuthKey
    func impersonate(username: String) async throws {
        for base in USAuthConfig.bases {
            do {
                let key = try await impersonateUser(base: base, username: username)
                self.token = key
                return
            } catch {
                if base == USAuthConfig.bases.last { throw error }
            }
        }
    }

    /// Example authed GET
    func fetchLocations() async throws -> Data {
        guard let token = token else { throw USAuthError.http(401, "Missing AuthToken") }
        for base in USAuthConfig.bases {
            do {
                var req = try makeRequest(base: base, path: "locations", method: "GET")
                req.setValue(token, forHTTPHeaderField: "X-US-AuthToken")
                let (data, resp) = try await URLSession.shared.data(for: req)
                guard let http = resp as? HTTPURLResponse else { throw USAuthError.unknown(URLError(.badServerResponse)) }
                lastHTTPStatus = http.statusCode
                lastBodySample = String(data: data, encoding: .utf8)
                guard http.statusCode == 200 else { throw USAuthError.http(http.statusCode, lastBodySample ?? "<empty>") }
                guard !data.isEmpty else { throw USAuthError.emptyBody }
                return data
            } catch {
                if base == USAuthConfig.bases.last { throw error }
            }
        }
        throw USAuthError.unknown(URLError(.badURL))
    }

    // ---------- Internal Calls ----------

    private func registerUser(base: String,
                              username: String,
                              password: String,
                              firstName: String,
                              lastName: String,
                              email: String,
                              phone: String?) async throws -> String {
        var req = try makeRequest(base: base, path: "RegisterUser", method: "POST")
        req.httpBody = try JSONEncoder().encode(USRegisterRequest(
            UserName: username,
            Password: password,
            FirstName: firstName,
            LastName: lastName,
            Email: email,
            Phone: phone
        ))

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw USAuthError.unknown(URLError(.badServerResponse)) }
        lastHTTPStatus = http.statusCode
        lastBodySample = String(data: data, encoding: .utf8) ?? "<empty>"

        // USchedule returns 200 + UserDetails on success, 400 with text body for validation/duplicate errors
        guard http.statusCode == 200 else {
            throw USAuthError.http(http.statusCode, lastBodySample ?? "<empty>")
        }
        guard !data.isEmpty else { throw USAuthError.emptyBody }

        do {
            let details = try JSONDecoder().decode(USUserDetailsLoose.self, from: data)
            if let key = details.AuthKey, !key.isEmpty { return key }
            throw USAuthError.decoding("Missing AuthKey in RegisterUser response", sample: lastBodySample ?? "<empty>")
        } catch let e as DecodingError {
            throw USAuthError.decoding(e.localizedDescription, sample: lastBodySample ?? "<empty>")
        } catch {
            throw USAuthError.decoding(error.localizedDescription, sample: lastBodySample ?? "<empty>")
        }
    }

    private func validateUser(base: String, username: String, password: String) async throws -> String {
        var req = try makeRequest(base: base, path: "ValidateUser", method: "POST")
        req.httpBody = try JSONEncoder().encode(USLoginRequest(UserName: username, Password: password))

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw USAuthError.unknown(URLError(.badServerResponse)) }
        lastHTTPStatus = http.statusCode
        lastBodySample = String(data: data, encoding: .utf8) ?? "<empty>"

        guard http.statusCode == 200 else { throw USAuthError.http(http.statusCode, lastBodySample ?? "<empty>") }
        guard !data.isEmpty else { throw USAuthError.emptyBody }

        do {
            let details = try JSONDecoder().decode(USUserDetailsLoose.self, from: data)
            if let key = details.AuthKey, !key.isEmpty { return key }
            throw USAuthError.decoding("Missing AuthKey in ValidateUser response", sample: lastBodySample ?? "<empty>")
        } catch let e as DecodingError {
            throw USAuthError.decoding(e.localizedDescription, sample: lastBodySample ?? "<empty>")
        } catch {
            throw USAuthError.decoding(error.localizedDescription, sample: lastBodySample ?? "<empty>")
        }
    }

    private func impersonateUser(base: String, username: String) async throws -> String {
        struct ImpReq: Encodable { let FieldName: String; let Value: String }
        var req = try makeRequest(base: base, path: "ImpersonateUser", method: "POST")
        req.httpBody = try JSONEncoder().encode(ImpReq(FieldName: "username", Value: username))

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw USAuthError.unknown(URLError(.badServerResponse)) }
        lastHTTPStatus = http.statusCode
        lastBodySample = String(data: data, encoding: .utf8) ?? "<empty>"

        guard http.statusCode == 200 else { throw USAuthError.http(http.statusCode, lastBodySample ?? "<empty>") }
        guard !data.isEmpty else { throw USAuthError.emptyBody }

        do {
            let details = try JSONDecoder().decode(USUserDetailsLoose.self, from: data)
            if let key = details.AuthKey, !key.isEmpty { return key }
            throw USAuthError.decoding("Missing AuthKey in ImpersonateUser response", sample: lastBodySample ?? "<empty>")
        } catch let e as DecodingError {
            throw USAuthError.decoding(e.localizedDescription, sample: lastBodySample ?? "<empty>")
        } catch {
            throw USAuthError.decoding(error.localizedDescription, sample: lastBodySample ?? "<empty>")
        }
    }

    private func makeRequest(base: String, path: String, method: String) throws -> URLRequest {
        guard let url = URL(string: "\(base)/api/\(USAuthConfig.alias)/\(path)") else { throw USAuthError.badURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(USAuthConfig.apiKey, forHTTPHeaderField: "X-US-Application-Key")
        req.timeoutInterval = 20
        return req
    }
}
