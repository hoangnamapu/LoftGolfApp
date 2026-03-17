import Foundation

struct DoorConfig {
    // TODO: Fill in once received from sponsor (from Avigilon Alta / OpenPath admin panel)
    static let orgId       = "REPLACE_WITH_ORG_ID"        // 5-digit org ID from OpenPath admin URL
    static let token       = "REPLACE_WITH_BEARER_TOKEN"  // Cloud Key Bearer token
    static let bay1EntryId = "REPLACE_WITH_BAY1_ENTRY_ID" // Avigilon Alta entry ID for Bay 1 door
    static let bay2EntryId = "REPLACE_WITH_BAY2_ENTRY_ID" // Avigilon Alta entry ID for Bay 2 door

    // uSchedule ResourceUnitID for each bay (from /resourceunits endpoint)
    static let bay1ResourceUnitId = 5523
    static let bay2ResourceUnitId = 5524
}
