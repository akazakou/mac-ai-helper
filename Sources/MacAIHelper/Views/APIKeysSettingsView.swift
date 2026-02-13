// APIKeysSettingsView.swift
// Settings tab for managing API keys for different AI providers.

import SwiftUI

struct APIKeysSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    /// Controls the add-key sheet presentation
    @State private var showingAddSheet = false

    /// Error message to display
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("API Keys")
                .font(.headline)

            Text("Add API keys for the AI providers you want to use. Keys are stored securely in the macOS Keychain.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Key list
            List {
                if viewModel.settings.apiKeyEntries.isEmpty {
                    Text("No API keys configured. Add one to get started.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(viewModel.settings.apiKeyEntries) { entry in
                        HStack(spacing: 12) {
                            Image(systemName: providerIcon(for: entry.provider))
                                .frame(width: 20)
                                .foregroundStyle(Color.accentColor)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.label)
                                    .font(.body)
                                Text(entry.provider.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            // Link to provider's API key page
                            Link(destination: entry.provider.helpURL) {
                                Image(systemName: "arrow.up.right.square")
                            }
                            .buttonStyle(.borderless)

                            // Delete button
                            Button(role: .destructive) {
                                deleteKey(entry)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.bordered)

            // Add button and error display
            HStack {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add API Key", systemImage: "plus")
                }

                Spacer()

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding()
        .sheet(isPresented: $showingAddSheet) {
            APIKeyAddView(viewModel: viewModel) {
                showingAddSheet = false
            }
        }
    }

    // MARK: - Helpers

    private func providerIcon(for provider: AIProvider) -> String {
        switch provider {
        case .openAI: "brain"
        case .anthropic: "sparkle"
        case .gemini: "diamond"
        }
    }

    private func deleteKey(_ entry: APIKeyEntry) {
        viewModel.deleteAPIKey(entry)
        errorMessage = nil
    }
}
