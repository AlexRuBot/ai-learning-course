//
//  CourseManager.swift
//  ai-learning-course
//
//  Created by Claude Code on 01.12.2025.
//

import Foundation

class CourseManager: ObservableObject {
    static let shared = CourseManager()

    @Published var weeks: [Week]

    private init() {
        self.weeks = [
            Week(
                id: 1,
                title: "Week 1: Introduction to AI",
                days: [
                    Day(
                        id: 1,
                        weekId: 1,
                        title: "Day 1: Free Chat with Claude",
                        description: "Get to know Claude Sonnet 4.5 through a free-form conversation",
                        type: .chat
                    ),
                    Day(
                        id: 2,
                        weekId: 1,
                        title: "Day 2: JSON Response Chat",
                        description: "Chat with Claude receiving pure JSON responses",
                        type: .jsonChat
                    ),
                    Day(
                        id: 3,
                        weekId: 1,
                        title: "Day 3: Interactive Clarification",
                        description: "Claude asks clarifying questions before answering",
                        type: .clarificationChat
                    ),
                    Day(
                        id: 5,
                        weekId: 1,
                        title: "Day 5: Dynamic System Prompt",
                        description: "Change Claude's behavior by modifying system prompts",
                        type: .systemPromptChat
                    )
                ]
            ),
            Week(
                id: 2,
                title: "Week 2: Advanced Features",
                days: [
                    Day(
                        id: 6,
                        weekId: 2,
                        title: "Day 1: Temperature Control",
                        description: "Adjust AI creativity by controlling temperature parameter",
                        type: .temperatureChat
                    ),
                    Day(
                        id: 7,
                        weekId: 2,
                        title: "Day 2: AI Model Comparison",
                        description: "Compare responses from 3 different AI models with Claude's analysis",
                        type: .comparisonChat
                    ),
                    Day(
                        id: 8,
                        weekId: 2,
                        title: "Day 3: Token Usage Tracking",
                        description: "Monitor API token usage with real-time counting and cost estimation",
                        type: .tokenTrackingChat
                    )
                ]
            )
        ]
    }
}
