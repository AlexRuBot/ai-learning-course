//
//  ClaudeManager.swift
//  ai-learning-course
//
//  Created by Claude Code on 01.12.2025.
//

import Foundation

struct ClaudeMessageResult {
    let text: String
    let tokenUsage: TokenUsage
}

class ClaudeManager: ObservableObject {
    static let shared = ClaudeManager()

    private let apiEndpoint = "https://api.anthropic.com/v1/messages"
    private let modelName = "claude-sonnet-4-5-20250929"
    private let networkManager = NetworkManager.shared

    @Published var apiKey: String {
        didSet {
            UserDefaults.standard.set(apiKey, forKey: "claudeAPIKey")
        }
    }

    @Published var maxTokens: Int {
        didSet {
            UserDefaults.standard.set(maxTokens, forKey: "maxTokens")
        }
    }

    private init() {
        self.apiKey = UserDefaults.standard.string(forKey: "claudeAPIKey") ?? ""
        self.maxTokens = UserDefaults.standard.integer(forKey: "maxTokens") == 0 ? 4096 : UserDefaults.standard.integer(forKey: "maxTokens")
    }

    var isAPIKeySet: Bool {
        !apiKey.isEmpty
    }

    func sendMessage(
        messages: [ChatMessage],
        systemPrompt: String? = nil,
        temperature: Double? = nil
    ) async throws -> ClaudeMessageResult {
        guard isAPIKeySet else {
            throw NetworkError.httpError(statusCode: 401, message: "API key not set")
        }

        guard let url = URL(string: apiEndpoint) else {
            throw NetworkError.invalidURL
        }

        let claudeMessages = messages.map { message in
            ClaudeMessage(role: message.role.rawValue, content: message.content)
        }

        let request = ClaudeRequest(
            model: modelName,
            maxTokens: maxTokens,
            messages: claudeMessages,
            system: systemPrompt,
            temperature: temperature
        )

        let headers = [
            "X-Api-Key": apiKey,
            "Content-Type": "application/json",
            "anthropic-version": "2023-06-01"
        ]

        let response: ClaudeResponse = try await networkManager.post(
            url: url,
            headers: headers,
            body: request
        )

        guard let firstContent = response.content.first,
              let text = firstContent.text else {
            throw NetworkError.noData
        }

        let tokenUsage = TokenUsage(
            inputTokens: response.usage.inputTokens,
            outputTokens: response.usage.outputTokens
        )

        return ClaudeMessageResult(text: text, tokenUsage: tokenUsage)
    }

    func sendMessage(
        messageText: String,
        conversationHistory: [ChatMessage] = []
    ) async throws -> ClaudeMessageResult {
        var allMessages = conversationHistory
        allMessages.append(ChatMessage(role: .user, content: messageText))

        return try await sendMessage(messages: allMessages)
    }
}
