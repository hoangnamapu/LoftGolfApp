//
//  BookingsTabView.swift
//  LoftGolfApp
//
//  Created by OpenAI on 2024-05-17.
//

import SwiftUI

struct BookingsTabView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "calendar")
                    .font(.system(size: 56))
                    .foregroundColor(.accentColor)
                    .padding(.top, 40)

                Text("Manage Your Bookings")
                    .font(.title2.bold())

                Text("View upcoming sessions, review past visits, and stay on top of everything happening at Loft Golf.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Bookings")
        }
    }
}

#Preview {
    BookingsTabView()
}
