//
//  WeekDaySelectionView.swift
//  ai-learning-course
//
//  Created by Claude Code on 01.12.2025.
//

import SwiftUI

struct WeekDaySelectionView: View {
    @ObservedObject var courseManager = CourseManager.shared
    @ObservedObject var claudeManager = ClaudeManager.shared
    @State private var showSettings = false
    @State private var selectedDay: Day?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if !claudeManager.isAPIKeySet {
                        APIKeyWarningCard(showSettings: $showSettings)
                    }

                    ForEach(courseManager.weeks) { week in
                        WeekCard(week: week, selectedDay: $selectedDay)
                    }
                }
                .padding()
            }
            .navigationTitle("AI Learning Course")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .navigationDestination(item: $selectedDay) { day in
                switch day.type {
                case .chat:
                    ChatView(day: day)
                case .jsonChat:
                    JSONChatView(day: day)
                default:
                    ComingSoonView(day: day)
                }
            }
        }
    }
}

struct APIKeyWarningCard: View {
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                Text("API Key Required")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }

            Text("Please configure your Claude API key in settings to use the learning features.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                showSettings = true
            } label: {
                HStack {
                    Image(systemName: "gear")
                    Text("Open Settings")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

struct WeekCard: View {
    let week: Week
    @Binding var selectedDay: Day?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(week.title)
                .font(.title2)
                .fontWeight(.bold)

            VStack(spacing: 12) {
                ForEach(week.days) { day in
                    DayRow(day: day)
                        .onTapGesture {
                            selectedDay = day
                        }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
    }
}

struct DayRow: View {
    let day: Day

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(iconColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(day.title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(day.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var iconName: String {
        switch day.type {
        case .chat:
            return "bubble.left.and.bubble.right.fill"
        case .jsonChat:
            return "curlybraces"
        case .lesson:
            return "book.fill"
        case .exercise:
            return "pencil.and.list.clipboard"
        }
    }

    private var iconColor: Color {
        switch day.type {
        case .chat:
            return .blue
        case .jsonChat:
            return .purple
        case .lesson:
            return .green
        case .exercise:
            return .orange
        }
    }
}

struct ComingSoonView: View {
    let day: Day

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "hourglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Coming Soon")
                .font(.title)
                .fontWeight(.bold)

            Text(day.title)
                .font(.headline)
                .foregroundColor(.secondary)

            Text("This lesson is under development")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .navigationTitle(day.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    WeekDaySelectionView()
}
