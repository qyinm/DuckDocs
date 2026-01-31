//
//  OpenAIProvider.swift
//  DuckDocs
//
//  Created by DuckDocs on 2026-01-31.
//

import Foundation
import AppKit

/// AI provider for OpenAI API (direct)
final class OpenAIProvider: AIProvider, Sendable {
    let providerType: AIProviderType = .openAI
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

        let urlString = "\(baseURL)/chat/completions"
        guard let url = URL(string: urlString) else {
            throw AIProviderError.invalidURL
        }

        print("[OpenAI] Sending request to \(modelId)...")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

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
                                "url": "data:image/jpeg;base64,\(base64Image)"
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
            print("[OpenAI] Error response: \(responseString)")

            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AIProviderError.serverError(httpResponse.statusCode, message)
            }
            throw AIProviderError.serverError(httpResponse.statusCode, responseString)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIProviderError.invalidResponse
        }

        print("[OpenAI] Analysis complete: \(content.prefix(100))...")
        return content
    }
}
