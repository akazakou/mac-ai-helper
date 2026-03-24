// ResultView.swift
// Displays the AI response with copy-to-clipboard functionality.

import MarkdownUI
import SwiftUI

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
            }

            Divider()

            // Action bar
            actionBar
        }
    }

    // MARK: - Response View

    private var responseView: some View {
        ScrollView {
            Markdown(viewModel.responseText)
                .textSelection(.enabled)
                .markdownTheme(.gitHub)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
        .frame(minHeight: 100, maxHeight: .infinity)
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
            .disabled(viewModel.responseText.isEmpty)

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
