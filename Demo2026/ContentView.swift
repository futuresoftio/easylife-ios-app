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
                case .settings:
                    SettingsTabView()
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
                    title: AppTab.settings.title,
                    systemImage: AppTab.settings.systemImage,
                    isSelected: selectedTab == .settings
                ) {
                    selectedTab = .settings
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
