//
//  TabBarButton.swift
//  TestApp
//
//  Created by Wei Lin on 20/9/2025.
//

import SwiftUI

enum AppTab {
    case home
    case report

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .report:
            return "Report"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            return "house"
        case .report:
            return "chart.bar"
        }
    }
}

struct TabBarButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                Text(title)
                    .font(.caption)
            }
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
