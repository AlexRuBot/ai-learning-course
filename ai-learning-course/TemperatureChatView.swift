//
//  TemperatureChatView.swift
//  ai-learning-course
//
//  Created by Claude Code on 08.12.2025.
//

import SwiftUI

struct TemperatureChatView: View {
    let day: Day

    @StateObject private var viewModel: TemperatureChatViewModel
    @FocusState private var isInputFocused: Bool
    @State private var showClearConfirmation = false
    @State private var showTemperatureInfo = false

    init(day: Day) {
        self.day = day
        _viewModel = StateObject(wrappedValue: TemperatureChatViewModel(dayId: day.id))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Temperature Control Bar
            TemperatureControlBar(
                temperature: $viewModel.temperature,
                onInfoTap: {
                    showTemperatureInfo = true
                }
            )

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if viewModel.messages.isEmpty {
                            EmptyTemperatureChatView()
                        } else {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }

                        if viewModel.isLoading {
                            TypingIndicator()
                        }
                    }
                    .padding()
                }
                .onTapGesture {
                    isInputFocused = false
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            MessageInputView(
                messageText: $viewModel.messageText,
                isLoading: viewModel.isLoading,
                isFocused: $isInputFocused,
                onSend: {
                    Task {
                        await viewModel.sendMessage()
                    }
                }
            )
        }
        .navigationTitle(day.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showClearConfirmation = true
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(viewModel.messages.isEmpty)
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert("Clear Chat History", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                viewModel.clearHistory()
            }
        } message: {
            Text("Are you sure you want to clear all messages? This action cannot be undone.")
        }
        .sheet(isPresented: $showTemperatureInfo) {
            TemperatureInfoView()
        }
    }
}

struct TemperatureControlBar: View {
    @Binding var temperature: Double
    let onInfoTap: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "thermometer.medium")
                    .foregroundColor(temperatureColor)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Temperature")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(temperatureLabel)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }

                Spacer()

                Text(String(format: "%.2f", temperature))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(temperatureColor)
                    .monospacedDigit()

                Button(action: onInfoTap) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)

            HStack(spacing: 12) {
                Text("0.0")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 30, alignment: .leading)

                Slider(value: $temperature, in: 0.0...1.0, step: 0.05)
                    .tint(temperatureColor)

                Text("1.0")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 30, alignment: .trailing)
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .background(temperatureColor.opacity(0.1))
    }

    private var temperatureLabel: String {
        if temperature < 0.3 {
            return "Focused"
        } else if temperature < 0.7 {
            return "Balanced"
        } else {
            return "Creative"
        }
    }

    private var temperatureColor: Color {
        if temperature < 0.3 {
            return .blue
        } else if temperature < 0.7 {
            return .green
        } else {
            return .orange
        }
    }
}

struct TemperatureInfoView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    InfoSection(
                        icon: "thermometer.low",
                        color: .blue,
                        title: "Low Temperature (0.0 - 0.3)",
                        description: "More focused and deterministic responses. Best for:",
                        examples: [
                            "Technical explanations",
                            "Code generation",
                            "Factual information",
                            "Mathematical problems"
                        ]
                    )

                    InfoSection(
                        icon: "thermometer.medium",
                        color: .green,
                        title: "Medium Temperature (0.3 - 0.7)",
                        description: "Balanced between creativity and consistency. Good for:",
                        examples: [
                            "General conversation",
                            "Problem solving",
                            "Content writing",
                            "Educational content"
                        ]
                    )

                    InfoSection(
                        icon: "thermometer.high",
                        color: .orange,
                        title: "High Temperature (0.7 - 1.0)",
                        description: "More creative and diverse outputs. Ideal for:",
                        examples: [
                            "Creative writing",
                            "Brainstorming ideas",
                            "Storytelling",
                            "Poetry and art"
                        ]
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                            Text("Tip")
                                .font(.headline)
                        }
                        Text("Try sending the same question with different temperatures to see how responses vary!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("About Temperature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct InfoSection: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    let examples: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
            }

            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(examples, id: \.self) { example in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(color)
                        Text(example)
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

class TemperatureChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = [] {
        didSet {
            saveHistory()
        }
    }
    @Published var messageText: String = ""
    @Published var isLoading: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    @Published var temperature: Double = 0.7 {
        didSet {
            saveTemperature()
        }
    }

    private let claudeManager = ClaudeManager.shared
    private let dayId: Int

    private var historyKey: String {
        "temperatureChatHistory_day_\(dayId)"
    }

    private var temperatureKey: String {
        "temperature_day_\(dayId)"
    }

    init(dayId: Int) {
        self.dayId = dayId
        loadHistory()
        loadTemperature()
    }

    func sendMessage() async {
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: trimmedMessage)

        await MainActor.run {
            messages.append(userMessage)
            messageText = ""
            isLoading = true
        }

        do {
            let result = try await claudeManager.sendMessage(
                messages: messages,
                systemPrompt: nil,
                temperature: temperature
            )

            let assistantMessage = ChatMessage(role: .assistant, content: result.text)

            await MainActor.run {
                messages.append(assistantMessage)
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true

                if let lastIndex = messages.firstIndex(where: { $0.id == userMessage.id }) {
                    messages.remove(at: lastIndex)
                }
            }
        }
    }

    func clearHistory() {
        messages = []
        UserDefaults.standard.removeObject(forKey: historyKey)
    }

    private func saveHistory() {
        guard let encoded = try? JSONEncoder().encode(messages) else { return }
        UserDefaults.standard.set(encoded, forKey: historyKey)
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([ChatMessage].self, from: data) else {
            return
        }
        messages = decoded
    }

    private func saveTemperature() {
        UserDefaults.standard.set(temperature, forKey: temperatureKey)
    }

    private func loadTemperature() {
        if UserDefaults.standard.object(forKey: temperatureKey) != nil {
            temperature = UserDefaults.standard.double(forKey: temperatureKey)
        } else {
            temperature = 0.7
        }
    }
}

struct EmptyTemperatureChatView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "thermometer.variable.and.figure")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Temperature Control Chat")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Adjust the temperature slider to control AI creativity")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                    Text("Low (0.0-0.3): Focused & Precise")
                        .font(.caption)
                }
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Medium (0.3-0.7): Balanced")
                        .font(.caption)
                }
                HStack {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                    Text("High (0.7-1.0): Creative & Diverse")
                        .font(.caption)
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(maxHeight: .infinity)
    }
}

#Preview {
    NavigationStack {
        TemperatureChatView(day: Day(
            id: 6,
            weekId: 2,
            title: "Day 1: Temperature Control",
            description: "Adjust temperature parameter",
            type: .temperatureChat
        ))
    }
}
