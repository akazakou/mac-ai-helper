// PromptPopupView.swift
// Floating popup showing the prompt list, each prompt labelled with its own model.
// Appears when the user triggers a text or screenshot shortcut.
// The window itself supplies the title bar; PopupPinButton is placed into it.

import SwiftUI

struct PromptPopupView: View {
    @Bindable var viewModel: PromptPopupViewModel
    let appState: AppState

    /// State of the popup window this view is shown in
    let session: PopupSession

    /// Callback to dismiss the popup
    var onDismiss: (() -> Void)?

    /// Callback fired when a prompt starts processing (popup switches to response mode)
    var onResponseStarted: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Content: loading, error, or prompt list
            if session.isLoading {
                loadingView
            } else if session.showingResult {
                ResultView(viewModel: ResultViewModel(session: session)) {
                    onDismiss?()
                }
            } else {
                promptListView
            }
        }
        .frame(minWidth: 320, maxWidth: .infinity, minHeight: 200, maxHeight: .infinity, alignment: .top)
        .task {
            await viewModel.loadModelsIfNeeded()
        }
        .onChange(of: session.isLoading) { _, isLoading in
            if isLoading {
                onResponseStarted?()
            }
        }
    }

    // MARK: - Prompt List

    private var promptListView: some View {
        ScrollView {
            VStack(spacing: 2) {
                // Show what content was captured
                if session.capturedText != nil {
                    HStack {
                        Image(systemName: "doc.text")
                        Text("Text captured from clipboard")
                            .font(.caption)
                        Spacer()
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                } else if session.capturedImage != nil {
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
                if let error = session.lastError {
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

                // Prompt buttons - read directly from appState for reliable observation
                ForEach(appState.settings.prompts) { prompt in
                    PromptButton(
                        prompt: prompt, modelAvailability: viewModel.availability(of: prompt)
                    ) {
                        viewModel.start(prompt)
                    }
                }

                // Empty state
                if appState.settings.prompts.isEmpty {
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

// MARK: - Pin Button

/// Title bar button that keeps the popup open when focus moves elsewhere.
struct PopupPinButton: View {
    let session: PopupSession

    private static let trailingPadding: CGFloat = 10

    var body: some View {
        Button {
            session.isPinned.toggle()
        } label: {
            Image(systemName: session.isPinned ? "pin.fill" : "pin")
                .foregroundStyle(session.isPinned ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
        .help(session.isPinned ? "Unpin window" : "Pin window to keep it open when switching apps")
        // Pin is offered only while waiting for or showing a response.
        // Hidden rather than removed, so the title bar item keeps its size.
        .opacity(session.isResponseVisible ? 1 : 0)
        .disabled(!session.isResponseVisible)
        .padding(.trailing, Self.trailingPadding)
    }
}

// MARK: - Prompt Button

/// A single prompt row in the popup list.
private struct PromptButton: View {
    let prompt: Prompt
    let modelAvailability: ModelAvailability
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: prompt.icon)
                    .frame(width: 20)
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(prompt.title)
                        .font(.body)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    PromptBadgesView(
                        model: prompt.model,
                        availability: modelAvailability,
                        webSearchEnabled: prompt.webSearchEnabled
                    )
                }

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
