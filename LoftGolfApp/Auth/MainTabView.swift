//
//  MainTabView.swift
//  LoftGolfApp
//
//  Created by ZhiYue Wang on 10/14/25.
//

import SwiftUI
/// Main view with bottom navigation bar
struct MainTabView: View {
    
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Home
            HomeTabView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            // Tab 2: Courses
            CoursesTabView()
                .tabItem {
                    Label("Courses", systemImage: "map.fill")
                }
                .tag(1)
            
            // Tab 3: Profile
            ProfileTabView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(3)
        }
        .accentColor(.black)
    }
}

#Preview {
    MainTabView()
}
