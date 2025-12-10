//
//  SystemPromptChatView.swift
//  ai-learning-course
//
//  Created by Claude Code on 08.12.2025.
//

import SwiftUI

struct SystemPromptChatView: View {
    let day: Day

    @StateObject private var viewModel: SystemPromptChatViewModel
    @FocusState private var isInputFocused: Bool
    @State private var showClearConfirmation = false
    @State private var showSystemPromptEditor = false

    init(day: Day) {
        self.day = day
        _viewModel = StateObject(wrappedValue: SystemPromptChatViewModel(dayId: day.id))
    }

    var body: some View {
        VStack(spacing: 0) {
            // System Prompt Display Bar
            SystemPromptBar(
                currentPromptTitle: viewModel.currentPromptTitle,
                onTap: {
                    showSystemPromptEditor = true
                }
            )

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if viewModel.messages.isEmpty {
                            EmptySystemPromptChatView()
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
        .sheet(isPresented: $showSystemPromptEditor) {
            SystemPromptEditorView(viewModel: viewModel)
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

struct SystemPromptBar: View {
    let currentPromptTitle: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)

                VStack(alignment: .leading, spacing: 2) {
                    Text("System Prompt")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(currentPromptTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }

                Spacer()

                Image(systemName: "pencil.circle.fill")
                    .foregroundColor(.purple)
                    .font(.title3)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color.purple.opacity(0.1))
        }
        .buttonStyle(.plain)
    }
}

struct SystemPromptEditorView: View {
    @ObservedObject var viewModel: SystemPromptChatViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedPreset: SystemPromptPreset?
    @State private var customPrompt: String = ""
    @State private var customTitle: String = ""
    @State private var showCustomEditor = false

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(SystemPromptPreset.allPresets) { preset in
                        Button {
                            selectedPreset = preset
                            viewModel.setSystemPrompt(preset.prompt, title: preset.title)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(preset.icon)
                                        .font(.title2)
                                    Text(preset.title)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if viewModel.currentPromptTitle == preset.title {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.purple)
                                    }
                                }
                                Text(preset.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("Preset Prompts")
                }

                Section {
                    Button {
                        showCustomEditor = true
                    } label: {
                        HStack {
                            Image(systemName: "pencil.and.outline")
                            Text("Create Custom Prompt")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Custom")
                }
            }
            .navigationTitle("System Prompts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showCustomEditor) {
                CustomPromptEditorView(viewModel: viewModel, isPresented: $showCustomEditor)
            }
        }
    }
}

struct CustomPromptEditorView: View {
    @ObservedObject var viewModel: SystemPromptChatViewModel
    @Binding var isPresented: Bool
    @State private var customTitle: String = ""
    @State private var customPrompt: String = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Prompt Name", text: $customTitle)
                } header: {
                    Text("Title")
                }

