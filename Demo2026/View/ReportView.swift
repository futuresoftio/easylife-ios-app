//
//  ReportView.swift
//  TestApp
//
//  Created by Wei Lin on 20/9/2025.
//

import SwiftUI
import Charts

struct ReportView: View {
    private struct SharedBackupFile: Identifiable {
        let id = UUID()
        let url: URL
    }

    @State private var categorySummaries: [CategoryExpenseSummary] = []
    @State private var selectedDate = Date()
    @State private var selectedChartCategory: String?
    @State private var selectedBreakdown: CategoryExpenseBreakdown?
    @State private var sharedBackupFile: SharedBackupFile?
    @State private var alertMessage: String?

    @ViewBuilder
    private var chartSection: some View {
        if categorySummaries.isEmpty {
            ContentUnavailableView(
                "No Expenses",
                systemImage: "chart.bar.xaxis",
                description: Text("The expense chart will appear here once expenses are available for the selected date.")
            )
        } else {
            Chart(categorySummaries) { summary in
                BarMark(
                    x: .value("Category", summary.category),
                    y: .value("Expense", summary.totalExpense)
                )
                .foregroundStyle(barStyle(for: summary))
            }
            .chartXSelection(value: $selectedChartCategory)
            .chartXAxisLabel("Category")
            .chartYAxisLabel("Expense")
            .frame(height: 260)
            .padding(.horizontal, 20)
        }
    }

    private func barStyle(for summary: CategoryExpenseSummary) -> AnyShapeStyle {
        let isSelected = selectedChartCategory == nil || selectedChartCategory == summary.category
        return isSelected ? AnyShapeStyle(.blue.gradient) : AnyShapeStyle(.blue.opacity(0.35))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DatePicker(
                    "Date",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal, 20)
                .padding(.top, 20)

                chartSection
            }
        }
        .navigationTitle("Report")
        .task {
            refreshCategorySummaries()
        }
        .onChange(of: selectedDate) { _, _ in
            refreshCategorySummaries()
        }
        .onChange(of: selectedChartCategory) { _, newValue in
            guard let newValue else {
                return
            }

            selectedBreakdown = ExpenseStore.loadExpenseBreakdown(for: newValue, date: selectedDate)
            selectedChartCategory = nil
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
        .sheet(item: $selectedBreakdown) { breakdown in
            breakdownSheet(for: breakdown)
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
    }

    private func triggerBackup() {
        Task {
            await backupExpenses()
        }
    }

    private func refreshCategorySummaries() {
        categorySummaries = ExpenseStore.loadCategorySummaries(for: selectedDate)
    }

    private func breakdownSheet(for breakdown: CategoryExpenseBreakdown) -> some View {
        NavigationStack {
            List(breakdown.expenses) { expense in
                HStack {
                    Text(expense.title)
                    Spacer()
                    Text(expense.amount, format: .currency(code: "AUD"))
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(breakdown.category)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        selectedBreakdown = nil
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
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

#Preview {
    ReportView()
}
