//
//  ReportView.swift
//  TestApp
//
//  Created by Wei Lin on 20/9/2025.
//

import SwiftUI
import Charts
#if canImport(GoogleMobileAds)
import GoogleMobileAds
import UIKit
#endif

struct ReportView: View {
    private struct SharedBackupFile: Identifiable {
        let id = UUID()
        let url: URL
    }

    @State private var dailySummaries: [DailyExpenseSummary] = []
    @State private var selectedDate = Date()
    @State private var sharedBackupFile: SharedBackupFile?
    @State private var alertMessage: String?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var calendar: Calendar {
        Calendar.current
    }

    private var monthSymbols: [String] {
        calendar.monthSymbols
    }

    private var selectedMonth: Int {
        calendar.component(.month, from: selectedDate)
    }

    private var selectedYear: Int {
        calendar.component(.year, from: selectedDate)
    }

    private var selectableYears: [Int] {
        let currentYear = calendar.component(.year, from: Date())
        return Array((currentYear - 5)...(currentYear + 5))
    }

    private var selectedMonthTitle: String {
        selectedDate.formatted(.dateTime.month(.wide).year())
    }

    private var monthlyTotalExpense: Double {
        dailySummaries.reduce(0) { $0 + $1.totalExpense }
    }

    private var layoutRefreshID: String {
        "\(horizontalSizeClass == .compact)-\(verticalSizeClass == .compact)"
    }

    @ViewBuilder
    private var chartSection: some View {
        if dailySummaries.isEmpty {
            ContentUnavailableView(
                "No Expenses",
                systemImage: "chart.bar.xaxis",
                description: Text("The monthly expense chart will appear here once expenses are available for the selected month.")
            )
        } else {
            Chart(dailySummaries) { summary in
                BarMark(
                    x: .value("Day", dayLabel(for: summary.date)),
                    y: .value("Expense", summary.totalExpense)
                )
                .foregroundStyle(.blue.gradient)
            }
            .chartXAxis {
                AxisMarks(values: dailySummaries.map { dayLabel(for: $0.date) }) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .chartXAxisLabel("Day")
            .chartYAxisLabel("Expense")
            .frame(height: 260)
            .padding(.horizontal, 20)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Month")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Picker("Month", selection: Binding(
                        get: { selectedMonth },
                        set: { updateSelectedDate(month: $0, year: selectedYear) }
                    )) {
                        ForEach(Array(monthSymbols.enumerated()), id: \.offset) { index, symbol in
                            Text(symbol).tag(index + 1)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Year", selection: Binding(
                        get: { selectedYear },
                        set: { updateSelectedDate(month: selectedMonth, year: $0) }
                    )) {
                        ForEach(selectableYears, id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                HStack(alignment: .firstTextBaseline) {
                    Text(selectedMonthTitle)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Spacer()

                    Text(monthlyTotalExpense, format: .currency(code: "AUD"))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                }
                .padding(.horizontal, 20)

                chartSection
            }
        }
        .id(layoutRefreshID)
        .navigationTitle("Report")
        .task {
            refreshDailySummaries()
        }
        .onChange(of: selectedDate) { _, _ in
            refreshDailySummaries()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    triggerBackup()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share Backup")
            }
        }
        .sheet(item: $sharedBackupFile) { sharedBackupFile in
            ShareSheetView(items: [sharedBackupFile.url])
        }
        .alert("Backup", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                alertMessage = nil
            }
        } message: {
            Text(alertMessage ?? "")
        }
        .safeAreaInset(edge: .bottom) {
            AdMobBannerContainer()
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .background(.thinMaterial)
        }
    }

    private func triggerBackup() {
        Task {
            await backupExpenses()
        }
    }

    private func refreshDailySummaries() {
        dailySummaries = ExpenseStore.loadDailyExpenseSummaries(forMonthContaining: selectedDate)
    }

    private func dayLabel(for date: Date) -> String {
        date.formatted(.dateTime.day())
    }

    private func updateSelectedDate(month: Int, year: Int) {
        let currentDay = calendar.component(.day, from: selectedDate)
        let dateComponents = DateComponents(year: year, month: month)
        guard let monthDate = calendar.date(from: dateComponents),
              let dayRange = calendar.range(of: .day, in: .month, for: monthDate) else {
            return
        }

        let validDay = min(currentDay, dayRange.count)
        selectedDate = calendar.date(from: DateComponents(year: year, month: month, day: validDay)) ?? monthDate
    }

    @MainActor
    private func backupExpenses() async {
        do {
            let backupFileURL = try await Task.detached(priority: .userInitiated) {
                try ExpenseBackupExporter.exportExcelFile()
            }.value
            sharedBackupFile = SharedBackupFile(url: backupFileURL)
        } catch {
            alertMessage = "Failed to create the backup file."
        }
    }
}

private struct AdMobBannerContainer: View {
    var body: some View {
#if canImport(GoogleMobileAds)
        ReportBannerAdView()
            .frame(height: 50)
#else
        EmptyView()
#endif
    }
}

#if canImport(GoogleMobileAds)
private struct ReportBannerAdView: UIViewRepresentable {
//    private let adUnitID = "ca-app-pub-3940256099942544/2435281174"
    private let adUnitID = "ca-app-pub-7774404592897854/5421695753"

    func makeUIView(context: Context) -> BannerView {
        let bannerView = BannerView(adSize: AdSizeBanner)
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = UIApplication.shared.topViewController
        bannerView.load(Request())
        return bannerView
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        uiView.rootViewController = UIApplication.shared.topViewController
    }
}

private extension UIApplication {
    var topViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController?
            .topMostViewController()
    }
}

private extension UIViewController {
    func topMostViewController() -> UIViewController {
        if let presentedViewController {
            return presentedViewController.topMostViewController()
        }

        if let navigationController = self as? UINavigationController,
           let visibleViewController = navigationController.visibleViewController {
            return visibleViewController.topMostViewController()
        }

        if let tabBarController = self as? UITabBarController,
           let selectedViewController = tabBarController.selectedViewController {
            return selectedViewController.topMostViewController()
        }

        return self
    }
}
#endif

#Preview {
    ReportView()
}
