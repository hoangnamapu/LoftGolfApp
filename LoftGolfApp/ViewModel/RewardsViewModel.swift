import SwiftUI

@MainActor
final class RewardsViewModel: ObservableObject {
    @Published var loyaltyPoints: Int = 0
    @Published var pointsToNextReward: Int = 100
    @Published var canRedeemHours: Int = 0

    @Published var anytimeCredits: Int = 0
    @Published var weekdayCredits: Int = 0

    // Ladder placeholders (until your backend supports it)
    @Published var didFollow: Bool = false
    @Published var didPostStory: Bool = false
    @Published var didReview: Bool = false

    private var authToken: String?

    func setAuthToken(_ token: String) {
        self.authToken = token
    }

    func loadRewards() async {
        // TODO: replace with real API calls
        // For now this lets you test the UI immediately.

        loyaltyPoints = 35
        pointsToNextReward = max(0, 100 - loyaltyPoints)
        canRedeemHours = loyaltyPoints / 100

        anytimeCredits = 1
        weekdayCredits = 2

        didFollow = true
        didPostStory = false
        didReview = false
    }
}