//
//  RewardsTabView.swift
//  LoftGolfApp
//
//  Created by OpenAI on 2024-05-17.
//

import SwiftUI

struct RewardsTabView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.white)
                        .padding()
                        .background(Circle().fill(Color.accentColor))
                        .padding(.top, 32)

                    Text("Rewards Coming Soon")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Text("Earn and redeem Loft Golf rewards directly from the app. Stay tuned for exclusive offers and loyalty benefits.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Rewards")
        }
    }
}

#Preview {
    RewardsTabView()
}
