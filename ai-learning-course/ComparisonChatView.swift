//
//  ComparisonChatView.swift
//  ai-learning-course
//
//  Created by Claude Code on 09.12.2025.
//

import SwiftUI

struct ComparisonChatView: View {
    let day: Day

    @StateObject private var viewModel = ComparisonChatViewModel()
    @StateObject private var claudeManager = ClaudeManager.shared
    @StateObject private var hfManager = HuggingFaceManager.shared
    @FocusState private var isInputFocused: Bool
    @State private var showClearConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if viewModel.comparisonResults.isEmpty {
                            EmptyComparisonView()
                        } else {
                            ForEach(Array(viewModel.comparisonResults.enumerated()), id: \.offset) { index, result in
                                ComparisonResultCard(result: result)
                                    .id(index)
                            }
                        }

                        if viewModel.isLoading {
                            LoadingComparisonView()
                        }
                    }
                    .padding()
                }
                .onTapGesture {
                    isInputFocused = false
                }
                .onChange(of: viewModel.comparisonResults.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo(viewModel.comparisonResults.count - 1, anchor: .bottom)
                    }
                }
            }

            Divider()

            ComparisonInputView(
                queryText: $viewModel.queryText,
                isLoading: viewModel.isLoading,
                isFocused: $isInputFocused,
                onSend: {
                    Task {
                        await viewModel.sendQuery()
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
                    Image(systemName: "trash")
                }
                .disabled(viewModel.comparisonResults.isEmpty)
            }
        }
        .alert("Clear All Results", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                viewModel.clearResults()
            }
        } message: {
            Text("Are you sure you want to clear all comparison results?")
        }
    }
}

// MARK: - Empty State View

struct EmptyComparisonView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))

            VStack(spacing: 8) {
                Text("AI Model Comparison")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Send a query to compare responses from 3 different AI models")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 6) {
                    Label("Llama 3.2 3B Instruct", systemImage: "1.circle.fill")
                    Label("Qwen 2.5 7B Instruct", systemImage: "2.circle.fill")
                    Label("Gemma 3 27B", systemImage: "3.circle.fill")
                }
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.top, 8)

                Text("Claude will analyze and compare the results")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Loading View

struct LoadingComparisonView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Querying models and analyzing responses...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Comparison Result Card

struct ComparisonResultCard: View {
    let result: ComparisonResult

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Query Header
            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(.blue)
                Text("Your Query")
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }

            Text(result.query)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)

            // Model Responses
            ForEach(result.responses) { response in
                ModelResponseCard(response: response)
            }

            // Claude's Analysis
            if let analysis = result.claudeAnalysis {
                ClaudeAnalysisCard(analysis: analysis)
            } else if result.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Claude is analyzing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Model Response Card

struct ModelResponseCard: View {
    let response: ModelResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cpu")
                    .foregroundColor(.purple)
                Text(response.modelName)
                    .fontWeight(.semibold)
                    .foregroundColor(.purple)
                Spacer()
            }

            if let error = response.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.vertical, 8)
            } else {
                Text(response.response)
                    .font(.body)
                    .padding(.vertical, 4)

                Divider()

                HStack(spacing: 16) {
                    Label("\(Int(response.responseTime * 1000))ms", systemImage: "clock")
                    Label("\(response.inputTokens)", systemImage: "arrow.down.circle")
                    Label("\(response.outputTokens)", systemImage: "arrow.up.circle")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Claude Analysis Card

struct ClaudeAnalysisCard: View {
    let analysis: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.orange)
                Text("Claude's Analysis")
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
            }

            Text(analysis)
                .font(.body)
                .padding(.vertical, 4)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Input View

struct ComparisonInputView: View {
    @Binding var queryText: String
    let isLoading: Bool
    var isFocused: FocusState<Bool>.Binding
    let onSend: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Enter your query...", text: $queryText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(20)
                .lineLimit(1...5)
                .focused(isFocused)
                .disabled(isLoading)

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(canSend ? .blue : .gray)
            }
            .disabled(!canSend)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var canSend: Bool {
        !queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }
}

// MARK: - ViewModel

@MainActor
class ComparisonChatViewModel: ObservableObject {
    @Published var queryText = ""
    @Published var comparisonResults: [ComparisonResult] = []
    @Published var isLoading = false

    private let claudeManager = ClaudeManager.shared
    private let hfManager = HuggingFaceManager.shared

    func sendQuery() async {
        let query = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        queryText = ""
        isLoading = true

        // Create initial result
        var result = ComparisonResult(
            query: query,
            responses: [],
            claudeAnalysis: nil,
            isLoading: true
        )
        comparisonResults.append(result)
        let resultIndex = comparisonResults.count - 1

        // Step 1: Query HuggingFace models
        let responses = await hfManager.queryAllModels(prompt: query)
        comparisonResults[resultIndex] = ComparisonResult(
            query: query,
            responses: responses,
            claudeAnalysis: nil,
            isLoading: true
        )

        // Step 2: Send to Claude for analysis
        let analysis = await getClaudeAnalysis(query: query, responses: responses)
        comparisonResults[resultIndex] = ComparisonResult(
            query: query,
            responses: responses,
            claudeAnalysis: analysis,
            isLoading: false
        )

        isLoading = false
    }

    private func getClaudeAnalysis(query: String, responses: [ModelResponse]) async -> String? {
        guard claudeManager.isAPIKeySet else {
            return "Claude API key not set. Please configure it in Settings."
        }

        var prompt = "Analyze these 3 AI responses to the query: \"\(query)\"\n\n"

        for (index, response) in responses.enumerated() {
            prompt += "Model \(index + 1) (\(response.modelName)):\n"
            if let error = response.error {
                prompt += "Error: \(error)\n"
            } else {
                prompt += "Response: \(response.response)\n"
                prompt += "Time: \(Int(response.responseTime * 1000))ms\n"
                prompt += "Tokens: \(response.inputTokens) in / \(response.outputTokens) out\n"
            }
            prompt += "\n"
        }

        prompt += """
        Provide a brief comparison (2-3 sentences) covering:
        - Quality of responses
        - Speed/efficiency
        - Best model for this query type
        """

        do {
            let message = ChatMessage(role: .user, content: prompt)
            let response = try await claudeManager.sendMessage(messages: [message])
            return response
        } catch {
            return "Error analyzing responses: \(error.localizedDescription)"
        }
    }

    func clearResults() {
        comparisonResults.removeAll()
    }
}

#Preview {
    NavigationView {
        ComparisonChatView(day: Day(
            id: 7,
            weekId: 2,
            title: "Day 2: AI Model Comparison",
            description: "Compare responses from multiple AI models",
            type: .comparisonChat
        ))
    }
}
