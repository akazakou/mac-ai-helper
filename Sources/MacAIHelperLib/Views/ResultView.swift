// ResultView.swift
// Displays the AI response (Markdown, plain text or a translated image)
// with copy-to-clipboard and save-image actions.

import AppKit
import MarkdownUI
import SwiftUI
import UniformTypeIdentifiers

struct ResultView: View {
    @Bindable var viewModel: ResultViewModel

    /// Callback to dismiss the entire popup
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Content area
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.errorMessage {
                errorView(error)
            } else {
                responseView
                aiDisclaimerFooter
            }

            Divider()

            // Action bar
            actionBar
        }
    }

    // MARK: - Response View

    private var responseView: some View {
        ScrollView {
            responseContent
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
        .frame(minHeight: 100, maxHeight: .infinity)
    }

    /// Translations are shown verbatim: Markdown would join their lines and
    /// treat characters such as * or # as formatting.
    @ViewBuilder
    private var responseContent: some View {
        switch viewModel.response {
        case .plainText(let text):
            Text(text)
                .font(.system(size: NSFont.systemFontSize))
        case .markdown(let text):
            Markdown(text)
                .markdownTextStyle(\.text) {
                    FontSize(NSFont.systemFontSize)
                }
                .markdownTheme(.gitHub)
        case .image(let pngData):
            translatedImage(pngData)
        case nil:
            EmptyView()
        }
    }

    /// Shows the image no larger than the screenshot was on screen, shrinking it to the window width.
    @ViewBuilder
    private func translatedImage(_ pngData: Data) -> some View {
        if let image = NSImage(data: pngData) {
            // The PNG holds screen pixels; dividing by the display scale gives its size in points.
            let displayScale = NSScreen.main?.backingScaleFactor ?? 1
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: image.size.width / displayScale)
        }
    }

    // MARK: - Save Image

    private static let defaultImageFileName = "Translated screenshot.png"

    /// Asks where to save the translated image. The panel is a sheet of the popup,
    /// which keeps the popup from closing as it would when another window takes focus.
    private func presentSaveImagePanel() {
        guard let window = NSApp.keyWindow else { return }
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = Self.defaultImageFileName
        savePanel.beginSheetModal(for: window) { result in
            guard result == .OK, let url = savePanel.url else { return }
            viewModel.saveImage(to: url)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Waiting for AI response…")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.red)
            Text("Error")
                .font(.headline)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .padding(12)
    }

    // MARK: - AI Disclaimer

    private var aiDisclaimerFooter: some View {
        HStack(spacing: 4) {
            Image(systemName: "info.circle")
                .font(.caption2)
            Text("AI-generated content — may not be accurate. Verify important information independently.")
                .font(.caption2)
        }
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack {
            // Copy button
            Button {
                viewModel.copyResponse()
                viewModel.dismiss()
                onDismiss?()
            } label: {
                Label(
                    viewModel.copied ? "Copied!" : "Copy",
                    systemImage: viewModel.copied ? "checkmark" : "doc.on.doc"
                )
            }
            .disabled(!viewModel.canCopy)

            if case .image = viewModel.response {
                Button {
                    presentSaveImagePanel()
                } label: {
                    Label(
                        viewModel.saved ? "Saved!" : "Save Image…",
                        systemImage: viewModel.saved ? "checkmark" : "square.and.arrow.down"
                    )
                }
            }

            if let saveError = viewModel.saveErrorMessage {
                Text(saveError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

            Spacer()

            // Close button
            Button("Done") {
                viewModel.dismiss()
                onDismiss?()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(12)
    }
}
