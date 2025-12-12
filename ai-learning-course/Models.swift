//
//  Models.swift
//  ai-learning-course
//
//  Created by Claude Code on 01.12.2025.
//

import Foundation

// MARK: - Course Structure Models

struct Week: Identifiable, Codable, Hashable {
    let id: Int
    let title: String
    let days: [Day]
}

struct Day: Identifiable, Codable, Hashable {
    let id: Int
    let weekId: Int
    let title: String
    let description: String
    let type: DayType
}

enum DayType: String, Codable {
    case chat
    case jsonChat
    case clarificationChat
    case systemPromptChat
    case temperatureChat
    case comparisonChat
    case tokenTrackingChat
    case conversationSummaryChat
    case lesson
    case exercise
}

// MARK: - Chat Models

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    let tokenUsage: TokenUsage?

    init(id: UUID = UUID(), role: MessageRole, content: String, timestamp: Date = Date(), tokenUsage: TokenUsage? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.tokenUsage = tokenUsage
    }
}

struct TokenUsage: Codable {
    let inputTokens: Int
    let outputTokens: Int

    var totalTokens: Int {
        inputTokens + outputTokens
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
}

// MARK: - Claude API Models

struct ClaudeRequest: Codable {
    let model: String
    let maxTokens: Int
    let messages: [ClaudeMessage]
    let system: String?
    let temperature: Double?

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
        case system
        case temperature
    }
}

struct ClaudeMessage: Codable {
    let role: String
    let content: String
}

struct ClaudeResponse: Codable {
    let id: String
    let type: String
    let role: String
    let content: [ClaudeContent]
    let model: String
    let stopReason: String?
    let usage: ClaudeUsage

    enum CodingKeys: String, CodingKey {
        case id, type, role, content, model
        case stopReason = "stop_reason"
        case usage
    }
}

struct ClaudeContent: Codable {
    let type: String
    let text: String?
}

struct ClaudeUsage: Codable {
    let inputTokens: Int
    let outputTokens: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

struct ClaudeError: Codable {
    let type: String
    let error: ErrorDetail
}

struct ErrorDetail: Codable {
    let type: String
    let message: String
}

// MARK: - HuggingFace API Models (Chat Completions)

struct HuggingFaceChatRequest: Codable {
    let model: String
    let messages: [HuggingFaceMessage]
    let maxTokens: Int?
    let temperature: Double?
    let stream: Bool?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxTokens = "max_tokens"
        case temperature
        case stream
    }
}

struct HuggingFaceMessage: Codable {
    let role: String
    let content: String
}

struct HuggingFaceChatResponse: Codable {
    let id: String?
    let choices: [HuggingFaceChoice]
    let usage: HuggingFaceUsage?
}

struct HuggingFaceChoice: Codable {
    let message: HuggingFaceMessage
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case message
        case finishReason = "finish_reason"
    }
}

struct HuggingFaceUsage: Codable {
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

struct HuggingFaceError: Codable {
    let error: String
    let estimatedTime: Double?

    enum CodingKeys: String, CodingKey {
        case error
        case estimatedTime = "estimated_time"
    }
}

// MARK: - Comparison Models

struct ModelResponse: Identifiable {
    let id = UUID()
    let modelName: String
    let response: String
    let responseTime: TimeInterval
    let inputTokens: Int
    let outputTokens: Int
    let error: String?
}

struct ComparisonResult {
    let query: String
    let responses: [ModelResponse]
    let claudeAnalysis: String?
    let isLoading: Bool
}
