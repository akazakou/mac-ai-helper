// PromptPopupView.swift
// Floating popup showing model selector and prompt list.
// Appears when the user triggers a text or screenshot shortcut.

import SwiftUI

struct PromptPopupView: View {
    @Bindable var viewModel: PromptPopupViewModel
    let appState: AppState

    /// Callback to dismiss the popup
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Header with model selector
            headerView

            Divider()

            // Content: loading, error, or prompt list
            if appState.isLoading {
                loadingView
            } else if appState.showingResult {
                ResultView(viewModel: ResultViewModel(appState: appState)) {
                    onDismiss?()
                }
            } else {
                promptListView
            }
        }
        .frame(minWidth: 320, maxWidth: .infinity, minHeight: 200, maxHeight: .infinity, alignment: .top)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        .task {
            await viewModel.loadModels()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .foregroundStyle(Color.accentColor)

            Text("Mac AI Helper")
                .font(.headline)

            Spacer()

            // Model selector
            if viewModel.isLoadingModels {
                ProgressView()
                    .scaleEffect(0.7)
            } else if !viewModel.availableModels.isEmpty {
                Picker("Model", selection: Binding(
                    get: { viewModel.selectedModelId ?? "" },
                    set: { viewModel.selectedModelId = $0.isEmpty ? nil : $0 }
                )) {
                    ForEach(viewModel.availableModels) { model in
                        Text(model.name)
                            .tag(model.id)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 180)
            } else {
                Text("No models")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Close button
            Button {
                onDismiss?()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
    }

    // MARK: - Prompt List

    private var promptListView: some View {
        ScrollView {
            VStack(spacing: 2) {
                // Show what content was captured
                if appState.capturedText != nil {
                    HStack {
                        Image(systemName: "doc.text")
                        Text("Text captured from clipboard")
                            .font(.caption)
                        Spacer()
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                } else if appState.capturedImage != nil {
                    HStack {
                        Image(systemName: "photo")
                        Text("Screenshot captured")
                            .font(.caption)
                        Spacer()
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }

                // Error display
                if let error = appState.lastError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                        Text(error)
                            .font(.caption)
                        Spacer()
                    }
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                }

                // Prompt buttons
                ForEach(viewModel.prompts) { prompt in
                    PromptButton(prompt: prompt) {
                        Task {
                            if let imageData = appState.capturedImage {
                                await viewModel.selectPromptWithImage(
                                    prompt, imageData: imageData
                                )
                            } else {
                                await viewModel.selectPrompt(prompt)
                            }
                        }
                    }
                }

                // Empty state
                if viewModel.prompts.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "text.bubble")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No prompts configured")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Text("Add prompts in Settings")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Processing…")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 150, maxHeight: .infinity)
    }
}

// MARK: - Prompt Button

/// A single prompt row in the popup list.
private struct PromptButton: View {
    let prompt: Prompt
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: prompt.icon)
                    .frame(width: 20)
                    .foregroundStyle(Color.accentColor)

                Text(prompt.title)
                    .font(.body)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
