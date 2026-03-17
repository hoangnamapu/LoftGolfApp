import Foundation

struct DoorConfig {
    // TODO: Fill in once received from sponsor
    // Bot user must be a native Avigilon Alta account (NOT Google/SSO login)
    // Create the user in the Avigilon Alta admin panel with Super Admin role + access to the entry
    static let orgId       = "REPLACE_WITH_ORG_ID"        // 5-digit org ID from Avigilon Alta admin URL
    static let botEmail    = "REPLACE_WITH_BOT_EMAIL"     // Bot user email (e.g. app@loftgolfstudios.com)
    static let botPassword = "REPLACE_WITH_BOT_PASSWORD"  // Bot user password
    static let entryId     = "REPLACE_WITH_ENTRY_ID"      // Avigilon Alta entry ID for the entrance door

    // uSchedule ResourceUnitID for each bay (from /resourceunits endpoint)
    static let bay1ResourceUnitId = 5523
    static let bay2ResourceUnitId = 5524
}

// In-memory JWT cache — avoids logging in on every door tap
enum AvigilonTokenCache {
    static var jwt: String?
    static var expiresAt: Date?

    static var isValid: Bool {
        guard let jwt, !jwt.isEmpty, let exp = expiresAt else { return false }
        return exp > Date().addingTimeInterval(300) // 5-min buffer
    }
}
