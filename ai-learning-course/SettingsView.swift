//
//  SettingsView.swift
//  ai-learning-course
//
//  Created by Claude Code on 01.12.2025.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var claudeManager = ClaudeManager.shared
    @State private var apiKeyInput: String = ""
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
}

#Preview {
    SettingsView()
}
