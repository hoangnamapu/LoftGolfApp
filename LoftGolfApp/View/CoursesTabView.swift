//
//  CoursesTabView.swift
//  LoftGolfApp
//
//  Created by ZhiYue Wang on 10/14/25.
//

import SwiftUI
/// Courses page - blank template
struct CoursesTabView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.gray)
                    
                    Text("Courses")
                        .font(.title.bold())
                        .foregroundStyle(.primary)
                    
                    Text("This is the courses page")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Courses")
        }
    }
}

#Preview {
    CoursesTabView()
}
