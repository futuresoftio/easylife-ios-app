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
        let patterns = [
            #"\b\d{4}[/-]\d{1,2}[/-]\d{1,2}\b"#,
            #"\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b"#,
            #"\b\d{1,2}\s+[A-Za-z]{3,9}\s+\d{2,4}\b"#,
            #"\b[A-Za-z]{3,9}\s+\d{1,2},?\s+\d{2,4}\b"#
        ]

        for line in lines {
            for pattern in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern) else {
                    continue
                }

                let range = NSRange(line.startIndex..<line.endIndex, in: line)
                guard let match = regex.firstMatch(in: line, range: range),
                      let matchRange = Range(match.range, in: line) else {
                    continue
                }

                let candidate = String(line[matchRange])
                if let parsedDate = parsedDate(from: candidate) {
                    return parsedDate
                }
            }
        }

        return nil
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
        let formatters = receiptDateFormatters
        for formatter in formatters {
            if let parsedDate = formatter.date(from: text) {
                return parsedDate
            }
        }

        return nil
    }

    private static let receiptDateFormatters: [DateFormatter] = [
        "yyyy-MM-dd",
        "yyyy/M/d",
        "d/M/yyyy",
        "dd/MM/yyyy",
        "d-MM-yyyy",
        "dd-MM-yyyy",
        "d/M/yy",
        "dd/MM/yy",
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
        return formatter
    }
}

private extension Array where Element == String {
    func pipe<T>(_ transform: ([String]) -> T) -> T {
        transform(self)
    }
}
