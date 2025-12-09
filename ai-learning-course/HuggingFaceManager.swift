//
//  HuggingFaceManager.swift
//  ai-learning-course
//
//  Created by Claude Code on 09.12.2025.
//

import Foundation

class HuggingFaceManager: ObservableObject {
    static let shared = HuggingFaceManager()

    @Published var apiKey: String {
        didSet {
            UserDefaults.standard.set(apiKey, forKey: "HuggingFaceAPIKey")
        }
    }

    var isAPIKeySet: Bool {
        !apiKey.isEmpty
    }

    // New Chat Completions endpoint
    private let chatCompletionsURL = "https://router.huggingface.co/v1/chat/completions"

    private init() {
        self.apiKey = UserDefaults.standard.string(forKey: "HuggingFaceAPIKey") ?? ""
    }

    enum HuggingFaceModel: String {
        case llama = "meta-llama/Llama-3.2-3B-Instruct"
        case qwen = "Qwen/Qwen2.5-7B-Instruct"
        case gemma = "google/gemma-3-27b-it"

        var displayName: String {
            switch self {
            case .llama: return "Llama 3.2 3B"
            case .qwen: return "Qwen 2.5 7B"
            case .gemma: return "Gemma 3 27B"
            }
        }
    }

    func queryModel(model: HuggingFaceModel, prompt: String) async throws -> ModelResponse {
        let startTime = CFAbsoluteTimeGetCurrent()

        guard !apiKey.isEmpty else {
            throw NSError(domain: "HuggingFace", code: 401, userInfo: [NSLocalizedDescriptionKey: "API key not set"])
        }

        guard let url = URL(string: chatCompletionsURL) else {
            throw NSError(domain: "HuggingFace", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let chatRequest = HuggingFaceChatRequest(
            model: model.rawValue,
            messages: [
                HuggingFaceMessage(role: "user", content: prompt)
            ],
            maxTokens: 200,
            temperature: 0.7,
            stream: false
        )

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(chatRequest)

        let (data, response) = try await URLSession.shared.data(for: request)
        let responseTime = CFAbsoluteTimeGetCurrent() - startTime

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "HuggingFace", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        // Handle errors
        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(HuggingFaceError.self, from: data) {
                return ModelResponse(
                    modelName: model.displayName,
                    response: "",
                    responseTime: responseTime,
                    inputTokens: 0,
                    outputTokens: 0,
                    error: errorResponse.error
                )
            }

            // Try to get error from response body
            if let errorString = String(data: data, encoding: .utf8) {
                return ModelResponse(
                    modelName: model.displayName,
                    response: "",
                    responseTime: responseTime,
                    inputTokens: 0,
                    outputTokens: 0,
                    error: "HTTP \(httpResponse.statusCode): \(errorString)"
                )
            }

            throw NSError(domain: "HuggingFace", code: httpResponse.statusCode,
                         userInfo: [NSLocalizedDescriptionKey: "HTTP Error \(httpResponse.statusCode)"])
        }

        // Parse successful response
        let decoder = JSONDecoder()
        let chatResponse = try decoder.decode(HuggingFaceChatResponse.self, from: data)

        guard let firstChoice = chatResponse.choices.first else {
            throw NSError(domain: "HuggingFace", code: 500,
                         userInfo: [NSLocalizedDescriptionKey: "No choices in response"])
        }

        let generatedText = firstChoice.message.content
        let inputTokens = chatResponse.usage?.promptTokens ?? (prompt.count / 4)
        let outputTokens = chatResponse.usage?.completionTokens ?? (generatedText.count / 4)

        return ModelResponse(
            modelName: model.displayName,
            response: generatedText,
            responseTime: responseTime,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            error: nil
        )
    }

    func queryAllModels(prompt: String) async -> [ModelResponse] {
        let models: [HuggingFaceModel] = [.llama, .qwen, .gemma]

        return await withTaskGroup(of: ModelResponse?.self) { group in
            for model in models {
                group.addTask {
                    do {
                        return try await self.queryModel(model: model, prompt: prompt)
                    } catch {
                        return ModelResponse(
                            modelName: model.displayName,
                            response: "",
                            responseTime: 0,
                            inputTokens: 0,
                            outputTokens: 0,
                            error: error.localizedDescription
                        )
                    }
                }
            }

            var results: [ModelResponse] = []
            for await result in group {
                if let result = result {
                    results.append(result)
                }
            }
            return results
        }
    }
}
