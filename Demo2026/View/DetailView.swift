//
//  DetailView.swift
//  TestApp
//
//  Created by Wei Lin on 20/9/2025.
//

import SwiftUI

struct DetailView: View {
    let item: String
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            Text("Detail Screen")
                .font(.largeTitle)
            Text("You selected: \(item)")
                .font(.title2)
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    onDelete()
                    dismiss()
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete Expense")
            }
        }
    }
}
