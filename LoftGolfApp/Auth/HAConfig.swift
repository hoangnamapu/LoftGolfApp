import Foundation

struct HAConfig {
    // TODO: Fill in once received from sponsor
    static let baseURL    = "http://homeassistant.local:8123"  // replace with actual HA URL
    static let token      = "REPLACE_WITH_LONG_LIVED_TOKEN"    // HA Profile → Long-Lived Access Tokens
    static let bay1Entity = "lock.bay_1_door"                  // replace with actual HA entity ID
    static let bay2Entity = "lock.bay_2_door"                  // replace with actual HA entity ID
    static let haService  = "lock/unlock"                      // or "script/turn_on" / "switch/turn_on"

    // uSchedule ResourceUnitID for each bay (from /resourceunits endpoint)
    static let bay1ResourceUnitId = 5052
    static let bay2ResourceUnitId = 0    // TODO: get from sponsor
}
