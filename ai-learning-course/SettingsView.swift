//
//  SettingsView.swift
//  ai-learning-course
//
//  Created by Claude Code on 01.12.2025.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var claudeManager = ClaudeManager.shared
    @ObservedObject var hfManager = HuggingFaceManager.shared
    @State private var apiKeyInput: String = ""
    @State private var hfApiKeyInput: String = ""
    @State private var maxTokensInput: String = ""
    @State private var showSaveConfirmation = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section {
                    SecureField("Enter your API key", text: $apiKeyInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button(action: saveAPIKey) {
                        HStack {
                            Spacer()
                            Text("Save API Key")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKeyInput.isEmpty)

                    if claudeManager.isAPIKeySet {
                        Label("API key is set", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                } header: {
                    Text("Claude API Configuration")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("To use this app, you need an Anthropic API key.")
                        Text("Get your API key at: console.anthropic.com")
                            .font(.caption)
                    }
                }

                Section {
                    SecureField("Enter HuggingFace API key", text: $hfApiKeyInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button(action: saveHFAPIKey) {
                        HStack {
                            Spacer()
                            Text("Save HuggingFace Key")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(hfApiKeyInput.isEmpty)

                    if hfManager.isAPIKeySet {
                        Label("HuggingFace key is set", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                } header: {
                    Text("HuggingFace API Configuration")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Required for AI model comparison feature.")
                        Text("Get your API key at: huggingface.co/settings/tokens")
                            .font(.caption)
                    }
                }

                Section {
                    HStack {
                        TextField("Max tokens (e.g., 4096)", text: $maxTokensInput)
                            .keyboardType(.numberPad)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        Button("Save") {
                            saveMaxTokens()
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.blue)
                        .disabled(maxTokensInput.isEmpty || Int(maxTokensInput) == nil)
                    }

                    Text("Current: \(claudeManager.maxTokens) tokens")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Token Limit")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Maximum number of tokens for API responses.")
                        Text("Recommended: 1024-8192. Default: 4096")
                            .font(.caption)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "info.circle")
                            Text("About")
                                .fontWeight(.semibold)
                        }
                        Text("This is an AI learning course application powered by Claude Sonnet 4.5.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Information")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                apiKeyInput = claudeManager.apiKey
                hfApiKeyInput = hfManager.apiKey
                maxTokensInput = String(claudeManager.maxTokens)
            }
            .alert("Success", isPresented: $showSaveConfirmation) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("API key has been saved successfully")
            }
        }
    }

    private func saveAPIKey() {
        claudeManager.apiKey = apiKeyInput
        showSaveConfirmation = true
    }

    private func saveHFAPIKey() {
        hfManager.apiKey = hfApiKeyInput
        showSaveConfirmation = true
    }

    private func saveMaxTokens() {
        if let tokens = Int(maxTokensInput), tokens > 0 {
            claudeManager.maxTokens = tokens
            showSaveConfirmation = true
        }
    }
}

#Preview {
    SettingsView()
}
