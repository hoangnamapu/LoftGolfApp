//
//  HomeTabView.swift
//  LoftGolfApp
//
//  Created by ZhiYue Wang on 10/14/25.
//

import SwiftUI
/// Home page - blank template
struct HomeTabView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.gray)
                    
                    Text("Home")
                        .font(.title.bold())
                        .foregroundStyle(.primary)
                    
                    Text("This is the home page")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Home")
        }
    }
}

#Preview {
    HomeTabView()
}
