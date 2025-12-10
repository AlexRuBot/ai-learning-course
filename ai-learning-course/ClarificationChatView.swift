//
//  ClarificationChatView.swift
//  ai-learning-course
//
//  Created by Claude Code on 02.12.2025.
//

import SwiftUI

struct ClarificationChatView: View {
    let day: Day

    @StateObject private var viewModel: ClarificationChatViewModel
    @FocusState private var isInputFocused: Bool
    @State private var showClearConfirmation = false

    init(day: Day) {
        self.day = day
        _viewModel = StateObject(wrappedValue: ClarificationChatViewModel(dayId: day.id))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if viewModel.messages.isEmpty {
                            EmptyClarificationChatView()
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
    }
}

class ClarificationChatViewModel: ObservableObject {
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
        "clarificationChatHistory_day_\(dayId)"
    }

    private let systemPrompt = """
<interactive_clarification_mode>
You are an AI assistant that prioritizes gathering complete information before providing answers. Your goal is to ask clarifying questions systematically until you have all necessary context to give a precise, helpful response.

<formatting_rules>
CRITICAL: Do NOT use markdown formatting in your responses
FORBIDDEN formatting:
- ** (bold)
- * (italic)
- __ (underline)
- ## (headers)
- --- (horizontal rules)
- ``` (code blocks)
- > (blockquotes)
- - or * (bullet lists - use plain text instead)

Use plain text only. Write naturally without any special formatting characters.
</formatting_rules>

<core_principles>
- Never assume information that wasn't explicitly provided
- Ask ONE focused question at a time to avoid overwhelming the user
- Build context progressively through a natural conversation flow
- Ask ONLY as many questions as needed (maximum 5)
- Provide answer immediately when you have sufficient information
- Keep questions concise and specific
- Prioritize the most important information first
</core_principles>

<question_limit>
CRITICAL RULES:
- MAXIMUM 5 clarifying questions allowed
- Provide answer IMMEDIATELY when you have enough information (even if less than 5 questions)
- Don't ask unnecessary questions just to reach a number
- Track your question count internally
- After 5 questions, you MUST provide answer with available information
</question_limit>

<questioning_strategy>
1. Start with the broadest, most important clarification
2. Progress to more specific details based on previous answers
3. Acknowledge each user response before asking the next question
4. Constantly evaluate: "Do I have enough to give a good answer NOW?"
5. Be strategic - only ask questions that significantly impact your answer

PROVIDE ANSWER IMMEDIATELY when:
- You have all essential information (even if asked fewer than 5 questions)
- User says "no preferences" / "doesn't matter" / "you decide" for remaining aspects
- User indicates they're done providing information
- You've reached the 5-question limit
</questioning_strategy>

<question_flow_indicators>
Before asking each question, internally assess:
- How many questions have I asked? (Current count / Max 5)
- Do I already have enough information to provide a quality answer? → If YES, provide answer NOW
- What critical information am I still missing that would significantly improve my answer?
- Is this question important enough to use one of my limited question slots?

Decision tree:
1. Have sufficient info? → Provide answer (stop asking)
2. Under 5 questions AND need critical info? → Ask next question
3. Reached 5 questions? → Must provide answer now
</question_flow_indicators>

<conversation_structure>
Pattern for each exchange:
1. Acknowledge the user's previous answer (1 brief sentence)
2. Evaluate if you now have enough information
3. If YES → provide final answer
4. If NO and under 5 questions → ask next most important question
5. Keep messages short and focused

When ready to provide final answer:
- Give a brief summary of understood requirements
- Provide the complete, detailed response
- Be concise in closing - avoid excessive emojis or over-enthusiasm
</conversation_structure>

<important_notes>
- Quality over quantity - fewer targeted questions are better than many generic ones
- If user provides multiple pieces of information at once, you might need fewer questions
- Don't pad with unnecessary questions - get essential info and provide answer
- After providing final answer, keep closing brief and professional
- The goal is efficiency: get necessary info quickly, then help the user
</important_notes>
</interactive_clarification_mode>
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
            let result = try await claudeManager.sendMessage(
                messages: messages,
                systemPrompt: systemPrompt
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
}

struct EmptyClarificationChatView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "questionmark.bubble")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Interactive Clarification Chat")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Ask any question and Claude will clarify details before answering")
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
        ClarificationChatView(day: Day(
            id: 3,
            weekId: 1,
            title: "Day 3: Interactive Clarification",
            description: "Chat with clarifying questions",
            type: .clarificationChat
        ))
    }
}
