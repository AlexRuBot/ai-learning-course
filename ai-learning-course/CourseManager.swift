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
                        title: "Day 2: Coming Soon",
                        description: "More content coming soon",
                        type: .lesson
                    )
                ]
            )
        ]
    }
}
