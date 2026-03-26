//
//  ExpenseModel.swift
//  TestApp
//
//  Created by Wei Lin on 20/9/2025.
//

import Foundation
import CoreData
import UIKit
import Vision

struct ExpenseCategory: Identifiable, Codable {
    let name: String
    let expenses: [ExpenseItem]

    var id: String { name }
}

struct ExpenseItem: Identifiable, Codable {
    let id: UUID
    let title: String
    let amount: Double
    let createdAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case amount
        case createdAt
    }

    init(id: UUID = UUID(), title: String, amount: Double, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.amount = amount
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        amount = try container.decode(Double.self, forKey: .amount)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

struct ReceiptExpense {
    let category: String
    let item: ExpenseItem
}

struct CategoryExpenseSummary: Identifiable {
    let category: String
    let totalExpense: Double

    var id: String { category }
}

struct CategoryExpenseBreakdown: Identifiable {
    let category: String
    let expenses: [ExpenseItem]

    var id: String { category }
}

private struct ReceiptContext {
    let title: String
    let category: String
}

enum ExpenseStore {
    private static let legacySavedExpensesKey = "saved_expense_categories_json"
    private static let persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "ExpenseDataModel")
        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Failed to load persistent stores: \(error.localizedDescription)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return container
    }()
    private static let viewContext = persistentContainer.viewContext

    static func loadCategories() -> [ExpenseCategory] {
        seedInitialDataIfNeeded()
        return categories(from: fetchStoredExpenses())
    }

    static func loadCategories(for date: Date) -> [ExpenseCategory] {
        seedInitialDataIfNeeded()
        return categories(from: expenses(for: date))
    }

    static func preloadInitialData() {
        seedInitialDataIfNeeded()
    }

    static func addReceiptExpenses(_ receiptExpenses: [ReceiptExpense]) throws {
        seedInitialDataIfNeeded()

        for receiptExpense in receiptExpenses {
            insertExpense(
                title: receiptExpense.item.title,
                amount: receiptExpense.item.amount,
                category: receiptExpense.category
            )
        }

        try saveContext()
    }

    static func deleteExpense(id: UUID) throws {
        let request = storedExpenseFetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        if let expense = try viewContext.fetch(request).first {
            viewContext.delete(expense)
            try saveContext()
        }
    }

    static func updateExpense(
        id: UUID,
        title: String,
        amount: Double,
        category: String,
        createdAt: Date
    ) throws {
        let request = storedExpenseFetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        guard let expense = try viewContext.fetch(request).first else {
            return
        }

        expense.setValue(title, forKey: "title")
        expense.setValue(amount, forKey: "amount")
        expense.setValue(categoryObject(named: category), forKey: "category")
        expense.setValue(createdAt, forKey: "createdAt")
        try saveContext()
    }

    static func loadCategorySummaries(for date: Date) -> [CategoryExpenseSummary] {
        seedInitialDataIfNeeded()

        let filteredExpenses = expenses(for: date)

        let groupedTotals = Dictionary(grouping: filteredExpenses, by: { expenseCategory(for: $0) })
            .map { category, expenses in
                CategoryExpenseSummary(
                    category: category,
                    totalExpense: expenses.reduce(0) { partialResult, expense in
                        partialResult + (expense.value(forKey: "amount") as? Double ?? 0)
                    }
                )
            }

        return groupedTotals.sorted { $0.category < $1.category }
    }

    static func loadExpenseBreakdown(for category: String, date: Date) -> CategoryExpenseBreakdown? {
        seedInitialDataIfNeeded()

        let expenses = expenses(for: date)
            .filter { expense in
                expenseCategory(for: expense) == category
            }
            .compactMap(expenseItem(from:))

        guard !expenses.isEmpty else {
            return nil
        }

        return CategoryExpenseBreakdown(category: category, expenses: expenses)
    }

    static func categories(from expenses: [NSManagedObject]) -> [ExpenseCategory] {
        let groupedExpenses = Dictionary(grouping: expenses, by: { expenseCategory(for: $0) })
        let categoryOrder = expenses.map { expenseCategory(for: $0) }.reduce(into: [String]()) { partialResult, category in
            if !partialResult.contains(category) {
                partialResult.append(category)
            }
        }

        return categoryOrder.compactMap { categoryName in
            guard let storedExpenses = groupedExpenses[categoryName] else {
                return nil
            }

            return ExpenseCategory(
                name: categoryName,
                expenses: storedExpenses.compactMap(expenseItem(from:))
            )
        }
    }

    private static func fetchStoredExpenses() -> [NSManagedObject] {
        let request = storedExpenseFetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: true)
        ]

        return (try? viewContext.fetch(request)) ?? []
    }

    private static func expenses(for date: Date) -> [NSManagedObject] {
        let calendar = Calendar.current
        return fetchStoredExpenses().filter { expense in
            guard let createdAt = expense.value(forKey: "createdAt") as? Date else {
                return false
            }

            return calendar.isDate(createdAt, inSameDayAs: date)
        }
    }

    private static func seedInitialDataIfNeeded() {
        let request = storedExpenseFetchRequest()
        request.fetchLimit = 1

        let count = (try? viewContext.count(for: request)) ?? 0
        guard count == 0 else {
            return
        }

        let categoriesToSeed = loadLegacySavedCategories().flatMap { categories in
            categories.isEmpty ? nil : categories
        } ?? loadBundledCategories()
        let now = Date()

        for (categoryIndex, category) in categoriesToSeed.enumerated() {
            for (expenseIndex, expense) in category.expenses.enumerated() {
                insertExpense(
                    id: expense.id,
                    title: expense.title,
                    amount: expense.amount,
                    category: category.name,
                    createdAt: now.addingTimeInterval(Double(categoryIndex * 100 + expenseIndex))
                )
            }
        }

        try? saveContext()
        UserDefaults.standard.removeObject(forKey: legacySavedExpensesKey)
    }

    private static func insertExpense(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        category: String,
        createdAt: Date = Date()
    ) {
        guard let entity = NSEntityDescription.entity(forEntityName: "StoredExpense", in: viewContext) else {
            return
        }

        let storedExpense = NSManagedObject(entity: entity, insertInto: viewContext)
        storedExpense.setValue(id, forKey: "id")
        storedExpense.setValue(title, forKey: "title")
        storedExpense.setValue(amount, forKey: "amount")
        storedExpense.setValue(categoryObject(named: category), forKey: "category")
        storedExpense.setValue(createdAt, forKey: "createdAt")
    }

    private static func saveContext() throws {
        guard viewContext.hasChanges else {
            return
        }

        do {
            try viewContext.save()
        } catch {
            viewContext.rollback()
            throw error
        }
    }

    private static func loadBundledCategories() -> [ExpenseCategory] {
        guard let url = Bundle.main.url(forResource: "Expense", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let categories = try? JSONDecoder().decode([ExpenseCategory].self, from: data) else {
            return []
        }

        return categories
    }

    private static func loadLegacySavedCategories() -> [ExpenseCategory]? {
        guard let data = UserDefaults.standard.data(forKey: legacySavedExpensesKey),
              let categories = try? JSONDecoder().decode([ExpenseCategory].self, from: data) else {
            return nil
        }

        return categories
    }

    private static func storedExpenseFetchRequest() -> NSFetchRequest<NSManagedObject> {
        NSFetchRequest<NSManagedObject>(entityName: "StoredExpense")
    }

    private static func expenseCategory(for expense: NSManagedObject) -> String {
        let category = expense.value(forKey: "category") as? NSManagedObject
        return category?.value(forKey: "name") as? String ?? "Other"
    }

    private static func expenseItem(from expense: NSManagedObject) -> ExpenseItem? {
        guard let id = expense.value(forKey: "id") as? UUID,
              let title = expense.value(forKey: "title") as? String else {
            return nil
        }

        let amount = expense.value(forKey: "amount") as? Double ?? 0
        let createdAt = expense.value(forKey: "createdAt") as? Date ?? Date()
        return ExpenseItem(id: id, title: title, amount: amount, createdAt: createdAt)
    }

    private static func categoryObject(named name: String) -> NSManagedObject? {
        let request = categoryFetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "name == %@", name)

        if let existingCategory = try? viewContext.fetch(request).first {
            return existingCategory
        }

        guard let entity = NSEntityDescription.entity(forEntityName: "Category", in: viewContext) else {
            return nil
        }

        let category = NSManagedObject(entity: entity, insertInto: viewContext)
        category.setValue(name, forKey: "name")
        return category
    }

    private static func categoryFetchRequest() -> NSFetchRequest<NSManagedObject> {
        NSFetchRequest<NSManagedObject>(entityName: "Category")
    }
}

