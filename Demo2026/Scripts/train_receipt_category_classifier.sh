#!/usr/bin/env swift

import Foundation

#if canImport(CreateML)
import CreateML
import NaturalLanguage
import TabularData

struct TrainingConfiguration {
    let inputURL: URL
    let outputURL: URL
    let author: String
    let version: String
    let modelDescription: String
}

enum TrainingScriptError: LocalizedError {
    case missingValue(flag: String)
    case unknownArgument(String)

    var errorDescription: String? {
        switch self {
        case .missingValue(let flag):
            return "Missing value for \(flag)."
        case .unknownArgument(let argument):
            return "Unknown argument: \(argument)"
        }
    }
}

let defaultInputPath = "Demo2026/Data/ReceiptCategoryTrainingTemplate.csv"
let defaultOutputPath = "Demo2026/Models/ReceiptCategoryClassifier.mlmodel"
let labelSeparator = "__"

func makeConfiguration(from arguments: [String]) throws -> TrainingConfiguration {
    var inputPath = defaultInputPath
    var outputPath = defaultOutputPath
    var author = "Wei Lin"
    var version = "1.0"
    var modelDescription = "Receipt item category classifier with hierarchical major and subcategory labels"

    var iterator = arguments.makeIterator()
    while let argument = iterator.next() {
        switch argument {
        case "--input":
            guard let value = iterator.next() else {
                throw TrainingScriptError.missingValue(flag: "--input")
            }
            inputPath = value
        case "--output":
            guard let value = iterator.next() else {
                throw TrainingScriptError.missingValue(flag: "--output")
            }
            outputPath = value
        case "--author":
            guard let value = iterator.next() else {
                throw TrainingScriptError.missingValue(flag: "--author")
            }
            author = value
        case "--version":
            guard let value = iterator.next() else {
                throw TrainingScriptError.missingValue(flag: "--version")
            }
            version = value
        case "--description":
            guard let value = iterator.next() else {
                throw TrainingScriptError.missingValue(flag: "--description")
            }
            modelDescription = value
        case "--help", "-h":
            printUsage()
            exit(0)
        default:
            throw TrainingScriptError.unknownArgument(argument)
        }
    }

    return TrainingConfiguration(
        inputURL: URL(fileURLWithPath: inputPath),
        outputURL: URL(fileURLWithPath: outputPath),
        author: author,
        version: version,
        modelDescription: modelDescription
    )
}

func printUsage() {
    let usage = """
    Usage:
      ./Demo2026/Scripts/train_receipt_category_classifier.sh [options]

    Options:
      --input <path>         Training CSV path. Default: \(defaultInputPath)
      --output <path>        Output .mlmodel path. Default: \(defaultOutputPath)
      --author <name>        Model author metadata. Default: Wei Lin
      --version <version>    Model version metadata. Default: 1.0
      --description <text>   Model description metadata.
      --help                 Show this help text.
    """

    print(usage)
}

func ensureParentDirectoryExists(for fileURL: URL) throws {
    let directoryURL = fileURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
}

func loadTrainingRows(from fileURL: URL) throws -> DataFrame {
    let rawCSV = try String(contentsOf: fileURL, encoding: .utf8)
    let lines = rawCSV
        .components(separatedBy: .newlines)
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    guard lines.count > 1 else {
        throw NSError(domain: "TrainingScript", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Training CSV must contain a header row and at least one data row."
        ])
    }

    var texts: [String] = []
    var labels: [String] = []

    for line in lines.dropFirst() {
        let fields = parseCSVLine(line)
        guard fields.count == 3 else {
            throw NSError(domain: "TrainingScript", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Invalid CSV row: \(line)"
            ])
        }

        texts.append(fields[0])
        labels.append(makeCombinedLabel(majorLabel: fields[1], subLabel: fields[2]))
    }

    var dataFrame = DataFrame()
    dataFrame.append(column: Column(name: "text", contents: texts))
    dataFrame.append(column: Column(name: "label", contents: labels))
    return dataFrame
}

func makeCombinedLabel(majorLabel: String, subLabel: String) -> String {
    "\(majorLabel)\(labelSeparator)\(subLabel)"
}

func parseCSVLine(_ line: String) -> [String] {
    var fields: [String] = []
    var current = ""
    var isInsideQuotes = false

    for character in line {
        if character == "\"" {
            isInsideQuotes.toggle()
            continue
        }

        if character == ",", !isInsideQuotes {
            fields.append(current)
            current = ""
            continue
        }

        current.append(character)
    }

    fields.append(current)
    return fields.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
}

func trainModel(using configuration: TrainingConfiguration) throws {
    let trainingData = try loadTrainingRows(from: configuration.inputURL)
    let parameters = MLTextClassifier.ModelParameters(
        validation: .split(strategy: .automatic),
        algorithm: .maxEnt(revision: 1),
        language: .english
    )

    let classifier = try MLTextClassifier(
        trainingData: trainingData,
        textColumn: "text",
        labelColumn: "label",
        parameters: parameters
    )

    let trainingAccuracy = (1.0 - classifier.trainingMetrics.classificationError) * 100
    let validationAccuracy = (1.0 - classifier.validationMetrics.classificationError) * 100

    print(String(format: "Training accuracy: %.2f%%", trainingAccuracy))
    print(String(format: "Validation accuracy: %.2f%%", validationAccuracy))

    let metadata = MLModelMetadata(
        author: configuration.author,
        shortDescription: configuration.modelDescription,
        version: configuration.version
    )

    try ensureParentDirectoryExists(for: configuration.outputURL)
    try classifier.write(to: configuration.outputURL, metadata: metadata)

    print("Model written to \(configuration.outputURL.path)")
    print("Add ReceiptCategoryClassifier.mlmodel to the Demo2026 app target in Xcode.")
}

do {
    let configuration = try makeConfiguration(from: Array(CommandLine.arguments.dropFirst()))
    try trainModel(using: configuration)
} catch {
    fputs("Error: \(error.localizedDescription)\n", stderr)
    printUsage()
    exit(1)
}

#else
fputs("Error: CreateML is unavailable in this Swift environment.\n", stderr)
exit(1)
#endif
