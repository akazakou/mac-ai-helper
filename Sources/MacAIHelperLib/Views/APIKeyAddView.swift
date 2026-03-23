// APIKeyAddView.swift
// Sheet dialog for adding a new API key with provider selection and key input.

import SwiftUI

struct APIKeyAddView: View {
    @Bindable var viewModel: SettingsViewModel

    /// Callback to dismiss the sheet
    let onDismiss: () -> Void

    /// Selected provider for the new key
    @State private var selectedProvider: AIProvider = .openAI

    /// The API key entered by the user
    @State private var apiKey = ""

    /// Optional label for the key
    @State private var label = ""

    /// Error message from validation or saving
    @State private var errorMessage: String?

    /// Whether we're currently validating the key
    @State private var isValidating = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Add API Key")
                .font(.headline)

            Form {
                // Provider picker
                Picker("Provider", selection: $selectedProvider) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }

                // API key input
                SecureField("API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)

                // Optional label
                TextField("Label (optional)", text: $label)
                    .textFieldStyle(.roundedBorder)

                // Help link
                HStack {
                    Text("Get your API key:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Link(selectedProvider.rawValue, destination: selectedProvider.helpURL)
                        .font(.caption)
                }
            }

            // Error display
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // Action buttons
            HStack {
                Button("Cancel") {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                if isValidating {
                    ProgressView()
                        .scaleEffect(0.7)
                }

                Button("Add") {
                    addKey()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(apiKey.isEmpty || isValidating)
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }

    // MARK: - Actions

    private func addKey() {
        errorMessage = nil

        do {
            try viewModel.addAPIKey(
                provider: selectedProvider,
                key: apiKey,
                label: label.isEmpty ? selectedProvider.rawValue : label
            )
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
