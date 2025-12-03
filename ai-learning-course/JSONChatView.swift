//
//  JSONChatView.swift
//  ai-learning-course
//
//  Created by Claude Code on 02.12.2025.
//

import SwiftUI

struct JSONChatView: View {
    let day: Day

    @StateObject private var viewModel: JSONChatViewModel
    @FocusState private var isInputFocused: Bool
    @State private var showClearConfirmation = false

    init(day: Day) {
        self.day = day
        _viewModel = StateObject(wrappedValue: JSONChatViewModel(dayId: day.id))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if viewModel.messages.isEmpty {
                            EmptyJSONChatView()
                        } else {
                            ForEach(viewModel.messages) { message in
                                JSONMessageBubble(message: message)
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

class JSONChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = [] {
        didSet {
            saveHistory()
        }
    }
    @Published var messageText: String = ""
    @Published var isLoading: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""

    private let claudeManager = ClaudeManager.shared
    private let dayId: Int
    private var historyKey: String {
        "jsonChatHistory_day_\(dayId)"
    }

    private let jsonSystemPrompt = """
CRITICAL INSTRUCTION: You MUST respond with ONLY raw JSON. NO markdown code blocks.

FORBIDDEN - Never use these:
- ```json
- ```
- Any backticks or code fences

REQUIRED FORMAT:
Your response must start with { or [ immediately
Your response must end with } or ] immediately
No text before or after the JSON
All JSON keys MUST be in English only (no Russian, no other languages)

CORRECT example:
{"response": "This is my answer", "timestamp": "2025-12-02"}

WRONG example (NEVER DO THIS):
```json
{"ответ": "This is my answer"}
```

Your ENTIRE response = valid JSON object or array with English keys only. Nothing else.
"""

    init(dayId: Int) {
        self.dayId = dayId
        loadHistory()
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
            let response = try await claudeManager.sendMessage(
                messages: messages,
                systemPrompt: jsonSystemPrompt
            )

            let assistantMessage = ChatMessage(role: .assistant, content: response)

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
}

struct JSONMessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if message.role == .assistant {
                    // Pretty print JSON for assistant messages
                    Text(prettyPrintedJSON(message.content))
                        .font(.system(.caption, design: .monospaced))
                        .padding(12)
                        .background(bubbleColor)
                        .foregroundColor(textColor)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .textSelection(.enabled)
                } else {
                    // Regular display for user messages
                    Text(message.content)
                        .font(.body)
                        .padding(12)
                        .background(bubbleColor)
                        .foregroundColor(textColor)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Text(formatTimestamp(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
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

    private func prettyPrintedJSON(_ jsonString: String) -> String {
        // Try to parse and pretty print JSON
        guard let data = jsonString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            // If parsing fails, return original string
            return jsonString
        }
        return prettyString
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct EmptyJSONChatView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "curlybraces")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("JSON Chat")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Ask Claude anything and receive JSON responses")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxHeight: .infinity)
    }
}

#Preview {
    NavigationStack {
        JSONChatView(day: Day(
            id: 2,
            weekId: 1,
            title: "Day 2: JSON Chat",
            description: "Chat with Claude in JSON format",
            type: .chat
        ))
    }
}
