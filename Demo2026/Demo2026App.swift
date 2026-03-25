//
//  Demo2026App.swift
//  TestApp
//
//  Created by Wei Lin on 20/9/2025.
//

import SwiftUI

@main
struct Demo2026App: App {
    init() {
        ExpenseStore.preloadInitialData()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
