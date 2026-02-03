//
//  MainTabView.swift
//  LoftGolfApp
//
//  Created by ZhiYue Wang on 10/14/25.
//

import SwiftUI

//Main view with bottom navigation bar
struct MainTabView: View {
    @State private var selectedTab = 0
    @StateObject private var authViewModel = AuthViewModel()
    @Binding var isAuthenticated: Bool
    
    // Store the auth token passed from login
    let authToken: String?
    
    init(isAuthenticated: Binding<Bool>, authToken: String? = nil) {
        self._isAuthenticated = isAuthenticated
        self.authToken = authToken
        
        // Configure Tab Bar appearance ONLY (not global tint)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(white: 0.1, alpha: 1)  // Dark gray background
        
        // Add top border line
        appearance.shadowColor = UIColor.gray.withAlphaComponent(0.3)
        
        // Unselected tab color
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.gray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.gray]
        
        // Selected tab color - green
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.systemGreen
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.systemGreen]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Home
            HomeTabView(authToken: authToken)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            // Tab 2: Rewards
            RewardsTabView()
                .tabItem {
                    Label("Rewards", systemImage: "gift.fill")
                }
                .tag(1)

            // Tab 3: Bookings
            BookingsTabView(authToken: authToken)
                .tabItem {
                    Label("Bookings", systemImage: "calendar")
                }
                .tag(2)
            
            // Tab 4: FAQ / Videos
            FaqVideosTabView()
                .tabItem {
                    Label("FAQ/Videos", systemImage: "questionmark.circle")
                }
                .tag(3)

            // Tab 5: Account with auth integration
            ProfileTabView(
                isAuthenticated: $isAuthenticated,
                authToken: authToken ?? authViewModel.token
            )
            .tabItem {
                Label("Account", systemImage: "person.fill")
            }
            .tag(4)
        }
        .onAppear {
            // Set the auth token in the view model if available
            if let token = authToken {
                authViewModel.token = token
            }
        }
    }
}

#Preview {
    MainTabView(isAuthenticated: .constant(true), authToken: nil)
}
