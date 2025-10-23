//
//  ProfileTabView.swift
//  LoftGolfApp
//
//  Created by ZhiYue Wang on 10/14/25.
//

import SwiftUI
/// Profile page - blank template
struct ProfileTabView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.gray)
                    
                    Text("Profile")
                        .font(.title.bold())
                        .foregroundStyle(.primary)
                    
                    Text("This is the profile page")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Profile")
        }
    }
}

#Preview {
    ProfileTabView()
}
