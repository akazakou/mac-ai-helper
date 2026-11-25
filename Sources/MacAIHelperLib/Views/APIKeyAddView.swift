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

    /// Optional Google Cloud project ID that turns on the Translation LLM (Google Translate only)
    @State private var projectId = ""

    /// Google Cloud project ID (6-30 lowercase letters, digits and hyphens) or project number
    private static let projectIdPattern = /[a-z][a-z0-9-]{4,28}[a-z0-9]|[0-9]+/

    private var trimmedProjectId: String {
        projectId.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isProjectIdValid: Bool {
        trimmedProjectId.isEmpty || trimmedProjectId.wholeMatch(of: Self.projectIdPattern) != nil
    }

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
                    ForEach(AIProvider.allCases.filter(\.requiresAPIKey)) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }

                // API key input
                SecureField("API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)

                // Optional label
                TextField("Label (optional)", text: $label)
                    .textFieldStyle(.roundedBorder)

                if selectedProvider == .googleTranslate {
                    projectIdField
                }

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
                .disabled(apiKey.isEmpty || !isProjectIdValid || isValidating)
            }
        }
        .padding()
        .frame(width: 400, height: selectedProvider == .googleTranslate ? 400 : 300)
    }

    private var projectIdField: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Google Cloud project ID (optional)", text: $projectId)
                .textFieldStyle(.roundedBorder)
            Text(
                isProjectIdValid
                    ? "Turns on Google's Translation LLM: more accurate than the standard model, "
                        + "$10 per million characters in and $10 out. Leave empty for the standard model."
                    : "A project ID has 6-30 lowercase letters, digits or hyphens, like my-project-123."
            )
            .font(.caption)
            .foregroundStyle(isProjectIdValid ? Color.secondary : Color.red)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Actions

    private func addKey() {
        errorMessage = nil
        var entry = APIKeyEntry(
            provider: selectedProvider, label: label.isEmpty ? selectedProvider.rawValue : label
        )
        if selectedProvider == .googleTranslate, !trimmedProjectId.isEmpty {
            entry.projectId = trimmedProjectId
        }

        Task {
            isValidating = true
            defer { isValidating = false }
            do {
                try await viewModel.addAPIKey(entry, key: apiKey)
                onDismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
