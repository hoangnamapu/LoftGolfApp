//
//  RewardsViewModel.swift
//  LoftGolfApp
//
//  Created by Mattias Benally on 2/24/26.
//


import SwiftUI

@MainActor
final class RewardsViewModel: ObservableObject {
    @Published var loyaltyPoints: Int = 0
    @Published var currentProgressPoints: Int = 0
    @Published var pointsToNextReward: Int = 50
    @Published var earnedFreeSessions: Int = 0

    @Published var didFollow: Bool = false
    @Published var didPostStory: Bool = false
    @Published var didReview: Bool = false

    private var authToken: String?

    func setAuthToken(_ token: String) {
        self.authToken = token
    }

    func loadRewards() async {
        guard let authToken = authToken, !authToken.isEmpty else {
            return
        }

        guard let url = URL(string: "\(USAuthConfig.bases[0])/api/\(USAuthConfig.alias)/customer") else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(authToken, forHTTPHeaderField: "X-US-AuthToken")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(USAuthConfig.apiKey, forHTTPHeaderField: "X-US-Application-Key")
        request.httpBody = Data("{}".utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let customer = try JSONDecoder().decode(CustomerResponse.self, from: data)

            loyaltyPoints = customer.loyaltyPointTotal
            earnedFreeSessions = loyaltyPoints / 50
            currentProgressPoints = loyaltyPoints % 50

            let remainder = loyaltyPoints % 50
            pointsToNextReward = remainder == 0 ? 0 : 50 - remainder
        } catch {
            print("Failed to load rewards:", error)
        }
    }

    var progressMessage: String {
        if loyaltyPoints == 0 {
            return "You are 50 points away from earning 1 FREE 55 MIN SESSION."
        }

        if pointsToNextReward == 0 {
            if earnedFreeSessions == 1 {
                return "Congratulations, you have earned a free hour!"
            } else {
                return "Congratulations, you have earned \(earnedFreeSessions) free 55 minute sessions!"
            }
        }

        let nextSessionNumber = earnedFreeSessions + 1

        if nextSessionNumber == 1 {
            return "You are only \(pointsToNextReward) points away from a free hour!"
        } else if nextSessionNumber == 2 {
            return "You are only \(pointsToNextReward) points away from a second free hour!"
        } else {
            return "You are only \(pointsToNextReward) points away from your \(nextSessionNumber.ordinalSuffix) free hour!"
        }
    }
}

struct CustomerResponse: Decodable {
    let loyaltyPointTotal: Int

    enum CodingKeys: String, CodingKey {
        case loyaltyPointTotal = "LoyaltyPointTotal"
    }
}

private extension Int {
    var ordinalSuffix: String {
        switch self {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(self)th"
        }
    }
}
