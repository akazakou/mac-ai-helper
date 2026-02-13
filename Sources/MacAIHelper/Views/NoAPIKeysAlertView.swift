// NoAPIKeysAlertView.swift
// A centered alert view shown when no API keys are configured.

import SwiftUI

/// Custom alert view with centered icon, title, message, and OK button.
struct NoAPIKeysAlertView: View {
    /// Called when the user taps OK to dismiss the alert
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 48))

            Text("API Keys Required")
                .font(.headline)

            Text("You need to add API keys for AI providers first.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("OK") {
                onDismiss()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
