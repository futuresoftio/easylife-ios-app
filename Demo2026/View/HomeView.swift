//
//  HomeView.swift
//  TestApp
//
//  Created by Wei Lin on 20/9/2025.
//

import SwiftUI
import UIKit
import VisionKit

struct HomeView: View {
    private struct CalendarDay: Identifiable {
        let date: Date
        let isCurrentMonth: Bool

        var id: Date { date }
    }

    @State private var categories: [ExpenseCategory] = []
    @State private var categoryNames: [String] = []
    @State private var expenseFormCategoryNames: [String] = []
    @State private var isShowingAddOptions = false
    @State private var isShowingAddCategorySheet = false
    @State private var isShowingAddExpenseSheet = false
    @State private var isShowingDateFilterSheet = false
    @State private var isShowingScanner = false
    @State private var isProcessingReceipt = false
    @State private var alertMessage: String?
    @State private var newCategoryName = ""
    @State private var selectedExpenseCategory = ""
    @State private var newExpenseTitle = ""
    @State private var newExpenseAmount = ""
    @State private var newExpenseDate = Date()
    @State private var selectedFilterDate = Date()
    @State private var pendingFilterDate = Date()
    @State private var calendarMonth = Calendar.current.startOfMonth(for: Date())
    @State private var expenseDates = Set<Date>()

    private var todayExpense: Double {
        categories
            .flatMap(\.expenses)
            .reduce(0) { $0 + $1.amount }
    }

    private var expenseHeaderTitle: String {
        if Calendar.current.isDateInToday(selectedFilterDate) {
            return "Today's Expense"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "Expense on \(formatter.string(from: selectedFilterDate))"
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: calendarMonth)
    }