enum ExpenseBackupExporter {
    static func exportExcelFile() throws -> URL {
        let categories = ExpenseStore.loadCategories()
        let fileName = "Expenses-\(timestamp()).xlsx"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        let archive = xlsxArchive(from: categories)

        try archive.write(to: fileURL)
        return fileURL
    }

    private static func xlsxArchive(from categories: [ExpenseCategory]) -> ZIPArchive {
        ZIPArchive(files: [
            ZIPFile(path: "[Content_Types].xml", data: Data(contentTypesXML.utf8)),
            ZIPFile(path: "_rels/.rels", data: Data(rootRelationshipsXML.utf8)),
            ZIPFile(path: "xl/workbook.xml", data: Data(workbookXML.utf8)),
            ZIPFile(path: "xl/_rels/workbook.xml.rels", data: Data(workbookRelationshipsXML.utf8)),
            ZIPFile(path: "xl/styles.xml", data: Data(stylesXML.utf8)),
            ZIPFile(path: "xl/worksheets/sheet1.xml", data: Data(worksheetXML(from: categories).utf8))
        ])
    }

    private static let contentTypesXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
        <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
        <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
    </Types>
    """

    private static let rootRelationshipsXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
    </Relationships>
    """

    private static let workbookXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
     xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <sheets>
            <sheet name="Expenses" sheetId="1" r:id="rId1"/>
        </sheets>
    </workbook>
    """

    private static let workbookRelationshipsXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
        <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
    </Relationships>
    """

