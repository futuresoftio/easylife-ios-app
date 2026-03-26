//
//  ReportView.swift
//  TestApp
//
//  Created by Wei Lin on 20/9/2025.
//

import SwiftUI

struct ReportView: View {
    private struct SharedBackupFile: Identifiable {
        let id = UUID()
        let url: URL
    }

    @State private var sharedBackupFile: SharedBackupFile?
    @State private var alertMessage: String?

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text(versionText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
        .navigationTitle("Report")
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
    }

    private func triggerBackup() {
        Task {
            await backupExpenses()
        }
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
