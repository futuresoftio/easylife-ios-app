//
//  DetailView.swift
//  TestApp
//
//  Created by Wei Lin on 20/9/2025.
//

import SwiftUI

struct DetailView: View {
    let expense: ExpenseItem
    let category: String
    let onDelete: () -> Void
    let onUpdate: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isShowingEditSheet = false
    @State private var selectedCategory: String
    @State private var expenseTitle: String
    @State private var expensePrice: String
    @State private var alertMessage: String?

    private var availableCategories: [String] {
        let names = ExpenseStore.loadCategories().map(\.name)
        return names.isEmpty ? [category] : names
    }

    init(expense: ExpenseItem, category: String, onDelete: @escaping () -> Void, onUpdate: @escaping () -> Void) {
        self.expense = expense
        self.category = category
        self.onDelete = onDelete
        self.onUpdate = onUpdate
        _selectedCategory = State(initialValue: category)
        _expenseTitle = State(initialValue: expense.title)
        _expensePrice = State(initialValue: String(format: "%.2f", expense.amount))
    }

    var body: some View {
        VStack {
            Text("Detail Screen")
                .font(.largeTitle)
            Text("You selected: \(expense.title)")
                .font(.title2)
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("Edit Expense")
            }
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
        .sheet(isPresented: $isShowingEditSheet) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(availableCategories, id: \.self) { categoryName in
                            Text(categoryName).tag(categoryName)
                        }
                    }
                    .pickerStyle(.menu)

                    TextField("Expense item name", text: $expenseTitle)
                        .textFieldStyle(.roundedBorder)

                    TextField("Expense item price", text: $expensePrice)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)

                    Spacer()

                    HStack {
                        Button("Cancel", role: .cancel) {
                            isShowingEditSheet = false
                        }
                        .buttonStyle(.bordered)

                        Button("Save") {
                            saveExpenseChanges()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(20)
                .navigationTitle("Edit Expense")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])
        }
        .alert("Edit Expense", isPresented: Binding(
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

    private func saveExpenseChanges() {
        let trimmedTitle = expenseTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else {
            alertMessage = "Expense item name cannot be empty."
            return
        }

        guard let amount = Double(expensePrice), amount >= 0 else {
            alertMessage = "Expense item price must be a valid number."
            return
        }

        do {
            try ExpenseStore.updateExpense(
                id: expense.id,
                title: trimmedTitle,
                amount: amount,
                category: selectedCategory
            )
            onUpdate()
            isShowingEditSheet = false
            dismiss()
        } catch {
            alertMessage = "Failed to update the expense."
        }
    }
}
