//
//  PaymentCardKeychainManager.swift
//  LoftGolfApp
//
//  IMPORTANT: This stores MINIMAL card info for display purposes only.
//  Full card details are NEVER stored - only last 4 digits and billing info.
//  User must re-enter card number and CVV for each transaction.
//

import Foundation
import Security

// Minimal card data for display - NEVER stores full card number or CVV
struct SavedCardDisplay: Codable, Equatable {
    let last4Digits: String
    let nameOnCard: String
    let expMonth: Int
    let expYear: Int
    let cardType: String // "Visa", "Mastercard", etc.
    
    // Billing info can be stored for convenience
    var billingAddress: String = ""
    var billingCity: String = ""
    var billingState: String = ""
    var billingZip: String = ""
    
    var isExpired: Bool {
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)
        
        if expYear < currentYear {
            return true
        }
        if expYear == currentYear && expMonth < currentMonth {
            return true
        }
        return false
    }
}

class PaymentCardKeychainManager {
    static let shared = PaymentCardKeychainManager()
    
    private let service = "com.loftgolf.savedcards"
    private let accountKey = "saved_card_display"
    
    private init() {}
    
    // MARK: - Save Card Display Info
    
    /// Saves minimal card info (last 4, expiry, billing) for display
    func saveCardDisplay(from card: PaymentCardFormData) {
        guard card.number.count >= 4 else { return }
        
        let cardType = detectCardType(card.number)
        let displayCard = SavedCardDisplay(
            last4Digits: String(card.number.suffix(4)),
            nameOnCard: card.nameOnCard,
            expMonth: card.expMonth ?? 0,
            expYear: card.expYear ?? 0,
            cardType: cardType,
            billingAddress: card.billingAddress,
            billingCity: card.billingCity,
            billingState: card.billingState,
            billingZip: card.billingZip
        )
        
        var cards = loadAllCardDisplays()
        // Remove duplicate if exists
        cards.removeAll { $0.last4Digits == displayCard.last4Digits }
        cards.append(displayCard)
        saveAllCardDisplays(cards)
    }
    
    private func saveAllCardDisplays(_ cards: [SavedCardDisplay]) {
        guard let data = try? JSONEncoder().encode(cards) else {
            print("Failed to encode card displays")
            return
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            print("✅ Card display info saved")
        } else {
            print("❌ Failed to save: \(status)")
        }
    }
    
    // MARK: - Load Card Display Info
    
    func loadAllCardDisplays() -> [SavedCardDisplay] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let cards = try? JSONDecoder().decode([SavedCardDisplay].self, from: data) else {
            return []
        }
        
        // Filter out expired cards
        return cards.filter { !$0.isExpired }
    }
    
    // MARK: - Delete Cards
    
    func deleteCardDisplay(last4: String) {
        var cards = loadAllCardDisplays()
        cards.removeAll { $0.last4Digits == last4 }
        saveAllCardDisplays(cards)
    }
    
    func deleteAllCardDisplays() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Card Type Detection
    
    private func detectCardType(_ number: String) -> String {
        let digits = number.filter { $0.isNumber }
        guard !digits.isEmpty else { return "Unknown" }
        
        let firstDigit = String(digits.prefix(1))
        let firstTwo = String(digits.prefix(2))
        
        if firstDigit == "4" {
            return "Visa"
        } else if ["51", "52", "53", "54", "55"].contains(firstTwo) {
            return "Mastercard"
        } else if ["34", "37"].contains(firstTwo) {
            return "American Express"
        } else if firstTwo == "60" || firstTwo == "65" {
            return "Discover"
        }
        
        return "Card"
    }
}

// MARK: - USchedule API Credit Card Model

struct UScheduleCreditCard: Codable {
    let cardName: String        // CardName
    let cardNumber: String      // CardNumber
    let cardExpMonth: String    // CardExpMonth (as string)
    let cardExpYear: String     // CardExpYear (4-digit year as string)
    let cardSecurityCode: String // CardSecurityCode (CVV)
    
    init(from card: PaymentCardFormData) {
        self.cardName = card.nameOnCard
        self.cardNumber = card.number
        self.cardExpMonth = String(format: "%02d", card.expMonth ?? 1)
        self.cardExpYear = String(card.expYear ?? 2025)
        self.cardSecurityCode = card.cvv
    }
}
