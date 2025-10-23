import Foundation
import Combine

// Example model you return from /customer
struct CustomerProfile {
    let reference1: String?
    let reference2: String?
    let reference3: String?
    let statusId: Int?
}

extension AuthViewModel {
    func getCustomer() async throws -> CustomerProfile {
        // Call USchedule `GET /api/{alias}/customer` with X-US-AuthToken
        // Map JSON -> CustomerProfile(reference1:, reference2:, reference3:, statusId:)
        fatalError("Implement network call here")
    }
}

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

    // Staging then Production (will fall through to next if first fails)
    static let bases  = [
        "https://beta.uschedule.com",
        "https://clients.uschedule.com"
    ]

    // If your USchedule tenant mirrors email into Reference1 (or uses email as username),
    // you can proactively check email uniqueness before registering:
    static let probeEmailViaReference1 = false
}

// MARK: - Helpers
private extension String {
    var trimmedLowercased: String {
        self.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    var digitsOnly: String {
        self.filter(\.isNumber)
    }
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

// MARK: - Duplicate Parsing
private enum DuplicateField: String { case username, email, phone, customer }

private func parseDuplicateField(_ text: String) -> DuplicateField? {
    let s = text.lowercased()
    if s.contains("username") && (s.contains("exist") || s.contains("taken")) { return .username }
    if s.contains("email")    && (s.contains("exist") || s.contains("already")) { return .email }
    if s.contains("phone")    && (s.contains("exist") || s.contains("already")) { return .phone }
    if s.contains("customer") && (s.contains("already") || s.contains("in the system")) { return .customer }
    return nil
}

private func isResetPasswordHint(_ text: String) -> Bool {
    let s = text.lowercased()
    return s.contains("reset password") || s.contains("password reset")
}

// MARK: - ViewModel
@MainActor
final class AuthViewModel: ObservableObject {
    @Published var token: String?
    @Published var lastHTTPStatus: Int?
    @Published var lastBodySample: String?

    // ---------- Public API ----------

    /// Register a user. We proactively pre-check username (and optionally email via Reference1) using ImpersonateUser,
    /// then call USchedule RegisterUser which enforces uniqueness and returns 400 on duplicates.
    func register(fullName: String,
                  email: String,
                  password: String,
                  phone: String? = nil,
                  userName: String) async throws {

        // Normalize inputs to avoid case/format duplicates
        let normalizedEmail = email.trimmedLowercased
        let normalizedUser  = userName.trimmedLowercased
        let normalizedPhone = phone?.digitsOnly

        // Split full name into first/last as RegisterUser expects
        let parts = fullName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        let first = parts.first.map(String.init) ?? fullName
        let last  = parts.dropFirst().first.map(String.init) ?? ""

        // ---- Pre-checks (best-effort, do not replace server validation) ----
        if await userExists(by: "username", value: normalizedUser) {
            throw USAuthError.http(400, "Username already exists")
        }
        if USAuthConfig.probeEmailViaReference1 {
            if await userExists(by: "Reference1", value: normalizedEmail) {
                throw USAuthError.http(400, "Email already in use")
            }
        }
        // If your usernames ARE emails, the username pre-check already covers email.

        // ---- Try staging then prod ----
        for base in USAuthConfig.bases {
            do {
                let key = try await registerUser(
                    base: base,
                    username: normalizedUser,
                    password: password,
                    firstName: first,
                    lastName: last,
                    email: normalizedEmail,
                    phone: normalizedPhone
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
        let u = username.trimmedLowercased
        for base in USAuthConfig.bases {
            do {
                let key = try await validateUser(base: base, username: u, password: password)
                self.token = key
                return
            } catch {
                if base == USAuthConfig.bases.last { throw error }
            }
        }
    }

    /// ImpersonateUser (no password; front-desk flow) → AuthKey
    func impersonate(username: String) async throws {
        let u = username.trimmedLowercased
        for base in USAuthConfig.bases {
            do {
                let key = try await impersonateUser(base: base, username: u)
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

    /// Best-effort probe for existing user. Returns true if user exists.
    /// fieldName: "username" (typical), "CustomerId", or client-defined "Reference1/2/3".
    func userExists(by fieldName: String = "username", value: String) async -> Bool {
        struct ImpReq: Encodable { let FieldName: String; let Value: String }
        for base in USAuthConfig.bases {
            do {
                var req = try makeRequest(base: base, path: "ImpersonateUser", method: "POST")
                req.httpBody = try JSONEncoder().encode(ImpReq(FieldName: fieldName, Value: value))
                let (_, resp) = try await URLSession.shared.data(for: req)
                guard let http = resp as? HTTPURLResponse else { continue }
                if http.statusCode == 200 { return true }   // user found
                if http.statusCode == 401 { continue }      // not found, try next base
            } catch {
                // ignore and try next base
            }
        }
        return false
    }

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

        // 200 => success with UserDetails; 400 => duplicate/validation; others => error
        if http.statusCode != 200 {
            if http.statusCode == 400, let body = lastBodySample {
                if let which = parseDuplicateField(body) {
                    throw USAuthError.http(400, "Duplicate \(which.rawValue): \(body)")
                }
                if isResetPasswordHint(body) {
                    throw USAuthError.http(400, "Account exists. Try password reset. Details: \(body)")
                }
            }
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
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(USAuthConfig.apiKey, forHTTPHeaderField: "X-US-Application-Key")
        req.timeoutInterval = 20
        return req
    }
}
