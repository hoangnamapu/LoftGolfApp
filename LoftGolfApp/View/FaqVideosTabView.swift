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
                    VStack(alignment: .leading, spacing: 20) {
                        Text("FAQ & Videos")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.top, 20)

                        faqSection(
                            title: "Support",
                            rows: [
                                FAQRowData(
                                    title: "Frequently Asked Questions",
                                    subtitle: "Common questions answered",
                                    icon: "questionmark.circle.fill",
                                    iconColor: .blue,
                                    url: URL(string: "https://loftgolfstudios.com/faq")!
                                ),
                                FAQRowData(
                                    title: "Simulator How-To",
                                    subtitle: "Learn how to use the simulator",
                                    icon: "figure.golf",
                                    iconColor: .green,
                                    url: URL(string: "https://loftgolfstudios.com/simulator-how-to")!
                                )
                            ]
                        )

                        faqSection(
                            title: "Videos",
                            rows: [
                                FAQRowData(
                                    title: "Video Tutorials",
                                    subtitle: "Watch step-by-step guides",
                                    icon: "play.rectangle.fill",
                                    iconColor: .red,
                                    url: URL(string: "https://www.youtube.com/@LoftGolfStudios")!
                                ),
                                FAQRowData(
                                    title: "Loft Video Library",
                                    subtitle: "Browse our full video collection",
                                    icon: "film.stack",
                                    iconColor: .purple,
                                    url: URL(string: "https://loftgolfstudios.com/videolibrary")!
                                )
                            ]
                        )

                        faqSection(
                            title: "Community",
                            rows: [
                                FAQRowData(
                                    title: "Instagram",
                                    subtitle: "@loftgolfstudios",
                                    icon: "camera.fill",
                                    iconColor: .pink,
                                    url: URL(string: "https://www.instagram.com/loftgolfstudios")!
                                ),
                                FAQRowData(
                                    title: "Facebook",
                                    subtitle: "Loft Golf Studios",
                                    icon: "person.2.fill",
                                    iconColor: .blue,
                                    url: URL(string: "https://m.facebook.com/loftgolfstudios/")!
                                )
                            ]
                        )
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private func faqSection(title: String, rows: [FAQRowData]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.gray)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    LinkRow(
                        title: row.title,
                        subtitle: row.subtitle,
                        icon: row.icon,
                        iconColor: row.iconColor,
                        url: row.url
                    )

                    if index < rows.count - 1 {
                        Divider()
                            .background(Color.gray.opacity(0.3))
                            .padding(.leading, 50)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6).opacity(0.15))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

struct FAQRowData {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let url: URL
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
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FaqVideosTabView()
}
