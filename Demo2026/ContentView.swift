//
//  ContentView.swift
//  TestApp
//
//  Created by Wei Lin on 20/9/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .home

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .home:
                    HomeView()
                case .report:
                    ReportTabView()
                }
            }
            Divider()
            HStack(spacing: 0) {
                TabBarButton(
                    title: AppTab.home.title,
                    systemImage: AppTab.home.systemImage,
                    isSelected: selectedTab == .home
                ) {
                    selectedTab = .home
                }
                TabBarButton(
                    title: AppTab.report.title,
                    systemImage: AppTab.report.systemImage,
                    isSelected: selectedTab == .report
                ) {
                    selectedTab = .report
                }
            }
            .padding(.vertical, 12)
            .background(.thinMaterial)
        }
    }
}

#Preview {
    ContentView()
}