    private var calendarDays: [CalendarDay] {
        let calendar = Calendar.current
        let monthStart = calendar.startOfMonth(for: calendarMonth)
        guard let monthRange = calendar.range(of: .day, in: .month, for: monthStart),
              let firstWeekday = calendar.dateComponents([.weekday], from: monthStart).weekday else {
            return []
        }

        let leadingDays = (firstWeekday - calendar.firstWeekday + 7) % 7
        var days: [CalendarDay] = []

        for offset in stride(from: leadingDays, to: 0, by: -1) {
            if let date = calendar.date(byAdding: .day, value: -offset, to: monthStart) {
                days.append(CalendarDay(date: date, isCurrentMonth: false))
            }
        }

        for day in monthRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                days.append(CalendarDay(date: date, isCurrentMonth: true))
            }
        }

        while days.count % 7 != 0 {
            if let lastDate = days.last?.date,
               let nextDate = calendar.date(byAdding: .day, value: 1, to: lastDate) {
                days.append(CalendarDay(date: nextDate, isCurrentMonth: false))
            } else {
                break
            }
        }

        return days
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16, pinnedViews: [.sectionHeaders]) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(expenseHeaderTitle)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                pendingFilterDate = selectedFilterDate
                                calendarMonth = Calendar.current.startOfMonth(for: selectedFilterDate)
                                expenseDates = ExpenseStore.expenseDatesWithItems()
                                isShowingDateFilterSheet = true
                            } label: {
                                Image(systemName: "calendar")
                                    .font(.headline)
                            }
                            .accessibilityLabel("Filter Date")
                        }
                        Text(todayExpense, format: .currency(code: "AUD"))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.blue.opacity(0.12))
                    )

                    if categories.isEmpty {
                        ContentUnavailableView(
                            "No Expenses",
                            systemImage: "receipt",
                            description: Text("The expense will appear here once\n expenses are available for Tody.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                    } else {
                        ForEach(categories) { category in
                            Section {
                                VStack(spacing: 12) {
                                    ForEach(category.expenses) { expense in
                                        NavigationLink(
                                            destination: DetailView(
                                                expense: expense,
                                                category: category.name,
                                                onDelete: {
                                                    deleteExpense(expense, from: category)
                                                },
                                                onUpdate: {
                                                    refreshCategories()
                                                }
                                            )
                                        ) {
                                            HStack {
                                                Text(expense.title)
                                                    .foregroundStyle(.primary)
                                                Spacer()
                                                Text(expense.amount, format: .currency(code: "AUD"))
                                                    .foregroundStyle(.secondary)
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 14)
                                            .background(
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .fill(Color(.secondarySystemBackground))
                                            )
                                        }
                                    }
                                }
                            } header: {
                                Text(category.name)
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemBackground).opacity(0.95))
                            }
                        }
                    }
                }
                .padding()
            }
            .task {
                refreshCategories()
            }
            .navigationTitle("Easy Life")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        LicensesView()
                    } label: {
                        Image(systemName: "doc.text")
                    }
                    .accessibilityLabel("Open Licenses")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingAddOptions = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            isShowingScanner = true
                        } else {
                            alertMessage = "Receipt scanning is not supported on this device."
                        }
                    } label: {
                        Image(systemName: "qrcode.viewfinder")
                    }
                    .accessibilityLabel("Scan")
                }
            }
            .sheet(isPresented: $isShowingScanner) {
                ReceiptScannerView(
                    onScan: { images in
                        isShowingScanner = false
                        Task {
                            await handleScannedReceipt(images)
                        }
                    },
                    onCancel: {
                        isShowingScanner = false
                    },
                    onError: { error in
                        isShowingScanner = false
                        alertMessage = error.localizedDescription
                    }
                )
            }
            .sheet(isPresented: $isShowingAddOptions) {
                VStack(spacing: 16) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.35))
                        .frame(width: 44, height: 5)
                        .padding(.top, 12)

                    Text("Add")
                        .font(.headline)

                    Button("Add new category") {
                        isShowingAddOptions = false
                        newCategoryName = ""
                        isShowingAddCategorySheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)

                    Button("Add new expense") {
                        isShowingAddOptions = false
                        handleAddExpenseSelection()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                    Text("Tip: Scan a receipt to auto-fill the category.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)

                    Button("Cancel", role: .cancel) {
                        isShowingAddOptions = false
                    }
                    .padding(.top, 8)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .presentationDetents([.height(240)])
            }
            .sheet(isPresented: $isShowingAddCategorySheet) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 16) {
                        TextField("Category name", text: $newCategoryName)
                            .textFieldStyle(.roundedBorder)

                        Spacer()

                        HStack {
                            Button("Cancel", role: .cancel) {
                                isShowingAddCategorySheet = false
                            }
                            .buttonStyle(.bordered)

                            Button("Save") {
                                addCategory()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(20)
                    .navigationTitle("Add Category")
                    .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.height(220)])
            }
            .sheet(isPresented: $isShowingAddExpenseSheet) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 16) {
                        Picker("Category", selection: $selectedExpenseCategory) {
                            ForEach(expenseFormCategoryNames, id: \.self) { categoryName in
                                Text(categoryName).tag(categoryName)
                            }
                        }
                        .pickerStyle(.menu)

                        TextField("Expense title", text: $newExpenseTitle)
                            .textFieldStyle(.roundedBorder)

                        TextField("Expense amount", text: $newExpenseAmount)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)

                        DatePicker(
                            "Date",
                            selection: $newExpenseDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)

                        Spacer()

                        HStack {
                            Button("Cancel", role: .cancel) {
                                isShowingAddExpenseSheet = false
                            }
                            .buttonStyle(.bordered)

                            Button("Save") {
                                addExpense()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(20)
                    .navigationTitle("Add Expense")
                    .navigationBarTitleDisplayMode(.inline)
                    .task {
                        loadExpenseFormCategories()
                    }
                }
                .presentationDetents([.height(320)])
            }
            .sheet(isPresented: $isShowingDateFilterSheet) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Button {
                                if let previousMonth = Calendar.current.date(byAdding: .month, value: -1, to: calendarMonth) {
                                    calendarMonth = Calendar.current.startOfMonth(for: previousMonth)
                                }
                            } label: {
                                Image(systemName: "chevron.left")
                            }

                            Spacer()

                            Text(monthTitle)
                                .font(.headline)

                            Spacer()

                            Button {
                                if let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: calendarMonth) {
                                    calendarMonth = Calendar.current.startOfMonth(for: nextMonth)
                                }
                            } label: {
                                Image(systemName: "chevron.right")
                            }
                        }

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                            ForEach(Calendar.current.veryShortWeekdaySymbols, id: \.self) { symbol in
                                Text(symbol)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                            }

                            ForEach(calendarDays) { day in
                                Button {
                                    pendingFilterDate = day.date
                                } label: {
                                    Text(day.date, format: .dateTime.day())
                                        .font(.body)
                                        .fontWeight(Calendar.current.isDate(day.date, inSameDayAs: pendingFilterDate) ? .bold : .regular)
                                        .foregroundStyle(dayTextColor(for: day))
                                        .frame(maxWidth: .infinity, minHeight: 32)
                                        .background(dayBackground(for: day))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Spacer(minLength: 0)

                        HStack(spacing: 12) {
                            Button(role: .cancel) {
                                isShowingDateFilterSheet = false
                            } label: {
                                Text("Cancel")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                let hasChanged = !Calendar.current.isDate(pendingFilterDate, inSameDayAs: selectedFilterDate)
                                isShowingDateFilterSheet = false

                                guard hasChanged else {
                                    return
                                }

                                selectedFilterDate = pendingFilterDate
                                refreshCategories()
                            } label: {
                                Text("Ok")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    }
                    .padding(20)
                    .navigationTitle("Select Date")
                    .navigationBarTitleDisplayMode(.inline)
                    .onAppear {
                        expenseDates = ExpenseStore.expenseDatesWithItems()
                        calendarMonth = Calendar.current.startOfMonth(for: pendingFilterDate)
                    }
                }
                .presentationDetents([.height(520)])
            }
            .overlay {
                if isProcessingReceipt {
                    ZStack {
                        Color.black.opacity(0.15)
                            .ignoresSafeArea()
                        ProgressView("Analyzing receipt...")
                            .padding(20)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
            .alert("Scan Receipt", isPresented: Binding(
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
    }

    @MainActor
    private func handleScannedReceipt(_ images: [UIImage]) async {
        isProcessingReceipt = true
        defer { isProcessingReceipt = false }

        do {
            let receiptExpenses = try await ReceiptAnalyzer.analyze(images: images)

            guard !receiptExpenses.isEmpty else {
                alertMessage = "No expenses were detected from the scanned receipt."
                return
            }

            try ExpenseStore.addReceiptExpenses(receiptExpenses)
            let parsedReceiptDate = Calendar.current.startOfDay(for: receiptExpenses[0].item.createdAt)
            selectedFilterDate = parsedReceiptDate
            pendingFilterDate = parsedReceiptDate
            calendarMonth = Calendar.current.startOfMonth(for: parsedReceiptDate)
            refreshCategories()
        } catch {
            alertMessage = "Failed to analyze the scanned receipt."
        }
    }

    private func deleteExpense(_ expense: ExpenseItem, from _: ExpenseCategory) {
        do {
            try ExpenseStore.deleteExpense(id: expense.id)
            refreshCategories()
        } catch {
            alertMessage = "Failed to delete the expense."
        }
    }

    private func refreshCategories() {
        expenseDates = ExpenseStore.expenseDatesWithItems()
        categoryNames = ExpenseStore.loadCategoryNames()
        categories = ExpenseStore.loadCategories(for: selectedFilterDate)
    }

    private func handleAddExpenseSelection() {
        let availableCategories = ExpenseStore.loadCategoryNames()
        guard !availableCategories.isEmpty else {
            alertMessage = "Please add a category first, or scan a receipt and let the app parse a category for you."
            return
        }

        prepareAddExpenseForm()
        isShowingAddExpenseSheet = true
    }

    private func addCategory() {
        let trimmedName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            alertMessage = "Category name cannot be empty."
            return
        }

        do {
            try ExpenseStore.addCategory(named: trimmedName)
            isShowingAddCategorySheet = false
            refreshCategories()
        } catch {
            alertMessage = "Failed to add the category."
        }
    }

    private func prepareAddExpenseForm() {
        expenseFormCategoryNames = []
        selectedExpenseCategory = ""
        newExpenseTitle = ""
        newExpenseAmount = ""
        newExpenseDate = selectedFilterDate
    }

    private func addExpense() {
        let trimmedTitle = newExpenseTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !selectedExpenseCategory.isEmpty else {
            alertMessage = "Please select a category."
            return
        }

        guard !trimmedTitle.isEmpty else {
            alertMessage = "Expense title cannot be empty."
            return
        }

        guard let amount = Double(newExpenseAmount), amount >= 0 else {
            alertMessage = "Expense amount must be a valid number."
            return
        }

        do {
            try ExpenseStore.addExpense(
                title: trimmedTitle,
                amount: amount,
                category: selectedExpenseCategory,
                createdAt: newExpenseDate
            )
            isShowingAddExpenseSheet = false
            selectedFilterDate = newExpenseDate
            refreshCategories()
        } catch {
            alertMessage = "Failed to add the expense."
        }
    }

    private func loadExpenseFormCategories() {
        let allCategoryNames = ExpenseStore.loadCategoryNames()
        expenseFormCategoryNames = allCategoryNames

        if selectedExpenseCategory.isEmpty {
            selectedExpenseCategory = allCategoryNames.first ?? ""
        }

        if allCategoryNames.isEmpty {
            isShowingAddExpenseSheet = false
            alertMessage = "Please add a category before adding an expense."
        }
    }

    private func dayTextColor(for day: CalendarDay) -> Color {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: day.date)
        let hasExpense = expenseDates.contains(normalizedDate)

        if calendar.isDate(day.date, inSameDayAs: pendingFilterDate) {
            return hasExpense ? .blue : .primary
        }

        if hasExpense {
            return .blue
        }

        return day.isCurrentMonth ? .primary : .secondary
    }

    @ViewBuilder
    private func dayBackground(for day: CalendarDay) -> some View {
        let calendar = Calendar.current

        ZStack {
            if calendar.isDateInToday(day.date) {
                Circle()
                    .stroke(Color.blue, lineWidth: 1.5)
                    .frame(width: 32, height: 32)
            }

            if calendar.isDate(day.date, inSameDayAs: pendingFilterDate) {
                Circle()
                    .fill(Color.blue.opacity(0.18))
                    .frame(width: 32, height: 32)
            }
        }
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}

#Preview {
    HomeView()
}
