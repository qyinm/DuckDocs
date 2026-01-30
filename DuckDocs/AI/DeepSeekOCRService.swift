//
//  DeepSeekOCRService.swift
//  DuckDocs
//
//  Created by DuckDocs on 2026-01-30.
//

import Foundation
import AppKit
import Vision

/// Service for analyzing screenshots using macOS Vision framework
@Observable
@MainActor
final class DeepSeekOCRService {
    /// Service state
    enum State: Equatable {
        case idle
        case loading
        case processing
        case error(String)
    }

    /// Current state
    private(set) var state: State = .idle

    /// Processing progress (0.0 to 1.0)
    private(set) var progress: Double = 0.0

    /// Whether the service is ready
    private(set) var isReady: Bool = true

    /// Model loading progress (not used for Vision, kept for compatibility)
    private(set) var loadingProgress: Double = 1.0

    /// Custom prompt for analysis (not used for Vision OCR)
    var customPrompt: String?

    init() {}

    /// Analyze a single image using Vision framework OCR
    func analyzeImage(_ image: NSImage, prompt: String? = nil) async throws -> String {
        state = .processing
        progress = 0.0

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            state = .error("Failed to convert image")
            throw VisionError.imageConversionFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: VisionError.analysisFailed(error.localizedDescription))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "No text detected in screenshot")
                    return
                }

                // Extract text from observations
                var texts: [String] = []
                for observation in observations {
                    if let topCandidate = observation.topCandidates(1).first {
                        texts.append(topCandidate.string)
                    }
                }

                let result = texts.isEmpty ? "No text detected in screenshot" : texts.joined(separator: "\n")
                continuation.resume(returning: result)
            }

            // Configure for best accuracy
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "ko-KR", "ja-JP", "zh-Hans", "zh-Hant"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: VisionError.analysisFailed(error.localizedDescription))
            }
        }
    }

    /// Analyze multiple images and generate combined documentation
    func analyzeImages(_ captures: [CaptureResult], prompt: String? = nil) async throws -> [String] {
        state = .processing
        progress = 0.0

        var results: [String] = []

        for (index, capture) in captures.enumerated() {
            progress = Double(index) / Double(captures.count)

            let result = try await analyzeImage(capture.screenshot, prompt: prompt)

            // Format the result with action context
            let formatted = """
            **Action:** \(capture.action.description)

            **Screen Content:**
            \(result)
            """

            results.append(formatted)
        }

        state = .idle
        progress = 1.0

        return results
    }

    /// Reset (no-op for Vision framework)
    func resetSession() {}

    /// Unload (no-op for Vision framework)
    func unloadModel() {
        state = .idle
    }
}

// MARK: - Errors

enum VisionError: LocalizedError {
    case modelLoadFailed(String)
    case modelNotReady
    case imageConversionFailed
    case analysisFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelLoadFailed(let message):
            return "Failed to load vision model: \(message)"
        case .modelNotReady:
            return "Vision service is not ready."
        case .imageConversionFailed:
            return "Failed to convert image for analysis"
        case .analysisFailed(let message):
            return "Image analysis failed: \(message)"
        }
    }
}
