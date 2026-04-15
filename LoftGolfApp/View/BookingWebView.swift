//
//  BookingWebView.swift
//  LoftGolfApp
//
//  Created by ZhiYue Wang on 3/19/26.
//

import SwiftUI
import WebKit

struct BookingWebView: View {
    let authToken: String?
    var showNavBar = true
    var targetURL: String = "https://clients.uschedule.com/loftgolfstudios/booking"
    var title: String = "Book a Session"
    var showDismissButton = false

    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var reloadTrigger = UUID()

    var body: some View {
        NavigationStack {
            ZStack {
                BookingWKWebView(authToken: authToken, isLoading: $isLoading, targetURL: targetURL)
                    .ignoresSafeArea(edges: .bottom)
                    .id(reloadTrigger)

                if isLoading {
                    ProgressView("Loading...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 4)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                reloadTrigger = UUID()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if showDismissButton {
                        Button("Done") { dismiss() }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    EmptyView()
                }
            }
        }
    }
}

struct BookingWKWebView: UIViewRepresentable {
    let authToken: String?
    @Binding var isLoading: Bool
    let targetURL: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator

        if let token = authToken {
            // Load remotelogin first — uSchedule will set session cookie then redirect
            let loginURLString = "https://clients.uschedule.com/loftgolfstudios/account/remotelogin?authKey=\(token)"
            if let url = URL(string: loginURLString) {
                webView.load(URLRequest(url: url))
            }
        } else {
            // No token — go straight to target page (user may need to log in manually)
            if let url = URL(string: targetURL) {
                webView.load(URLRequest(url: url))
            }
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: BookingWKWebView

        init(_ parent: BookingWKWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }

            // After remotelogin completes, redirect to the configured target page
            guard let currentURL = webView.url?.absoluteString else { return }
            if currentURL.contains("remotelogin") {
                if let url = URL(string: parent.targetURL) {
                    webView.load(URLRequest(url: url))
                }
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
    }
}
