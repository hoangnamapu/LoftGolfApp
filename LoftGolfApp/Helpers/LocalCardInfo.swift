import Foundation


struct LocalCardInfo: Codable {
    let brand: String
    let last4: String
    let expMonth: Int
    let expYear: Int
}


struct LocalCardStore {

    private static let key = "local_saved_card"

    static func save(_ card: LocalCardInfo) {
        if let data = try? JSONEncoder().encode(card) {
            KeychainHelper.save(data, key: key)
        }
    }

    static func load() -> LocalCardInfo? {
        guard let data = KeychainHelper.read(key: key) else { return nil }
        return try? JSONDecoder().decode(LocalCardInfo.self, from: data)
    }

    static func clear() {
        KeychainHelper.delete(key: key)
    }
}
