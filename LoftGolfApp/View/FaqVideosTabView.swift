//
//  FaqVideosTabView.swift
//  LoftGolfApp
//
//  Created by OpenAI on 2024-05-17.
//

import SwiftUI

struct FaqVideosTabView: View {
    private let faqURL = URL(string: "https://loftgolfstudios.com/faq")!
    private let videosURL = URL(string: "https://www.youtube.com/@LoftGolfStudios")!

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Support")) {
                    Link(destination: faqURL) {
                        Label("Frequently Asked Questions", systemImage: "questionmark.circle")
                    }

                    Link(destination: videosURL) {
                        Label("Video Tutorials", systemImage: "play.rectangle")
                    }
                }

                Section(header: Text("Community")) {
                    Link("Instagram", destination: URL(string: "https://www.instagram.com/loftgolfstudios")!)
                    Link("Facebook", destination: URL(string: "https://www.facebook.com/loftgolfstudios/")!)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("FAQ & Videos")
        }
    }
}

#Preview {
    FaqVideosTabView()
}
