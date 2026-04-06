//
//  Demo2026App.swift
//  TestApp
//
//  Created by Wei Lin on 20/9/2025.
//

import SwiftUI
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

@main
struct Demo2026App: App {
    init() {
        ExpenseStore.preloadInitialData()
#if canImport(GoogleMobileAds)
        MobileAds.shared.start()
#endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