                Section {
                    TextEditor(text: $customPrompt)
                        .frame(minHeight: 200)
                        .font(.system(.body, design: .monospaced))
                } header: {
                    Text("Prompt Content")
                } footer: {
                    Text("Write your custom system prompt here. This will define Claude's behavior and personality.")
                }
            }
            .navigationTitle("Custom Prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        viewModel.setSystemPrompt(customPrompt, title: customTitle.isEmpty ? "Custom Prompt" : customTitle)
                        dismiss()
                        isPresented = false
                    }
                    .disabled(customPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

class SystemPromptChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = [] {
        didSet {
            saveHistory()
        }
    }
    @Published var messageText: String = ""
    @Published var isLoading: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    @Published var currentPromptTitle: String = "Helpful Assistant"

    private var currentSystemPrompt: String = SystemPromptPreset.defaultPrompt.prompt
    private let claudeManager = ClaudeManager.shared
    private let dayId: Int

    private var historyKey: String {
        "systemPromptChatHistory_day_\(dayId)"
    }

    private var promptKey: String {
        "systemPrompt_day_\(dayId)"
    }

    private var promptTitleKey: String {
        "systemPromptTitle_day_\(dayId)"
    }

    init(dayId: Int) {
        self.dayId = dayId
        loadHistory()
        loadSystemPrompt()
    }

    func setSystemPrompt(_ prompt: String, title: String) {
        currentSystemPrompt = prompt
        currentPromptTitle = title
        saveSystemPrompt()
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
                systemPrompt: currentSystemPrompt
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

    private func saveSystemPrompt() {
        UserDefaults.standard.set(currentSystemPrompt, forKey: promptKey)
        UserDefaults.standard.set(currentPromptTitle, forKey: promptTitleKey)
    }

    private func loadSystemPrompt() {
        if let savedPrompt = UserDefaults.standard.string(forKey: promptKey),
           let savedTitle = UserDefaults.standard.string(forKey: promptTitleKey) {
            currentSystemPrompt = savedPrompt
            currentPromptTitle = savedTitle
        } else {
            currentSystemPrompt = SystemPromptPreset.defaultPrompt.prompt
            currentPromptTitle = SystemPromptPreset.defaultPrompt.title
        }
    }
}

struct SystemPromptPreset: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let prompt: String

    static let defaultPrompt = SystemPromptPreset(
        icon: "💬",
        title: "Helpful Assistant",
        description: "Standard helpful AI assistant",
        prompt: "You are a helpful, harmless, and honest AI assistant. Provide clear, accurate, and concise answers."
    )

    static let pirate = SystemPromptPreset(
        icon: "🏴‍☠️",
        title: "Pirate",
        description: "Talk like a pirate captain",
        prompt: "You are a friendly pirate captain. Speak in pirate dialect, use nautical terms, and end sentences with 'arr' or 'matey'. Be enthusiastic and adventurous!"
    )

    static let philosopher = SystemPromptPreset(
        icon: "🤔",
        title: "Philosopher",
        description: "Deep thinker and questioner",
        prompt: "You are a thoughtful philosopher. Respond with deep insights, ask thought-provoking questions, and explore the underlying assumptions in every query. Reference famous philosophical concepts when relevant."
    )

    static let poet = SystemPromptPreset(
        icon: "📜",
        title: "Poet",
        description: "Responds in verse and rhyme",
        prompt: "You are a creative poet. Respond to all questions in poetic form using rhyme, meter, and vivid imagery. Be creative and expressive while still being helpful."
    )

    static let scientist = SystemPromptPreset(
        icon: "🔬",
        title: "Scientist",
        description: "Evidence-based and analytical",
        prompt: "You are a meticulous scientist. Provide evidence-based answers, cite relevant studies when possible, explain the scientific method behind concepts, and acknowledge uncertainty when appropriate."
    )

    static let teacher = SystemPromptPreset(
        icon: "👨‍🏫",
        title: "Patient Teacher",
        description: "Educational and encouraging",
        prompt: "You are a patient and encouraging teacher. Break down complex topics into simple explanations, use analogies and examples, ask questions to check understanding, and provide positive reinforcement."
    )

    static let comedian = SystemPromptPreset(
        icon: "😄",
        title: "Comedian",
        description: "Humorous and witty responses",
        prompt: "You are a witty comedian. Respond with humor, puns, and clever wordplay while still being helpful. Keep it lighthearted and fun, but stay on topic."
    )

    static let minimalist = SystemPromptPreset(
        icon: "⚡",
        title: "Minimalist",
        description: "Brief and to the point",
        prompt: "You are extremely concise. Provide the shortest possible accurate answer. Use bullet points. No fluff. Maximum clarity with minimum words."
    )

    static let allPresets: [SystemPromptPreset] = [
        defaultPrompt,
        pirate,
        philosopher,
        poet,
        scientist,
        teacher,
        comedian,
        minimalist
    ]
}

struct EmptySystemPromptChatView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Dynamic System Prompt Chat")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Change Claude's behavior by selecting different system prompts")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text("Tap the prompt bar above to change behavior")
                .font(.caption)
                .foregroundColor(.purple)
                .padding(.top, 4)
        }
        .padding()
        .frame(maxHeight: .infinity)
    }
}

#Preview {
    NavigationStack {
        SystemPromptChatView(day: Day(
            id: 5,
            weekId: 1,
            title: "Day 5: Dynamic System Prompt",
            description: "Change system prompts during chat",
            type: .systemPromptChat
        ))
    }
}
