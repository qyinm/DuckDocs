//
//  DeepSeekOCRService.swift
//  DuckDocs
//
//  Created by DuckDocs on 2026-01-30.
//

import Foundation
import AppKit
import MLXLMCommon
import MLXLLM

/// Service for analyzing screenshots using Vision Language Model (MLX Swift)
@Observable
@MainActor
final class DeepSeekOCRService {
    /// Service state
    enum State {
        case idle
        case loading
        case processing
        case error(String)
    }

    /// Current state
    private(set) var state: State = .idle

    /// Processing progress (0.0 to 1.0)
    private(set) var progress: Double = 0.0

    /// Whether the model is loaded and ready
    private(set) var isReady: Bool = false

    /// Model loading progress
    private(set) var loadingProgress: Double = 0.0

    /// VLM model ID (4-bit quantized for efficiency)
    private let modelId = "mlx-community/Qwen2.5-VL-3B-Instruct-4bit"

    /// Loaded model context
    private var modelContext: ModelContext?

    /// Chat session for maintaining context
    private var chatSession: ChatSession?

    /// Custom prompt for analysis
    var customPrompt: String?

    /// Maximum tokens for generation
    var maxTokens: Int = 2048

    /// Image resize dimensions for processing
    private let imageSize = CGSize(width: 512, height: 512)

    init() {}

    /// Load the VLM model
    func loadModel() async throws {
        guard modelContext == nil else { return }

        state = .loading
        loadingProgress = 0.0

        do {
            // Load the vision language model
            let context = try await MLXLMCommon.loadModel(
                id: modelId,
                progressHandler: { [weak self] progress in
                    Task { @MainActor in
                        self?.loadingProgress = progress.fractionCompleted
                    }
                }
            )

            modelContext = context

            // Create chat session with image processing config
            let processing = UserInput.Processing(resize: imageSize)
            chatSession = ChatSession(
                context,
                generateParameters: GenerateParameters(maxTokens: maxTokens),
                processing: processing
            )

            isReady = true
            state = .idle
            loadingProgress = 1.0
        } catch {
            state = .error("Failed to load model: \(error.localizedDescription)")
            throw VisionError.modelLoadFailed(error.localizedDescription)
        }
    }

    /// Analyze a single image
    func analyzeImage(_ image: NSImage, prompt: String? = nil) async throws -> String {
        // Ensure model is loaded
        if !isReady {
            try await loadModel()
        }

        guard let session = chatSession else {
            throw VisionError.modelNotReady
        }

        state = .processing
        progress = 0.0

        // Save image to temp file
        let tempURL = try saveImageToTemp(image)

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        let analysisPrompt = prompt ?? customPrompt ?? """
        Analyze this screenshot and describe:
        1. What UI elements are visible
        2. Any text content shown
        3. The current state of the interface

        Be concise and focus on actionable information.
        """

        do {
            // Use the VLM to analyze the image
            let result = try await session.respond(
                to: analysisPrompt,
                image: .url(tempURL)
            )

            state = .idle
            progress = 1.0

            return result
        } catch {
            state = .error("Analysis failed: \(error.localizedDescription)")
            throw VisionError.analysisFailed(error.localizedDescription)
        }
    }

    /// Analyze multiple images and generate combined documentation
    func analyzeImages(_ captures: [CaptureResult], prompt: String? = nil) async throws -> [String] {
        // Ensure model is loaded
        if !isReady {
            try await loadModel()
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
            results.append(result)
        }

        state = .idle
        progress = 1.0

        return results
    }

    /// Reset the chat session (clears context)
    func resetSession() {
        guard let context = modelContext else { return }

        let processing = UserInput.Processing(resize: imageSize)
        chatSession = ChatSession(
            context,
            generateParameters: GenerateParameters(maxTokens: maxTokens),
            processing: processing
        )
    }

    /// Unload the model to free memory
    func unloadModel() {
        chatSession = nil
        modelContext = nil
        isReady = false
        state = .idle
    }

    // MARK: - Private Helpers

    private func saveImageToTemp(_ image: NSImage) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let imagePath = tempDir.appendingPathComponent(UUID().uuidString + ".png")

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw VisionError.imageConversionFailed
        }

        try pngData.write(to: imagePath)
        return imagePath
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
            return "Vision model is not ready. Please wait for it to load."
        case .imageConversionFailed:
            return "Failed to convert image to PNG format"
        case .analysisFailed(let message):
            return "Image analysis failed: \(message)"
        }
    }
}
