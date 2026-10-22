// ModelPickerView.swift
// Dropdown of AI models with a substring filter and provider-prefixed labels.

import SwiftUI

/// Model selector showing "[Provider] Model name" rows, filterable by model name.
/// The selected model is shown even when it is missing from `models` (e.g. outdated).
struct ModelPickerView: View {
    let models: [AIModel]
    let selectedModel: AIModel?
    /// Renders the selected model label in red to signal a problem with it
    var isHighlightedAsError = false
    let onSelect: (AIModel) -> Void

    @State private var isShown = false
    @State private var filterText = ""
    @FocusState private var isFilterFieldFocused: Bool

    /// Case-insensitive substring match on the model name only.
    private var filteredModels: [AIModel] {
        let query = filterText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return models }
        return models.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private func isSelected(_ model: AIModel) -> Bool {
        model.id == selectedModel?.id && model.provider == selectedModel?.provider
    }

    var body: some View {
        Button {
            isShown.toggle()
        } label: {
            HStack(spacing: 4) {
                if let model = selectedModel {
                    if isHighlightedAsError {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    providerLabel(model.provider)
                    Text(model.name)
                        .lineLimit(1)
                } else {
                    Text("Select model")
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(isHighlightedAsError ? Color.red : Color.primary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShown, arrowEdge: .bottom) {
            modelListPopover
                .frame(width: 320, height: 360)
        }
        .onChange(of: isShown) { _, shown in
            if shown {
                // Start each session with an empty filter.
                filterText = ""
                isFilterFieldFocused = true
            }
        }
    }

    // MARK: - Popover

    private var modelListPopover: some View {
        VStack(spacing: 0) {
            TextField("Filter models…", text: $filterText)
                .textFieldStyle(.roundedBorder)
                .padding(8)
                .focused($isFilterFieldFocused)
                .onSubmit(selectFirstMatch)

            Divider()

            if filteredModels.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredModels) { model in
                            ModelRow(
                                model: model,
                                isSelected: isSelected(model)
                            ) {
                                onSelect(model)
                                isShown = false
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .background(.background)
        .onExitCommand { isShown = false }
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("No models match")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func selectFirstMatch() {
        guard let model = filteredModels.first else { return }
        onSelect(model)
        isShown = false
    }

    private func providerLabel(_ provider: AIProvider) -> some View {
        Text("[\(provider.displayName)]")
            .foregroundStyle(isHighlightedAsError ? Color.red : Color.secondary)
            .lineLimit(1)
    }
}

// MARK: - Model Row

/// A single model row in the dropdown list.
private struct ModelRow: View {
    let model: AIModel
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text("[\(model.provider.displayName)]")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(model.name)
                    .lineLimit(1)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .font(.callout)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isHovered ? Color.accentColor.opacity(0.1) : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}