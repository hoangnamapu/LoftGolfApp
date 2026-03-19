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
    @Published var pointsToNextReward: Int = 50
    @Published var canRedeemHours: Int = 0
    @Published var currentProgressPoints: Int = 0
    @Published var anytimeCredits: Int = 0

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
            anytimeCredits = loyaltyPoints / 50
            canRedeemHours = anytimeCredits
            currentProgressPoints = loyaltyPoints % 50

            let remainder = loyaltyPoints % 50
            pointsToNextReward = remainder == 0 ? 0 : 50 - remainder
        } catch {
            print("Failed to load rewards:", error)
        }
    }
}

struct CustomerResponse: Decodable {
    let loyaltyPointTotal: Int

    enum CodingKeys: String, CodingKey {
        case loyaltyPointTotal = "LoyaltyPointTotal"
    }
}
