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

            Text("You have \(viewModel.loyaltyPoints) Loyalty Points")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)

            Text(viewModel.progressMessage)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.top, 4)

            Divider().background(Color.gray.opacity(0.3))

            Text("50 points = 1 FREE 55 MIN SESSION. Points are earned from paid hours. Prepaid discount cards do not generate loyalty points.")
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


}

#Preview("0 Points") {
    let vm = RewardsViewModel()
    vm.loyaltyPoints = 0
    vm.currentProgressPoints = 0
    vm.pointsToNextReward = 50
    vm.earnedFreeSessions = 0
    return RewardsTabView(authToken: nil, previewModel: vm)
}

#Preview("40 Points") {
    let vm = RewardsViewModel()
    vm.loyaltyPoints = 40
    vm.currentProgressPoints = 40
    vm.pointsToNextReward = 10
    vm.earnedFreeSessions = 0
    return RewardsTabView(authToken: nil, previewModel: vm)
}

#Preview("190 Points") {
    let vm = RewardsViewModel()
    vm.loyaltyPoints = 190
    vm.currentProgressPoints = 40
    vm.pointsToNextReward = 10
    vm.earnedFreeSessions = 3
    return RewardsTabView(authToken: nil, previewModel: vm)
}

#Preview("100 Points") {
    let vm = RewardsViewModel()
    vm.loyaltyPoints = 100
    vm.currentProgressPoints = 0
    vm.pointsToNextReward = 0
    vm.earnedFreeSessions = 2
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
