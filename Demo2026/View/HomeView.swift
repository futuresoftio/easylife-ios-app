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
    @State private var categories: [ExpenseCategory] = []
    @State private var isShowingAddOptions = false
    @State private var isShowingScanner = false
    @State private var isProcessingReceipt = false
    @State private var alertMessage: String?

    private var todayExpense: Double {
        categories
            .flatMap(\.expenses)
            .reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16, pinnedViews: [.sectionHeaders]) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Today's Expense")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text(todayExpense, format: .currency(code: "AUD"))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.blue.opacity(0.12))
                    )

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
                .padding()
            }
            .task {
                refreshCategories()
            }
            .navigationTitle("Easy Life")
            .toolbar {
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
                        if VNDocumentCameraViewController.isSupported {
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
                        alertMessage = "Add new category is not implemented yet."
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)

                    Button("Add new expense") {
                        isShowingAddOptions = false
                        alertMessage = "Add new expense is not implemented yet."
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                    Button("Cancel", role: .cancel) {
                        isShowingAddOptions = false
                    }
                    .padding(.top, 8)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .presentationDetents([.height(240)])
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
        categories = ExpenseStore.loadCategories(for: Date())
    }
}

#Preview {
    HomeView()
}
