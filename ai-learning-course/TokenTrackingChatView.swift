//
//  TokenTrackingChatView.swift
//  ai-learning-course
//
//  Created by Claude Code on 10.12.2025.
//

import SwiftUI

struct TokenTrackingChatView: View {
    let day: Day

    @StateObject private var viewModel: TokenTrackingChatViewModel
    @FocusState private var isInputFocused: Bool
    @State private var showClearConfirmation = false

    init(day: Day) {
        self.day = day
        _viewModel = StateObject(wrappedValue: TokenTrackingChatViewModel(dayId: day.id))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Token Stats Header
            TokenStatsHeader(viewModel: viewModel)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if viewModel.messages.isEmpty {
                            EmptyTokenTrackingView()
                        } else {
                            ForEach(viewModel.messages) { message in
                                TokenMessageBubble(message: message)
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
    }
}

struct TokenStatsHeader: View {
    @ObservedObject var viewModel: TokenTrackingChatViewModel
    @ObservedObject var claudeManager = ClaudeManager.shared

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 20) {
                TokenStat(
                    icon: "arrow.down.circle.fill",
                    label: "Input",
                    value: viewModel.totalInputTokens,
                    color: .blue
                )

                TokenStat(
                    icon: "arrow.up.circle.fill",
                    label: "Output",
                    value: viewModel.totalOutputTokens,
                    color: .green
                )

                TokenStat(
                    icon: "sum",
                    label: "Total",
                    value: viewModel.totalTokens,
                    color: .purple
                )
            }

            HStack(spacing: 16) {
                Label("Max: \(claudeManager.maxTokens)", systemImage: "chart.bar.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("•")
                    .foregroundColor(.secondary)

                Text("Estimated: $\(viewModel.estimatedCost, specifier: "%.4f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}

struct TokenStat: View {
    let icon: String
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text("\(value)")
                .font(.headline)
                .fontWeight(.bold)
                .monospaced()

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

class TokenTrackingChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = [] {
        didSet {
            saveHistory()
            updateTokenStats()
        }
    }
    @Published var messageText: String = ""
    @Published var isLoading: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    @Published var totalInputTokens: Int = 0
    @Published var totalOutputTokens: Int = 0

    private let claudeManager = ClaudeManager.shared
    private let dayId: Int
    private var historyKey: String {
        "tokenTrackingHistory_day_\(dayId)"
    }

    // Claude Sonnet pricing (per 1M tokens)
    private let inputPricePerMillion: Double = 3.0  // $3 per 1M input tokens
    private let outputPricePerMillion: Double = 15.0 // $15 per 1M output tokens

    var totalTokens: Int {
        totalInputTokens + totalOutputTokens
    }

    var estimatedCost: Double {
        let inputCost = (Double(totalInputTokens) / 1_000_000.0) * inputPricePerMillion
        let outputCost = (Double(totalOutputTokens) / 1_000_000.0) * outputPricePerMillion
        return inputCost + outputCost
    }

    init(dayId: Int) {
        self.dayId = dayId
        loadHistory()
        updateTokenStats()
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
                messages: messages
            )

            let assistantMessage = ChatMessage(
                role: .assistant,
                content: result.text,
                tokenUsage: result.tokenUsage
            )

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
        updateTokenStats()
    }

    private func updateTokenStats() {
        var inputTotal = 0
        var outputTotal = 0

        for message in messages {
            if let usage = message.tokenUsage {
                inputTotal += usage.inputTokens
                outputTotal += usage.outputTokens
            }
        }

        totalInputTokens = inputTotal
        totalOutputTokens = outputTotal
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
}

struct TokenMessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background(bubbleColor)
                    .foregroundColor(textColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                HStack(spacing: 8) {
                    Text(formatTimestamp(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if let tokenUsage = message.tokenUsage {
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        HStack(spacing: 4) {
                            Text("↓\(tokenUsage.inputTokens)")
                                .foregroundColor(.blue)
                            Text("↑\(tokenUsage.outputTokens)")
                                .foregroundColor(.green)
                            Text("Σ\(tokenUsage.totalTokens)")
                                .foregroundColor(.purple)
                        }
                        .font(.caption2)
                        .fontWeight(.medium)
                        .monospaced()
                    }
                }
            }

            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
    }

    private var bubbleColor: Color {
        message.role == .user ? .blue : Color(.systemGray5)
    }

    private var textColor: Color {
        message.role == .user ? .white : .primary
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct EmptyTokenTrackingView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Token Usage Tracking")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Start chatting to monitor your API token usage in real-time")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .frame(maxHeight: .infinity)
    }
}

#Preview {
    NavigationStack {
        TokenTrackingChatView(day: Day(
            id: 8,
            weekId: 2,
            title: "Day 3: Token Usage Tracking",
            description: "Monitor token usage",
            type: .tokenTrackingChat
        ))
    }
}
