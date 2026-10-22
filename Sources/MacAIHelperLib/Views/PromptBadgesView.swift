// PromptBadgesView.swift
// Compact badges describing a prompt: model provider, model name, model status, and options.

import SwiftUI

struct PromptBadgesView: View {
    let model: AIModel?
    let availability: ModelAvailability
    let webSearchEnabled: Bool

    private var modelTint: Color {
        availability.isError ? .red : .secondary
    }

    var body: some View {
        HStack(spacing: 4) {
            if let model {
                Badge(text: model.provider.displayName, tint: modelTint)
                Badge(text: model.name, tint: modelTint)
                    // Long model names truncate first so the other badges stay readable.
                    .layoutPriority(-1)
            } else {
                Badge(text: "No model", systemImage: "exclamationmark.triangle", tint: .orange)
            }

            if availability == .outdated {
                Badge(text: "Outdated", systemImage: "exclamationmark.triangle.fill", tint: .red)
            }

            if webSearchEnabled {
                Badge(text: "Web search", systemImage: "globe", tint: .secondary)
            }
        }
        .help(availability.warningMessage(for: model) ?? "")
    }
}

// MARK: - Badge

/// A single capsule-shaped badge.
private struct Badge: View {
    let text: String
    var systemImage: String?
    let tint: Color

    var body: some View {
        HStack(spacing: 2) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(text)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.caption2)
        .foregroundStyle(tint)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(tint.opacity(0.15), in: Capsule())
    }
}
