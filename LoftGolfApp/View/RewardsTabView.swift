//
//  RewardsTabView.swift
//  LoftGolfApp
//
//  Created by Mattias Benally.
//

import SwiftUI

struct RewardsTabView: View {
    @StateObject private var viewModel: RewardsViewModel

    let authToken: String?

    init(authToken: String? = nil, previewModel: RewardsViewModel? = nil) {
        self.authToken = authToken
        _viewModel = StateObject(wrappedValue: previewModel ?? RewardsViewModel())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.black,
                        Color.black,
                        Color.black,
                        Color.black,
                        Color.black,
                        Color(.systemGray6).opacity(0.25),
                        Color.white
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        Text("Rewards")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.top, 20)

                        loyaltyPointsCard
                        if viewModel.anytimeCredits > 0  {
                            freeCreditsCard
                        }
                        ladderRewardsCard
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .task {
                #if DEBUG
                if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                    return
                }
                #endif

                if let token = authToken, !token.isEmpty {
                    print("RewardsTabView received token:", token)
                    viewModel.setAuthToken(token)
                } else {
                    print("RewardsTabView authToken is nil or empty")
                }

                await viewModel.loadRewards()
            }
            .refreshable {
                #if DEBUG
                if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                    return
                }
                #endif

                print("RewardsTabView refresh triggered")
                await viewModel.loadRewards()
            }
        }
    }

    // MARK: - Loyalty Points
    private var loyaltyPointsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.circle.fill")
                    .foregroundStyle(.green)
                Text("Loyalty Points")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
            }
            HalfCircleProgressView(
                progress: Double(viewModel.currentProgressPoints) / 50.0,
                value: "\(viewModel.currentProgressPoints)",
                color: .green
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)

            Text("You have \(viewModel.currentProgressPoints) Loyalty Points")     .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)

            if viewModel.anytimeCredits > 0 && viewModel.currentProgressPoints == 0 {
                Text("Your loyalty points have converted into \(viewModel.anytimeCredits) Anytime Credit(s).")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 4)
            } else {
                Text("You are \(viewModel.pointsToNextReward) points away from earning 1 Anytime Credit.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 4)
            }

            Divider().background(Color.gray.opacity(0.3))

            Text("Points are earned from paid hours. Prepaid/free credits do not generate loyalty points. 1 Booked Session = 10 points.")
                .font(.caption)
                .foregroundStyle(.gray)
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.15))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Free Credits
    private var freeCreditsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "ticket.fill")
                    .foregroundStyle(.green)
                Text("Anytime Credit")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                creditRow(title: "Available Anytime Credit", value: viewModel.anytimeCredits)
            }

            Divider().background(Color.gray.opacity(0.3))

            Text("Every 50 loyalty points converts into 1 Anytime Credit.")
                .font(.caption)
                .foregroundStyle(.gray)
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.15))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }

    private func creditRow(title: String, value: Int) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Spacer()
            Text("\(value)")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.green)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Ladder Rewards
    private var ladderRewardsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gift.fill")
                    .foregroundStyle(.green)
                Text("Earn Rewards")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
            }

            Text("Complete actions to earn a free 1-hour Anytime credit.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))

            VStack(spacing: 10) {
                ladderRow(
                        title: "Follow Loft Golf on Instagram",
                        isDone: viewModel.didFollow,
                        link: "https://www.instagram.com/loftgolfstudios"
                    )

                ladderRow(
                        title: "Post a story and tag Loft Golf",
                        isDone: viewModel.didPostStory,
                        link: "https://www.instagram.com/loftgolfstudios"
                    )
                
                ladderRow(
                        title: "Leave a Yelp Review",
                        isDone: viewModel.didReview,
                        link: "https://www.yelp.com/biz/loft-golf-studios-tempe"
                    )
            }

            Divider().background(Color.gray.opacity(0.3))

            Text("Once you complete all three, your account receives 1 Free Anytime Credit.")
                .font(.caption)
                .foregroundStyle(.gray)

            Button {
                // Placeholder for future action
            } label: {
                Text("Coming Soon")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .disabled(true)
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.15))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }

    private func ladderRow(title: String, isDone: Bool, link: String? = nil) -> some View {
        HStack {

            if let link = link, let url = URL(string: link) {
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.blue)

                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 12))
                            .foregroundStyle(.blue)
                    }
                }
            } else {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Spacer()

            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isDone ? .green : .gray)
                .font(.system(size: 20))
                .frame(width: 22)
        }
        .padding(.vertical, 6)
    }
}

#Preview("User WITH 2 anytime credits") {
    let vm = RewardsViewModel()
    vm.loyaltyPoints = 100
    vm.currentProgressPoints = 0
    vm.anytimeCredits = 2
    vm.pointsToNextReward = 0
    vm.canRedeemHours = 2
    return RewardsTabView(authToken: nil, previewModel: vm)
}
#Preview("User earning toward next credit") {
    let vm = RewardsViewModel()
    vm.loyaltyPoints = 35
    vm.currentProgressPoints = 35
    vm.anytimeCredits = 0
    vm.pointsToNextReward = 15
    vm.canRedeemHours = 0
    return RewardsTabView(authToken: nil, previewModel: vm)
}

#Preview("User WITH 2 credits + progress (125 pts)") {
    let vm = RewardsViewModel()
    vm.loyaltyPoints = 125
    vm.currentProgressPoints = 25
    vm.anytimeCredits = 2
    vm.pointsToNextReward = 25
    vm.canRedeemHours = 2
    return RewardsTabView(authToken: nil, previewModel: vm)
}

struct HalfCircleProgressView: View {
    var progress: Double          // 0.0 ... 1.0
    var value: String
    var color: Color = .green

    var body: some View {
        ZStack {
            // Track (top half)
            Circle()
                .trim(from: 0.0, to: 0.5)
                .stroke(Color.gray.opacity(0.25), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(180))

            // Progress (top half)
            Circle()
                .trim(from: 0.0, to: min(max(progress, 0), 1) * 0.5)
                .stroke(color, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(180))
                .animation(.easeOut(duration: 0.8), value: progress)

            // Value centered inside the gauge
            Text(value)
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 170, height: 110)   // card-gauge look
    }
}