    private static let stylesXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        <fonts count="1">
            <font>
                <sz val="11"/>
                <name val="Aptos"/>
            </font>
        </fonts>
        <fills count="2">
            <fill><patternFill patternType="none"/></fill>
            <fill><patternFill patternType="gray125"/></fill>
        </fills>
        <borders count="1">
            <border><left/><right/><top/><bottom/><diagonal/></border>
        </borders>
        <cellStyleXfs count="1">
            <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
        </cellStyleXfs>
        <cellXfs count="1">
            <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
        </cellXfs>
        <cellStyles count="1">
            <cellStyle name="Normal" xfId="0" builtinId="0"/>
        </cellStyles>
    </styleSheet>
    """

    private static func worksheetXML(from categories: [ExpenseCategory]) -> String {
        var rows = [headerRow()]
        var rowIndex = 2

        for category in categories {
            for expense in category.expenses {
                rows.append(xmlRow(category: category.name, item: expense.title, amount: expense.amount, row: rowIndex))
                rowIndex += 1
            }
        }

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            <sheetData>
                \(rows.joined(separator: "\n"))
            </sheetData>
        </worksheet>
        """
    }

    private static func headerRow() -> String {
        """
        <row r="1">
            \(inlineStringCell(reference: "A1", value: "Category"))
            \(inlineStringCell(reference: "B1", value: "Item"))
            \(inlineStringCell(reference: "C1", value: "Amount"))
        </row>
        """
    }

    private static func xmlRow(category: String, item: String, amount: Double, row: Int) -> String {
        """
        <row r="\(row)">
            \(inlineStringCell(reference: "A\(row)", value: category))
            \(inlineStringCell(reference: "B\(row)", value: item))
            <c r="C\(row)"><v>\(String(format: "%.2f", amount))</v></c>
        </row>
        """
    }

    private static func inlineStringCell(reference: String, value: String) -> String {
        #"<c r="\#(reference)" t="inlineStr"><is><t>\#(escaped(value))</t></is></c>"#
    }

    private static func escaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    private struct ZIPFile {
        let path: String
        let data: Data
    }

    private struct ZIPArchive {
        let files: [ZIPFile]

        func write(to url: URL) throws {
            try buildData().write(to: url, options: .atomic)
        }

        private func buildData() -> Data {
            var archive = Data()
            var centralDirectory = Data()
            var offset: UInt32 = 0

            for file in files {
                let fileName = Data(file.path.utf8)
                let crc = CRC32.checksum(of: file.data)
                let uncompressedSize = UInt32(file.data.count)

                archive.appendUInt32(0x04034B50)
                archive.appendUInt16(20)
                archive.appendUInt16(0)
                archive.appendUInt16(0)
                archive.appendUInt16(0)
                archive.appendUInt16(0)
                archive.appendUInt32(crc)
                archive.appendUInt32(uncompressedSize)
                archive.appendUInt32(uncompressedSize)
                archive.appendUInt16(UInt16(fileName.count))
                archive.appendUInt16(0)
                archive.append(fileName)
                archive.append(file.data)

                centralDirectory.appendUInt32(0x02014B50)
                centralDirectory.appendUInt16(20)
                centralDirectory.appendUInt16(20)
                centralDirectory.appendUInt16(0)
                centralDirectory.appendUInt16(0)
                centralDirectory.appendUInt16(0)
                centralDirectory.appendUInt16(0)
                centralDirectory.appendUInt32(crc)
                centralDirectory.appendUInt32(uncompressedSize)
                centralDirectory.appendUInt32(uncompressedSize)
                centralDirectory.appendUInt16(UInt16(fileName.count))
                centralDirectory.appendUInt16(0)
                centralDirectory.appendUInt16(0)
                centralDirectory.appendUInt16(0)
                centralDirectory.appendUInt16(0)
                centralDirectory.appendUInt32(0)
                centralDirectory.appendUInt32(offset)
                centralDirectory.append(fileName)

                offset = UInt32(archive.count)
            }

            let centralDirectoryOffset = UInt32(archive.count)
            archive.append(centralDirectory)
            archive.appendUInt32(0x06054B50)
            archive.appendUInt16(0)
            archive.appendUInt16(0)
            archive.appendUInt16(UInt16(files.count))
            archive.appendUInt16(UInt16(files.count))
            archive.appendUInt32(UInt32(centralDirectory.count))
            archive.appendUInt32(centralDirectoryOffset)
            archive.appendUInt16(0)

            return archive
        }
    }

    private enum CRC32 {
        private static let table: [UInt32] = (0..<256).map { index in
            var value = UInt32(index)
            for _ in 0..<8 {
                if value & 1 == 1 {
                    value = 0xEDB88320 ^ (value >> 1)
                } else {
                    value >>= 1
                }
            }
            return value
        }

        static func checksum(of data: Data) -> UInt32 {
            var crc: UInt32 = 0xFFFF_FFFF
            for byte in data {
                let tableIndex = Int((crc ^ UInt32(byte)) & 0xFF)
                crc = table[tableIndex] ^ (crc >> 8)
            }
            return crc ^ 0xFFFF_FFFF
        }
    }
}

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { buffer in
            append(contentsOf: buffer)
        }
    }

    mutating func appendUInt32(_ value: UInt32) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { buffer in
            append(contentsOf: buffer)
        }
    }
}

