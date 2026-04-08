//
//  LicensesView.swift
//  TestApp
//

import SwiftUI

struct LicensesView: View {
    var body: some View {
        List {
            Section("Dependencies") {
                ForEach(LicenseCatalog.dependencies) { dependency in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dependency.name)
                            .font(.headline)
                        Text(dependency.licenseName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(dependency.usageNote)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }

            Section("License Texts") {
                ForEach(LicenseCatalog.licenseDocuments) { document in
                    NavigationLink {
                        LicenseDocumentView(document: document)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(document.title)
                            Text(document.packageNames.joined(separator: ", "))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("App Store Notes") {
                ForEach(LicenseCatalog.appStoreNotes, id: \.self) { note in
                    Text(note)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("Licenses")
    }
}

private struct LicenseDocumentView: View {
    let document: LicenseDocument

    var body: some View {
        ScrollView {
            Text(document.body)
                .font(.system(.footnote, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        LicensesView()
    }
}
