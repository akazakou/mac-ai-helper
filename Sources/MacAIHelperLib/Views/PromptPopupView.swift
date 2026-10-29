// PromptPopupView.swift
// Floating popup showing the prompt list, each prompt labelled with its own model.
// Appears when the user triggers a text or screenshot shortcut.

import AppKit
import SwiftUI

struct PromptPopupView: View {
    @Bindable var viewModel: PromptPopupViewModel
    let appState: AppState

    /// Callback to dismiss the popup
    var onDismiss: (() -> Void)?

    /// Callback fired when a prompt starts processing (popup switches to response mode)
    var onResponseStarted: (() -> Void)?

    /// Pin is offered only while waiting for or showing a response
    private var isResponseVisible: Bool {
        appState.isLoading || appState.showingResult
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
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
            await viewModel.loadModelsIfNeeded()
        }
        .onChange(of: appState.isLoading) { _, isLoading in
            if isLoading {
                onResponseStarted?()
            }
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

            if isResponseVisible {
                pinButton
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
        // The header doubles as a drag handle; SwiftUI content covers the whole
        // window, so isMovableByWindowBackground never sees a background click.
        .background(WindowDragArea())
    }

    private var pinButton: some View {
        Button {
            appState.isPopupPinned.toggle()
        } label: {
            Image(systemName: appState.isPopupPinned ? "pin.fill" : "pin")
                .foregroundStyle(appState.isPopupPinned ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
        .help(appState.isPopupPinned ? "Unpin window" : "Pin window to keep it open when switching apps")
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

                // Prompt buttons - read directly from appState for reliable observation
                ForEach(appState.settings.prompts) { prompt in
                    PromptButton(
                        prompt: prompt, modelAvailability: viewModel.availability(of: prompt)
                    ) {
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

// MARK: - Window Drag Area

/// Transparent view that moves its window when dragged.
/// ponytail: AppKit bridge because WindowDragGesture requires macOS 15; swap once the target is raised.
private struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
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
