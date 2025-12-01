//
//  ClaudeManager.swift
//  ai-learning-course
//
//  Created by Claude Code on 01.12.2025.
//

import Foundation

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

    private init() {
        self.apiKey = UserDefaults.standard.string(forKey: "claudeAPIKey") ?? ""
    }

    var isAPIKeySet: Bool {
        !apiKey.isEmpty
    }

    func sendMessage(
        messages: [ChatMessage],
        systemPrompt: String? = nil
    ) async throws -> String {
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
            maxTokens: 4096,
            messages: claudeMessages,
            system: systemPrompt
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

        return text
    }

    func sendMessage(
        messageText: String,
        conversationHistory: [ChatMessage] = []
    ) async throws -> String {
        var allMessages = conversationHistory
        allMessages.append(ChatMessage(role: .user, content: messageText))

        return try await sendMessage(messages: allMessages)
    }
}
