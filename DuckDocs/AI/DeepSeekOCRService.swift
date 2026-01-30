//
//  DeepSeekOCRService.swift
//  DuckDocs
//
//  Created by DuckDocs on 2026-01-30.
//

import Foundation
import AppKit

/// Service for analyzing screenshots using OpenRouter API
@Observable
@MainActor
final class DeepSeekOCRService {
    enum State: Equatable {
        case idle
        case loading
        case processing
        case error(String)
    }

    private(set) var state: State = .idle
    private(set) var progress: Double = 0.0
    private(set) var isReady: Bool = true  // Always ready with API
    private(set) var loadingProgress: Double = 1.0

    // OpenRouter API configuration
    private let apiURL = "https://openrouter.ai/api/v1/chat/completions"
    private let modelId = "openai/gpt-4.1-nano"

    /// API Key - set this before use
    var apiKey: String = ""

    /// Custom prompt for analysis
    var customPrompt: String?

    /// Maximum tokens for generation
    var maxTokens: Int = 4096

    /// Shared instance for app-wide use
    static let shared = DeepSeekOCRService()

    init() {
        // Try to load API key from environment or UserDefaults
        if let key = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"] {
            apiKey = key
        } else if let key = UserDefaults.standard.string(forKey: "openrouter_api_key") {
            apiKey = key
        }
    }

    /// Preload - no-op for API based service
    func preloadModel() {
        // No preloading needed for API
    }

    /// Load model - no-op for API based service
    func loadModel() async throws {
        // No loading needed for API
    }

    /// Analyze a single image and convert to markdown
    func analyzeImage(_ image: NSImage, prompt: String? = nil) async throws -> String {
        guard !apiKey.isEmpty else {
            throw VisionError.apiKeyMissing
        }

        state = .processing
        progress = 0.0

        let analysisPrompt = prompt ?? customPrompt ?? "Convert this image to markdown format. Extract all text and preserve the layout structure."

        print("[OpenRouter] Converting image to base64...")

        // Convert image to base64
        guard let base64Image = imageToBase64(image) else {
            throw VisionError.imageConversionFailed
        }

        print("[OpenRouter] Sending request to API...")

        let result = try await sendRequest(prompt: analysisPrompt, imageBase64: base64Image)

        state = .idle
        progress = 1.0

        print("[OpenRouter] Analysis complete: \(result.prefix(100))...")
        return result
    }

    private func imageToBase64(_ image: NSImage) -> String? {
        // Resize if too large (max 2048px on longest side)
        let maxDimension: CGFloat = 2048
        var targetSize = image.size

        if image.size.width > maxDimension || image.size.height > maxDimension {
            let scale = maxDimension / max(image.size.width, image.size.height)
            targetSize = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        }

        let resizedImage = NSImage(size: targetSize)
        resizedImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: targetSize),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy,
                   fraction: 1.0)
        resizedImage.unlockFocus()

        guard let tiffData = resizedImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            return nil
        }

        print("[OpenRouter] Image size: \(Int(targetSize.width))x\(Int(targetSize.height)), data: \(jpegData.count / 1024)KB")
        return jpegData.base64EncodedString()
    }

    private func sendRequest(prompt: String, imageBase64: String) async throws -> String {
        guard let url = URL(string: apiURL) else {
            throw VisionError.analysisFailed("Invalid API URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("DuckDocs/1.0", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("DuckDocs", forHTTPHeaderField: "X-Title")

        let requestBody: [String: Any] = [
            "model": modelId,
            "max_tokens": maxTokens,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": prompt
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(imageBase64)"
                            ]
                        ]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VisionError.analysisFailed("Invalid response")
        }

        if httpResponse.statusCode != 200 {
            let responseString = String(data: data, encoding: .utf8) ?? "No response body"
            print("[OpenRouter] Error response: \(responseString)")

            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw VisionError.analysisFailed("API Error: \(message)")
            }
            throw VisionError.analysisFailed("HTTP \(httpResponse.statusCode): \(responseString)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw VisionError.analysisFailed("Failed to parse response")
        }

        return content
    }

    /// Unload - no-op for API based service
    func unloadModel() {
        // No unloading needed for API
    }
}

// MARK: - Errors

enum VisionError: LocalizedError {
    case modelLoadFailed(String)
    case modelNotReady
    case imageConversionFailed
    case analysisFailed(String)
    case apiKeyMissing

    var errorDescription: String? {
        switch self {
        case .modelLoadFailed(let message):
            return "Failed to load model: \(message)"
        case .modelNotReady:
            return "Model is not ready"
        case .imageConversionFailed:
            return "Failed to convert image"
        case .analysisFailed(let message):
            return "Image analysis failed: \(message)"
        case .apiKeyMissing:
            return "OpenRouter API key is missing. Please set it in Settings."
        }
    }
}
