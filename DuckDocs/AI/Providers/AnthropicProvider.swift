//
//  AnthropicProvider.swift
//  DuckDocs
//
//  Created by DuckDocs on 2026-01-31.
//

import Foundation
import AppKit

/// AI provider for Anthropic (Claude) API
final class AnthropicProvider: AIProvider, Sendable {
    let providerType: AIProviderType = .anthropic
    let modelId: String
    private let apiKey: String
    private let baseURL: String
    private let maxTokens: Int

    init(config: AIProviderConfig, maxTokens: Int = 4096) {
        self.modelId = config.modelId
        self.apiKey = config.apiKey
        self.baseURL = config.effectiveBaseURL
        self.maxTokens = maxTokens
    }

    func analyzeImage(_ image: NSImage, prompt: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw AIProviderError.apiKeyMissing
        }

        guard let base64Image = ImageUtils.imageToBase64(image) else {
            throw AIProviderError.imageConversionFailed
        }

        let urlString = "\(baseURL)/messages"
        guard let url = URL(string: urlString) else {
            throw AIProviderError.invalidURL
        }

        print("[Anthropic] Sending request to \(modelId)...")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        // Anthropic uses a different format for images
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
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProviderError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let responseString = String(data: data, encoding: .utf8) ?? "No response body"
            print("[Anthropic] Error response: \(responseString)")

            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AIProviderError.serverError(httpResponse.statusCode, message)
            }
            throw AIProviderError.serverError(httpResponse.statusCode, responseString)
        }

        // Anthropic response format is different
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw AIProviderError.invalidResponse
        }

        print("[Anthropic] Analysis complete: \(text.prefix(100))...")
        return text
    }
}
