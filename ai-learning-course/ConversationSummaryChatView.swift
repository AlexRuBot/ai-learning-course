//
//  ConversationSummaryChatView.swift
//  ai-learning-course
//
//  Created by Claude Code on 10.12.2025.
//

import SwiftUI

struct ConversationSummaryChatView: View {
    let day: Day

    @StateObject private var viewModel: ConversationSummaryChatViewModel
    @FocusState private var isInputFocused: Bool
    @State private var showClearConfirmation = false

    init(day: Day) {
        self.day = day
        _viewModel = StateObject(wrappedValue: ConversationSummaryChatViewModel(dayId: day.id))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Summary Info Header
            SummaryInfoHeader(viewModel: viewModel)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if viewModel.displayMessages.isEmpty {
                            EmptyConversationSummaryView()
                        } else {
                            ForEach(viewModel.displayMessages) { message in
                                SummaryMessageBubble(message: message)
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
                .onChange(of: viewModel.displayMessages.count) { _, _ in
                    if let lastMessage = viewModel.displayMessages.last {
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
                .disabled(viewModel.displayMessages.isEmpty)
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

struct SummaryInfoHeader: View {
    @ObservedObject var viewModel: ConversationSummaryChatViewModel

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                InfoBadge(
                    icon: "text.bubble.fill",
                    label: "Messages",
                    value: "\(viewModel.totalMessageCount)",
                    color: .blue
                )

                InfoBadge(
                    icon: "doc.text.fill",
                    label: "Summaries",
                    value: "\(viewModel.summaryCount)",
                    color: .green
                )

                InfoBadge(
                    icon: "arrow.down.circle.fill",
                    label: "Compressed",
                    value: "\(viewModel.compressedMessageCount)",
                    color: .orange
                )
            }

            if viewModel.isCreatingSummary {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Creating summary...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}

struct InfoBadge: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)

            Text(value)
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

struct ConversationSummaryMessage: Identifiable, Codable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    let isSummary: Bool
    let tokenUsage: TokenUsage?

    init(id: UUID = UUID(), role: MessageRole, content: String, timestamp: Date = Date(), isSummary: Bool = false, tokenUsage: TokenUsage? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isSummary = isSummary
        self.tokenUsage = tokenUsage
    }
}

class ConversationSummaryChatViewModel: ObservableObject {
    @Published var displayMessages: [ConversationSummaryMessage] = [] {
        didSet {
            saveHistory()
        }
    }
    @Published var messageText: String = ""
    @Published var isLoading: Bool = false
    @Published var isCreatingSummary: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    @Published var totalMessageCount: Int = 0
    @Published var summaryCount: Int = 0
    @Published var compressedMessageCount: Int = 0

    private let claudeManager = ClaudeManager.shared
    private let dayId: Int
    private let summaryThreshold = 10
    private var historyKey: String {
        "conversationSummaryHistory_day_\(dayId)"
    }
    private var statsKey: String {
        "conversationSummaryStats_day_\(dayId)"
    }

    init(dayId: Int) {
        self.dayId = dayId
        loadHistory()
    }

    func sendMessage() async {
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }

        let userMessage = ConversationSummaryMessage(role: .user, content: trimmedMessage)

        await MainActor.run {
            displayMessages.append(userMessage)
            messageText = ""
            isLoading = true
            totalMessageCount += 1
        }

        do {
            // Convert display messages to ChatMessage for API
            let apiMessages = displayMessages.map { msg in
                ChatMessage(role: msg.role, content: msg.content)
            }

            let result = try await claudeManager.sendMessage(messages: apiMessages)

            let assistantMessage = ConversationSummaryMessage(
                role: .assistant,
                content: result.text,
                tokenUsage: result.tokenUsage
            )

            await MainActor.run {
                displayMessages.append(assistantMessage)
                totalMessageCount += 1
                isLoading = false
            }

            // Check if we need to compress
            await checkAndCompressHistory()

        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true

                if let lastIndex = displayMessages.firstIndex(where: { $0.id == userMessage.id }) {
                    displayMessages.remove(at: lastIndex)
                }
                totalMessageCount -= 1
            }
        }
    }

    private func checkAndCompressHistory() async {
        // Count non-summary messages
        let nonSummaryMessages = displayMessages.filter { !$0.isSummary }

        guard nonSummaryMessages.count >= summaryThreshold else { return }

        await MainActor.run {
            isCreatingSummary = true
        }

        // Find the index where to split (keep last few messages uncompressed)
        let messagesToCompress = Array(nonSummaryMessages.prefix(summaryThreshold))

        // Create summary prompt
        let conversationText = messagesToCompress.map { msg in
            "\(msg.role == .user ? "User" : "Assistant"): \(msg.content)"
        }.joined(separator: "\n")

        let summaryPrompt = """
        Please create a concise summary of the following conversation in 2-3 sentences. \
        Capture the key topics and important points discussed:

        \(conversationText)

        Provide only the summary, nothing else.
        """

        do {
            let result = try await claudeManager.sendMessage(
                messageText: summaryPrompt
            )

            await MainActor.run {
                // Remove the compressed messages
                let idsToRemove = Set(messagesToCompress.map { $0.id })
                displayMessages.removeAll { idsToRemove.contains($0.id) }

                // Insert summary at the beginning
                let summaryMessage = ConversationSummaryMessage(
                    role: .assistant,
                    content: "📝 Summary of previous conversation:\n\n\(result.text)",
                    timestamp: messagesToCompress.first?.timestamp ?? Date(),
                    isSummary: true,
                    tokenUsage: result.tokenUsage
                )

                displayMessages.insert(summaryMessage, at: 0)

                summaryCount += 1
                compressedMessageCount += messagesToCompress.count
                isCreatingSummary = false

                saveStats()
            }
        } catch {
            await MainActor.run {
                isCreatingSummary = false
                print("Failed to create summary: \(error.localizedDescription)")
            }
        }
    }

    func clearHistory() {
        displayMessages = []
        totalMessageCount = 0
        summaryCount = 0
        compressedMessageCount = 0
        UserDefaults.standard.removeObject(forKey: historyKey)
        UserDefaults.standard.removeObject(forKey: statsKey)
    }

    private func saveHistory() {
        guard let encoded = try? JSONEncoder().encode(displayMessages) else { return }
        UserDefaults.standard.set(encoded, forKey: historyKey)
        saveStats()
    }

    private func saveStats() {
        let stats: [String: Int] = [
            "totalMessageCount": totalMessageCount,
            "summaryCount": summaryCount,
            "compressedMessageCount": compressedMessageCount
        ]
        UserDefaults.standard.set(stats, forKey: statsKey)
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([ConversationSummaryMessage].self, from: data) else {
            return
        }
        displayMessages = decoded

        // Load stats
        if let stats = UserDefaults.standard.dictionary(forKey: statsKey) as? [String: Int] {
            totalMessageCount = stats["totalMessageCount"] ?? 0
            summaryCount = stats["summaryCount"] ?? 0
            compressedMessageCount = stats["compressedMessageCount"] ?? 0
        }
    }
}

struct SummaryMessageBubble: View {
    let message: ConversationSummaryMessage

    var body: some View {
        HStack {
            if message.role == .user && !message.isSummary {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user && !message.isSummary ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background(bubbleColor)
                    .foregroundColor(textColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        message.isSummary ?
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.green, lineWidth: 2)
                        : nil
                    )

                HStack(spacing: 8) {
                    Text(formatTimestamp(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if let tokenUsage = message.tokenUsage {
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("↓\(tokenUsage.inputTokens) ↑\(tokenUsage.outputTokens)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .monospaced()
                    }

                    if message.isSummary {
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("Summary")
                            .font(.caption2)
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                    }
                }
            }

            if (message.role == .assistant && !message.isSummary) || message.isSummary {
                Spacer(minLength: 60)
            }
        }
    }

    private var bubbleColor: Color {
        if message.isSummary {
            return Color.green.opacity(0.1)
        }
        return message.role == .user ? .blue : Color(.systemGray5)
    }

    private var textColor: Color {
        if message.isSummary {
            return .primary
        }
        return message.role == .user ? .white : .primary
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct EmptyConversationSummaryView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Conversation Summary Chat")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Messages are automatically summarized every 10 messages to save context")
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
        ConversationSummaryChatView(day: Day(
            id: 9,
            weekId: 2,
            title: "Day 4: Conversation Summary",
            description: "Auto-compress long conversations",
            type: .conversationSummaryChat
        ))
    }
}
