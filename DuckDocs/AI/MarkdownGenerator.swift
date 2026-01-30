//
//  MarkdownGenerator.swift
//  DuckDocs
//
//  Created by DuckDocs on 2026-01-30.
//

import Foundation
import AppKit

/// Generates markdown documentation from capture results and AI analysis
struct MarkdownGenerator {
    /// Output configuration
    struct Configuration {
        var includeTableOfContents: Bool = true
        var includeTimestamps: Bool = false
        var includeActionDetails: Bool = true
        var imageFormat: ImageFormat = .png
        var imageFolder: String = "images"

        enum ImageFormat: String {
            case png
            case jpg
        }
    }

    var configuration = Configuration()

    /// Generate markdown documentation
    func generate(
        title: String,
        captures: [CaptureResult],
        aiAnalysis: [String]? = nil
    ) -> String {
        var markdown = ""

        // Header
        markdown += "# \(title)\n\n"

        if configuration.includeTimestamps {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .short
            markdown += "*Generated: \(formatter.string(from: Date()))*\n\n"
        }

        // Table of contents
        if configuration.includeTableOfContents && !captures.isEmpty {
            markdown += "## Table of Contents\n\n"
            for capture in captures {
                markdown += "- [Step \(capture.stepNumber): \(capture.action.shortDescription)](#step-\(capture.stepNumber))\n"
            }
            markdown += "\n---\n\n"
        }

        // Steps
        for (index, capture) in captures.enumerated() {
            markdown += generateStep(
                capture: capture,
                analysis: aiAnalysis?[safe: index]
            )
            markdown += "\n---\n\n"
        }

        return markdown
    }

    private func generateStep(capture: CaptureResult, analysis: String?) -> String {
        var step = ""

        // Step header
        step += "## Step \(capture.stepNumber)\n\n"

        // Action description
        if configuration.includeActionDetails {
            step += "**Action:** \(capture.action.description)\n\n"
        }

        // Screenshot
        let imageName = "step_\(capture.stepNumber).\(configuration.imageFormat.rawValue)"
        let imagePath = "\(configuration.imageFolder)/\(imageName)"
        step += "![Step \(capture.stepNumber)](\(imagePath))\n\n"

        // AI analysis
        if let analysis = analysis, !analysis.isEmpty {
            step += analysis + "\n\n"
        }

        return step
    }

    /// Export documentation to a directory
    func export(
        title: String,
        captures: [CaptureResult],
        aiAnalysis: [String]? = nil,
        to directory: URL
    ) throws -> URL {
        // Create directories
        let imagesDir = directory.appendingPathComponent(configuration.imageFolder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        // Save images
        for capture in captures {
            let imageName = "step_\(capture.stepNumber).\(configuration.imageFormat.rawValue)"
            let imageURL = imagesDir.appendingPathComponent(imageName)

            guard let tiffData = capture.screenshot.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData) else {
                continue
            }

            let imageData: Data?
            switch configuration.imageFormat {
            case .png:
                imageData = bitmap.representation(using: .png, properties: [:])
            case .jpg:
                imageData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
            }

            if let data = imageData {
                try data.write(to: imageURL)
            }
        }

        // Generate and save markdown
        let markdown = generate(title: title, captures: captures, aiAnalysis: aiAnalysis)
        let markdownURL = directory.appendingPathComponent("README.md")
        try markdown.write(to: markdownURL, atomically: true, encoding: .utf8)

        return markdownURL
    }
}

// MARK: - Action Extensions

extension Action {
    /// Short description for table of contents
    var shortDescription: String {
        switch self {
        case .click(_, _, let button):
            return "\(button.rawValue.capitalized) Click"
        case .doubleClick(_, _, let button):
            return "\(button.rawValue.capitalized) Double-Click"
        case .drag:
            return "Drag"
        case .scroll:
            return "Scroll"
        case .delay(let seconds):
            return "Wait \(String(format: "%.1f", seconds))s"
        }
    }
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
