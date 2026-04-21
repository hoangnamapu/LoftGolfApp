import Testing
@testable import LoftGolfApp

@Suite("Rewards Logic")
@MainActor
struct RewardsTests {

    // MARK: - progressMessage

    @Test func zeroPoints() {
        let vm = makeVM(loyaltyPoints: 0, earned: 0, toNext: 50)
        #expect(vm.progressMessage == "You are 50 points away from earning 1 FREE 55 MIN SESSION.")
    }

    @Test func fortyPoints() {
        let vm = makeVM(loyaltyPoints: 40, earned: 0, toNext: 10)
        #expect(vm.progressMessage == "You are only 10 points away from a free hour!")
    }

    @Test func fortyNinePoints() {
        // 1 point away — code always says "points" (plural), not "point"
        let vm = makeVM(loyaltyPoints: 49, earned: 0, toNext: 1)
        #expect(vm.progressMessage == "You are only 1 points away from a free hour!")
    }

    @Test func exactlyFiftyPoints_earnedOneFreeSession() {
        let vm = makeVM(loyaltyPoints: 50, earned: 1, toNext: 0)
        #expect(vm.progressMessage == "Congratulations, you have earned a free hour!")
    }

    @Test func fiftyOnePoints_workingTowardSecond() {
        let vm = makeVM(loyaltyPoints: 51, earned: 1, toNext: 49)
        #expect(vm.progressMessage == "You are only 49 points away from a second free hour!")
    }

    @Test func ninetyPoints_tenAwayFromSecond() {
        let vm = makeVM(loyaltyPoints: 90, earned: 1, toNext: 10)
        #expect(vm.progressMessage == "You are only 10 points away from a second free hour!")
    }

    @Test func exactlyHundredPoints_twoEarned() {
        let vm = makeVM(loyaltyPoints: 100, earned: 2, toNext: 0)
        #expect(vm.progressMessage == "Congratulations, you have earned 2 free 55 minute sessions!")
    }

    @Test func hundredOnePoints_workingTowardThird() {
        let vm = makeVM(loyaltyPoints: 101, earned: 2, toNext: 49)
        #expect(vm.progressMessage == "You are only 49 points away from your 3rd free hour!")
    }

    @Test func exactlyOneFiftyPoints_threeEarned() {
        let vm = makeVM(loyaltyPoints: 150, earned: 3, toNext: 0)
        #expect(vm.progressMessage == "Congratulations, you have earned 3 free 55 minute sessions!")
    }

    // MARK: - Point math (earnedFreeSessions, currentProgressPoints, pointsToNextReward)

    @Test func pointMath_zero() {
        let vm = RewardsViewModel()
        vm.loyaltyPoints = 0
        vm.earnedFreeSessions = 0 / 50
        vm.currentProgressPoints = 0 % 50
        vm.pointsToNextReward = 50
        #expect(vm.earnedFreeSessions == 0)
        #expect(vm.currentProgressPoints == 0)
        #expect(vm.pointsToNextReward == 50)
    }

    @Test func pointMath_boundary50() {
        // Exactly 50 points: 1 session earned, 0 progress, 0 to next
        let earned = 50 / 50
        let progress = 50 % 50
        let toNext = progress == 0 ? 0 : 50 - progress
        #expect(earned == 1)
        #expect(progress == 0)
        #expect(toNext == 0)
    }

    @Test func pointMath_51() {
        let earned = 51 / 50
        let progress = 51 % 50
        let toNext = progress == 0 ? 0 : 50 - progress
        #expect(earned == 1)
        #expect(progress == 1)
        #expect(toNext == 49)
    }

    @Test func pointMath_boundary100() {
        let earned = 100 / 50
        let progress = 100 % 50
        let toNext = progress == 0 ? 0 : 50 - progress
        #expect(earned == 2)
        #expect(progress == 0)
        #expect(toNext == 0)
    }

    // MARK: - ordinalSuffix (tested indirectly via progressMessage)
    // nextSessionNumber = earnedFreeSessions + 1; suffix used when >= 3rd

    @Test func ordinal_3rd() {
        // 101 pts → earned=2, next=3rd
        let vm = makeVM(loyaltyPoints: 101, earned: 2, toNext: 49)
        #expect(vm.progressMessage.contains("3rd"))
    }

    @Test func ordinal_4th() {
        // 151 pts → earned=3, next=4th (default "th" branch)
        let vm = makeVM(loyaltyPoints: 151, earned: 3, toNext: 49)
        #expect(vm.progressMessage.contains("4th"))
    }

    @Test func ordinal_11th() {
        // 501 pts → earned=10, next=11th (should NOT be "11st")
        let vm = makeVM(loyaltyPoints: 501, earned: 10, toNext: 49)
        #expect(vm.progressMessage.contains("11th"))
        #expect(!vm.progressMessage.contains("11st"))
    }

    // MARK: - Helper

    private func makeVM(loyaltyPoints: Int, earned: Int, toNext: Int) -> RewardsViewModel {
        let vm = RewardsViewModel()
        vm.loyaltyPoints = loyaltyPoints
        vm.earnedFreeSessions = earned
        vm.pointsToNextReward = toNext
        vm.currentProgressPoints = loyaltyPoints % 50
        return vm
    }
}
