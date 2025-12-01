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
    case lesson
    case exercise
}

// MARK: - Chat Models

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date

    init(id: UUID = UUID(), role: MessageRole, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
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

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
        case system
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
