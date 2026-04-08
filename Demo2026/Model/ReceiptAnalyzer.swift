//
//  ReceiptAnalyzer.swift
//  TestApp
//

import Foundation
import UIKit
import Vision

enum ReceiptAnalyzer {
    static func analyze(images: [UIImage]) async throws -> [ReceiptExpense] {
        try await Task.detached(priority: .userInitiated) {
            try images.flatMap(recognizedTextLines(from:))
        }
        .value
        .pipe(parseExpenses)
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
        let normalizedLines = normalizedReceiptLines(from: lines)
        
        let prediction = parseCategory(from: normalizedLines)
        let title = prediction?.subCategory ?? "Scanned Receipt"
        let category = prediction?.majorCategory ?? "Other"
        
        let createdAt = parseDate(from: normalizedLines) ?? Date()
        
        let amount = parseAmount(from: normalizedLines) ?? 0.0
        
        return [
            ReceiptExpense(
                category: category,
                item: ExpenseItem(
                    title: title,
                    amount: amount,
                    createdAt: createdAt
                )
            )
        ]
    }

    private static func parseCategory(from lines: [String]) -> ReceiptCategoryModelLoader.Prediction? {
        for line in lines {
            if let prediction = ReceiptCategoryModelLoader.predictedResult(for: line) {
                return prediction
            }
        }

        return nil
    }

    private static func normalizedReceiptLines(from lines: [String]) -> [String] {
        lines
            .map {
                $0.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
    }

    private static func parseAmount(from lines: [String]) -> Double? {
        let prioritizedTerms = ["amount due", "grand total", "total", "total aud", "payment", "paid"]
        let excludedTerms = ["subtotal", "tax", "gst", "change", "saving", "discount"]
        var fallbackAmount: Double?

        for line in lines {
            guard let lineAmount = amount(in: line) else {
                continue
            }

            let lowercaseLine = line.lowercased()
            if excludedTerms.contains(where: lowercaseLine.contains) {
                continue
            }

            if prioritizedTerms.contains(where: lowercaseLine.contains) {
                return lineAmount
            }

            fallbackAmount = max(fallbackAmount ?? 0, lineAmount)
        }

        return fallbackAmount
    }

    private static func parseDate(from lines: [String]) -> Date? {
        let labeledLines = lines.filter(isStrictReceiptDateLine)

        if let parsedLabeledDate = parseDate(fromCandidateLines: labeledLines) {
            return parsedLabeledDate
        }

        return parseDate(fromCandidateLines: lines)
    }

    private static func parseDate(fromCandidateLines lines: [String]) -> Date? {
        for line in lines {
            let normalizedLine = normalizedDateLine(line)

            if let parsedDate = parsedDate(from: normalizedLine) {
                return parsedDate
            }

            for candidate in dateCandidates(in: normalizedLine) {
                if let parsedDate = parsedDate(from: candidate) {
                    return parsedDate
                }
            }

            if let detectedDate = detectedDate(in: normalizedLine) {
                return detectedDate
            }
        }

        return nil
    }

    private static func isStrictReceiptDateLine(_ text: String) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedText.range(
            of: #"(?i)^date\s*/\s*time\b"#,
            options: .regularExpression
        ) != nil
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

    private static func parsedDate(from text: String) -> Date? {
        let normalizedText = text
            .replacingOccurrences(of: ".", with: "/")
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted.union(.whitespacesAndNewlines))

        for formatter in receiptDateFormatters {
            if let parsedDate = formatter.date(from: normalizedText) {
                return parsedDate
            }
        }

        return nil
    }

    private static func normalizedDateLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "(?i)date\\s*/\\s*time", with: "", options: .regularExpression)
            .replacingOccurrences(of: "(?i)date\\s*:", with: "", options: .regularExpression)
            .replacingOccurrences(of: "(?i)time\\s*:", with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func detectedDate(in text: String) -> Date? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector.matches(in: text, range: range).compactMap(\.date).first
    }

    private static func dateCandidates(in text: String) -> [String] {
        let patterns = [
            #"\b\d{1,2}[/-\.]\d{1,2}[/-\.]\d{2,4}\s+\d{1,2}:\d{2}\b"#,
            #"\b\d{4}[/-\.]\d{1,2}[/-\.]\d{1,2}\s+\d{1,2}:\d{2}\b"#,
            #"\b\d{4}[/-\.]\d{1,2}[/-\.]\d{1,2}\b"#,
            #"\b\d{1,2}[/-\.]\d{1,2}[/-\.]\d{2,4}\b"#,
            #"\b\d{1,2}\s+[A-Za-z]{3,9}\s+\d{2,4}\b"#,
            #"\b[A-Za-z]{3,9}\s+\d{1,2},?\s+\d{2,4}\b"#
        ]

        var candidates: [String] = []
        let range = NSRange(text.startIndex..<text.endIndex, in: text)

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                continue
            }

            for match in regex.matches(in: text, range: range) {
                guard let matchRange = Range(match.range, in: text) else {
                    continue
                }
                candidates.append(String(text[matchRange]))
            }
        }

        return candidates
    }

    private static let receiptDateFormatters: [DateFormatter] = [
        "d/M/yy HH:mm",
        "dd/MM/yy HH:mm",
        "d/M/yyyy HH:mm",
        "dd/MM/yyyy HH:mm",
        "M/d/yy HH:mm",
        "MM/dd/yy HH:mm",
        "M/d/yyyy HH:mm",
        "MM/dd/yyyy HH:mm",
        "yyyy/M/d HH:mm",
        "yyyy/MM/dd HH:mm",
        "yyyy-MM-dd HH:mm",
        "d-M-yy HH:mm",
        "dd-MM-yy HH:mm",
        "d-M-yyyy HH:mm",
        "dd-MM-yyyy HH:mm",
        "yyyy-MM-dd",
        "yyyy/M/d",
        "yyyy/MM/dd",
        "d/M/yyyy",
        "dd/MM/yyyy",
        "M/d/yyyy",
        "MM/dd/yyyy",
        "d-MM-yyyy",
        "dd-MM-yyyy",
        "M-d-yyyy",
        "MM-dd-yyyy",
        "d/M/yy",
        "dd/MM/yy",
        "M/d/yy",
        "MM/dd/yy",
        "d MMM yyyy",
        "dd MMM yyyy",
        "d MMMM yyyy",
        "dd MMMM yyyy",
        "MMM d yyyy",
        "MMMM d yyyy",
        "MMM d, yyyy",
        "MMMM d, yyyy"
    ].map { format in
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        formatter.isLenient = false
        return formatter
    }
}

private extension Array where Element == String {
    func pipe<T>(_ transform: ([String]) -> T) -> T {
        transform(self)
    }
}