enum ReceiptAnalyzer {
    static func analyze(images: [UIImage]) async throws -> [ReceiptExpense] {
        try await Task.detached(priority: .userInitiated) {
            let textLines = try images.flatMap(recognizedTextLines(from:))
            return parseExpenses(from: textLines)
        }.value
    }

    private static func recognizedTextLines(from image: UIImage) throws -> [String] {
        guard let cgImage = image.cgImage else {
            return []
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-AU", "en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])

        let observations = request.results ?? []
        return observations.compactMap { $0.topCandidates(1).first?.string }
    }

    private static func parseExpenses(from lines: [String]) -> [ReceiptExpense] {
        let skippedTerms = ["total", "subtotal", "tax", "gst", "change", "balance", "visa", "eftpos", "mastercard", "receipt", "invoice", "amount due"]
        var parsedExpenses: [ReceiptExpense] = []
        var fallbackExpense: ReceiptExpense?
        var previousDescriptiveLine: String?
        var lastRecognizedContext: ReceiptContext?

        for rawLine in lines {
            let line = rawLine
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !line.isEmpty else {
                continue
            }

            let lowercaseLine = line.lowercased()

            guard let amount = amount(in: line) else {
                if shouldStoreAsContextLine(line, skippedTerms: skippedTerms) {
                    previousDescriptiveLine = line

                    let recognizedCategory = category(for: line)
                    if recognizedCategory != "Other" {
                        lastRecognizedContext = ReceiptContext(title: line, category: recognizedCategory)
                    }
                }
                continue
            }

            let rawTitle = titleText(in: line)
            let title = resolvedTitle(
                from: rawTitle,
                previousLine: previousDescriptiveLine,
                recognizedContext: lastRecognizedContext
            )

            if skippedTerms.contains(where: lowercaseLine.contains) {
                if lowercaseLine.contains("total"), fallbackExpense == nil {
                    fallbackExpense = ReceiptExpense(
                        category: "Other",
                        item: ExpenseItem(title: "Scanned Receipt", amount: amount)
                    )
                }
                continue
            }

            guard !title.isEmpty else {
                continue
            }

            parsedExpenses.append(
                ReceiptExpense(
                    category: resolvedCategory(
                        for: title,
                        rawTitle: rawTitle,
                        recognizedContext: lastRecognizedContext
                    ),
                    item: ExpenseItem(title: title, amount: amount)
                )
            )
        }

        if parsedExpenses.isEmpty, let fallbackExpense {
            return [fallbackExpense]
        }

        return parsedExpenses
    }

    private static func amount(in line: String) -> Double? {
        let pattern = #"(?i)(?:sale\s+)?(?:aud\s*)?\$?\s*([0-9]+(?:[.,][0-9]{2}))\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: range),
              let amountRange = Range(match.range(at: 1), in: line) else {
            return nil
        }

        return Double(line[amountRange].replacingOccurrences(of: ",", with: "."))
    }

    private static func titleText(in line: String) -> String {
        let pattern = #"(?i)(?:sale\s+)?(?:aud\s*)?\$?\s*[0-9]+(?:[.,][0-9]{2})\s*$"#
        let title = line.replacingOccurrences(of: pattern, with: "", options: .regularExpression)

        return title.trimmingCharacters(in: CharacterSet(charactersIn: "-: ").union(.whitespacesAndNewlines))
    }

    private static func resolvedTitle(from rawTitle: String, previousLine: String?, recognizedContext: ReceiptContext?) -> String {
        let genericTitles = ["sale", "amount", "aud", "$"]
        let normalizedTitle = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        if !normalizedTitle.isEmpty, !genericTitles.contains(normalizedTitle.lowercased()) {
            return normalizedTitle
        }

        if let recognizedContext {
            return recognizedContext.title.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return previousLine?.trimmingCharacters(in: .whitespacesAndNewlines) ?? normalizedTitle
    }

    private static func resolvedCategory(for title: String, rawTitle: String, recognizedContext: ReceiptContext?) -> String {
        let genericTitles = ["sale", "amount", "aud", "$"]
        let normalizedRawTitle = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if genericTitles.contains(normalizedRawTitle), let recognizedContext {
            return recognizedContext.category
        }

        let inferredCategory = category(for: title)
        if inferredCategory != "Other" {
            return inferredCategory
        }

        return recognizedContext?.category ?? inferredCategory
    }

    private static func shouldStoreAsContextLine(_ line: String, skippedTerms: [String]) -> Bool {
        let lowercaseLine = line.lowercased()

        if skippedTerms.contains(where: lowercaseLine.contains) {
            return false
        }

        return amount(in: line) == nil
    }

    private static func category(for title: String) -> String {
        let lowercaseTitle = title.lowercased()

        let categoryKeywords: [(String, [String])] = [
            ("Food", ["coffee", "lunch", "dinner", "tea", "cafe", "restaurant", "snack", "breakfast"]),
            ("Transport", ["uber", "taxi", "train", "fare", "metro", "bus", "fuel", "parking", "toll"]),
            ("Groceries", ["grocery", "fruit", "vegetable", "veg", "milk", "bread", "supermarket", "market"]),
            ("Entertainment", ["movie", "cinema", "netflix", "game", "music", "ticket"]),
            ("Health", ["pharmacy", "medicine", "clinic", "dentist", "hospital", "vitamin"]),
            ("Shopping", ["shirt", "shoes", "clothes", "bag", "gift", "store", "retail"]),
            ("Bills", ["bill", "electricity", "water", "gas", "internet", "mobile", "recharge", "subscription"]),
            ("Education", ["book", "course", "tuition", "school", "class"]),
            ("Personal Care", ["haircut", "salon", "shampoo", "skincare", "soap"]),
            ("Home", ["dish", "laundry", "detergent", "cleaner", "furniture", "kitchen", "home"]),
            ("Car service", ["bob jane", "castle hill", "car service", "mechanic", "tyre", "tire", "wheel alignment", "brake"])
        ]

        for (category, keywords) in categoryKeywords where keywords.contains(where: lowercaseTitle.contains) {
            return category
        }

        return "Other"
    }
}
