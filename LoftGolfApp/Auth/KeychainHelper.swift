import Foundation
import Security

enum AppKeychain {
    static func save(_ data: Data, account: String) {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        SecItemDelete(q as CFDictionary)
        SecItemAdd(q as CFDictionary, nil)
    }

    static func load(account: String) -> Data? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var out: CFTypeRef?
        SecItemCopyMatching(q as CFDictionary, &out)
        return out as? Data
    }

    static func delete(account: String) {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(q as CFDictionary)
    }
}

struct ProfileCardDisplay: Codable {
    let nameOnCard: String
    let last4: String
    let expMonth: Int
    let expYear: Int
}

private let kProfileCardAccount = "profile.card.display"

func saveProfileCardDisplay(_ c: ProfileCardDisplay) {
    let data = try! JSONEncoder().encode(c)
    AppKeychain.save(data, account: kProfileCardAccount)
}

func loadProfileCardDisplay() -> ProfileCardDisplay? {
    guard let d = AppKeychain.load(account: kProfileCardAccount) else { return nil }
    return try? JSONDecoder().decode(ProfileCardDisplay.self, from: d)
}

func deleteProfileCardDisplay() {
    AppKeychain.delete(account: kProfileCardAccount)
}
