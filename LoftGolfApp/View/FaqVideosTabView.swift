//
//  FaqVideosTabView.swift
//  LoftGolfApp
//
//  Created by OpenAI on 2024-05-17.
//

import SwiftUI

struct FaqVideosTabView: View {
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Support")) {
                    LinkRow(
                        title: "Frequently Asked Questions",
                        subtitle: "Common questions answered",
                        icon: "questionmark.circle.fill",
                        iconColor: .blue,
                        url: URL(string: "https://loftgolfstudios.com/faq")!
                    )

                    LinkRow(
                        title: "Simulator How-To",
                        subtitle: "Learn how to use the simulator",
                        icon: "figure.golf",
                        iconColor: .green,
                        url: URL(string: "https://loftgolfstudios.com/simulator-how-to")!
                    )
                }

                Section(header: Text("Videos")) {
                    LinkRow(
                        title: "Video Tutorials",
                        subtitle: "Watch step-by-step guides",
                        icon: "play.rectangle.fill",
                        iconColor: .red,
                        url: URL(string: "https://www.youtube.com/@LoftGolfStudios")!
                    )

                    LinkRow(
                        title: "Loft Video Library",
                        subtitle: "Browse our full video collection",
                        icon: "film.stack",
                        iconColor: .purple,
                        url: URL(string: "https://loftgolfstudios.com/videolibrary")!
                    )
                }

                Section(header: Text("Community")) {
                    LinkRow(
                        title: "Instagram",
                        subtitle: "@loftgolfstudios",
                        icon: "camera.fill",
                        iconColor: .pink,
                        url: URL(string: "https://www.instagram.com/loftgolfstudios")!
                    )

                    LinkRow(
                        title: "Facebook",
                        subtitle: "Loft Golf Studios",
                        icon: "person.2.fill",
                        iconColor: .blue,
                        url: URL(string: "https://m.facebook.com/loftgolfstudios/")!
                    )
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("FAQ & Videos")
        }
    }
}

struct LinkRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor)
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .foregroundStyle(.primary)
    }
}

#Preview {
    FaqVideosTabView()
}
