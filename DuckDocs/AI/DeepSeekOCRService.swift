//
//  DeepSeekOCRService.swift
//  DuckDocs
//
//  Created by DuckDocs on 2026-01-30.
//

import Foundation
import AppKit

/// Service for analyzing screenshots using DeepSeek OCR 2 (MLX 4-bit)
@Observable
@MainActor
final class DeepSeekOCRService {
    /// Service state
    enum State {
        case idle
        case checking
        case processing
        case error(String)
    }

    /// Current state
    private(set) var state: State = .idle

    /// Processing progress (0.0 to 1.0)
    private(set) var progress: Double = 0.0

    /// Whether Python and dependencies are available
    private(set) var isAvailable: Bool = false

    /// Path to Python executable
    private var pythonPath: String = "/usr/bin/python3"

    /// Path to the OCR script
    private var scriptPath: String {
        Bundle.main.path(forResource: "deepseek_ocr", ofType: "py") ?? ""
    }

    /// Custom prompt for analysis
    var customPrompt: String?

    /// Maximum tokens for generation
    var maxTokens: Int = 2048

    init() {
        Task {
            await checkAvailability()
        }
    }

    /// Check if Python and dependencies are available
    func checkAvailability() async {
        state = .checking

        // Try common Python paths
        let pythonPaths = [
            "/usr/bin/python3",
            "/usr/local/bin/python3",
            "/opt/homebrew/bin/python3",
            "python3"
        ]

        for path in pythonPaths {
            if await checkPythonPath(path) {
                pythonPath = path
                isAvailable = true
                state = .idle
                return
            }
        }

        isAvailable = false
        state = .error("Python 3 with mlx-lm not found")
    }

    private func checkPythonPath(_ path: String) async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["-c", "import mlx_lm; print('ok')"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Analyze a single image
    func analyzeImage(_ image: NSImage, prompt: String? = nil) async throws -> String {
        guard isAvailable else {
            throw OCRError.pythonNotAvailable
        }

        state = .processing
        progress = 0.0

        // Save image to temp file
        let tempDir = FileManager.default.temporaryDirectory
        let imagePath = tempDir.appendingPathComponent(UUID().uuidString + ".png")

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            state = .error("Failed to convert image")
            throw OCRError.imageConversionFailed
        }

        try pngData.write(to: imagePath)

        defer {
            try? FileManager.default.removeItem(at: imagePath)
        }

        // Run Python script
        let result = try await runPythonScript(imagePath: imagePath.path, prompt: prompt)

        state = .idle
        progress = 1.0

        return result
    }

    /// Analyze multiple images and generate combined documentation
    func analyzeImages(_ captures: [CaptureResult], prompt: String? = nil) async throws -> String {
        guard isAvailable else {
            throw OCRError.pythonNotAvailable
        }

        state = .processing
        progress = 0.0

        var results: [String] = []

        for (index, capture) in captures.enumerated() {
            progress = Double(index) / Double(captures.count)

            let stepPrompt = prompt ?? """
            This is step \(capture.stepNumber) of a UI workflow.
            Action performed: \(capture.action.description)

            Analyze this screenshot and describe:
            1. What is shown on screen
            2. The result of the action
            3. Any important UI elements or text

            Be concise and focus on what's relevant to the action.
            """

            let result = try await analyzeImage(capture.screenshot, prompt: stepPrompt)
            results.append("## Step \(capture.stepNumber)\n\n**Action:** \(capture.action.description)\n\n\(result)")
        }

        state = .idle
        progress = 1.0

        return results.joined(separator: "\n\n---\n\n")
    }

    private func runPythonScript(imagePath: String, prompt: String?) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)

        var arguments = [scriptPath, "--image", imagePath, "--json"]
        if let prompt = prompt ?? customPrompt {
            arguments.append(contentsOf: ["--prompt", prompt])
        }
        arguments.append(contentsOf: ["--max-tokens", String(maxTokens)])

        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        return try await withCheckedThrowingContinuation { continuation in
            do {
                try process.run()

                Task.detached {
                    process.waitUntilExit()

                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                    if process.terminationStatus != 0 {
                        let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                        continuation.resume(throwing: OCRError.processFailed(errorMessage))
                        return
                    }

                    guard let output = String(data: outputData, encoding: .utf8) else {
                        continuation.resume(throwing: OCRError.invalidOutput)
                        return
                    }

                    // Parse JSON result
                    if let data = output.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let result = json["result"] as? String {
                        continuation.resume(returning: result)
                    } else if let data = output.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let error = json["error"] as? String {
                        continuation.resume(throwing: OCRError.processFailed(error))
                    } else {
                        // Return raw output if not JSON
                        continuation.resume(returning: output.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
            } catch {
                continuation.resume(throwing: OCRError.processFailed(error.localizedDescription))
            }
        }
    }
}

// MARK: - Errors

enum OCRError: LocalizedError {
    case pythonNotAvailable
    case imageConversionFailed
    case processFailed(String)
    case invalidOutput

    var errorDescription: String? {
        switch self {
        case .pythonNotAvailable:
            return "Python 3 with mlx-lm is not available. Please install: pip install mlx-lm pillow"
        case .imageConversionFailed:
            return "Failed to convert image to PNG format"
        case .processFailed(let message):
            return "OCR processing failed: \(message)"
        case .invalidOutput:
            return "Invalid output from OCR process"
        }
    }
}
