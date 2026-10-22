// PromptsSettingsView.swift
// Settings tab for managing user-defined AI prompts (add, edit, delete, reorder).

import SwiftUI
import UniformTypeIdentifiers

/// Represents the editor mode for the prompt sheet.
/// Using an Identifiable enum with `.sheet(item:)` ensures the sheet is
/// recreated each time, avoiding SwiftUI stale-state issues.
enum PromptEditorMode: Identifiable {
    case new
    case editing(Prompt)

    var id: String {
        switch self {
        case .new:
            return "new"
        case .editing(let prompt):
            return prompt.id.uuidString
        }
    }
}

struct PromptsSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    /// Controls the editor sheet presentation and provides context
    @State private var editorMode: PromptEditorMode?

    /// The prompt pending deletion (triggers confirmation alert)
    @State private var promptToDelete: Prompt?

    /// Tracks the prompt being dragged for reordering
    @State private var draggingPrompt: Prompt?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prompts")
                .font(.headline)

            Text("Configure the prompts that appear when you trigger the shortcut. Drag items to reorder.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Prompt list with drag and drop support
            List {
                ForEach(viewModel.settings.prompts) { prompt in
                    PromptRowView(
                        prompt: prompt,
                        modelAvailability: viewModel.availability(of: prompt.model),
                        onEdit: { editorMode = .editing(prompt) },
                        onDelete: { promptToDelete = prompt }
                    )
                    .draggable(prompt.id.uuidString) {
                        // Drag preview
                        PromptDragPreview(prompt: prompt)
                    }
                    .dropDestination(for: String.self) { items, _ in
                        guard let draggedIdString = items.first,
                              let draggedId = UUID(uuidString: draggedIdString),
                              let sourceIndex = viewModel.settings.prompts.firstIndex(where: { $0.id == draggedId }),
                              let destinationIndex = viewModel.settings.prompts.firstIndex(where: { $0.id == prompt.id }),
                              sourceIndex != destinationIndex else {
                            return false
                        }
                        viewModel.movePrompt(from: IndexSet(integer: sourceIndex), to: destinationIndex > sourceIndex ? destinationIndex + 1 : destinationIndex)
                        return true
                    } isTargeted: { _ in
                        // Visual feedback handled by SwiftUI
                    }
                }
                .onDelete(perform: viewModel.deletePrompt)
            }
            .listStyle(.bordered)

            // Add button
            HStack {
                Button {
                    editorMode = .new
                } label: {
                    Label("Add Prompt", systemImage: "plus")
                }

                Spacer()
            }
        }
        .padding()
        .sheet(item: $editorMode) { mode in
            PromptEditorSheet(mode: mode, viewModel: viewModel) {
                editorMode = nil
            }
        }
        .alert(
            "Delete Prompt",
            isPresented: Binding(
                get: { promptToDelete != nil },
                set: { if !$0 { promptToDelete = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) {
                promptToDelete = nil
            }
            Button("Delete", role: .destructive) {
                confirmDelete()
            }
        } message: {
            if let prompt = promptToDelete {
                Text("Are you sure you want to delete \"\(prompt.title)\"?")
            }
        }
    }

    // MARK: - Helpers

    private func confirmDelete() {
        guard let prompt = promptToDelete,
              let index = viewModel.settings.prompts.firstIndex(where: { $0.id == prompt.id }) else {
            promptToDelete = nil
            return
        }
        viewModel.deletePrompt(at: IndexSet(integer: index))
        promptToDelete = nil
    }
}

// MARK: - Prompt Editor Sheet (separate view to guarantee fresh state)

/// A standalone sheet view for adding/editing a prompt.
/// Being a separate struct ensures all `@State` fields are initialized fresh
/// each time the sheet is presented, eliminating stale-state bugs.
private struct PromptEditorSheet: View {
    let mode: PromptEditorMode
    let viewModel: SettingsViewModel
    let dismiss: () -> Void

    @State private var title: String
    @State private var template: String
    @State private var icon: String
    @State private var webSearchEnabled: Bool
    @State private var model: AIModel?

    init(mode: PromptEditorMode, viewModel: SettingsViewModel, dismiss: @escaping () -> Void) {
        self.mode = mode
        self.viewModel = viewModel
        self.dismiss = dismiss

        switch mode {
        case .new:
            _title = State(initialValue: "")
            _template = State(initialValue: "")
            _icon = State(initialValue: "text.bubble")
            _webSearchEnabled = State(initialValue: false)
            _model = State(initialValue: viewModel.availableModels.first)
        case .editing(let prompt):
            _title = State(initialValue: prompt.title)
            _template = State(initialValue: prompt.template)
            _icon = State(initialValue: prompt.icon)
            _webSearchEnabled = State(initialValue: prompt.webSearchEnabled)
            _model = State(initialValue: prompt.model)
        }
    }

    private var isEditing: Bool {
        if case .editing = mode { return true }
        return false
    }

    private var modelAvailability: ModelAvailability {
        viewModel.availability(of: model)
    }

    /// Outdated, missing, or not-yet-verified models block saving; provider load failures only warn.
    private var canSave: Bool {
        guard !title.isEmpty, !template.isEmpty else { return false }
        switch modelAvailability {
        case .available, .providerLoadFailed:
            return true
        case .notSelected, .loading, .outdated:
            return false
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(isEditing ? "Edit Prompt" : "New Prompt")
                .font(.headline)

            Form {
                TextField("Title", text: $title)
                    .textFieldStyle(.roundedBorder)

                modelSection

                VStack(alignment: .leading) {
                    Text("Template")
                        .font(.caption)
                    TextEditor(text: $template)
                        .font(.body.monospaced())
                        .frame(minHeight: 100)
                        .border(Color.secondary.opacity(0.3))
                }

                IconPickerView(selectedIcon: $icon)

                Toggle(isOn: $webSearchEnabled) {
                    Label("Enable web search", systemImage: "magnifyingglass")
                }
                .help("Let the model search the web for up-to-date information when answering this prompt")
            }

            // Hint about optional {text} placeholder
            Text("Tip: Use {text} in your prompt to control where captured content is inserted. If omitted, captured content will be appended after your prompt automatically.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(isEditing ? "Save" : "Add") {
                    savePrompt()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .padding()
        .frame(width: 400, height: 470)
    }

    // MARK: - Model Section

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Model")
                Spacer()
                if viewModel.availableModels.isEmpty && model == nil && !viewModel.isLoadingModels {
                    Text("No models — add an API key")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ModelPickerView(
                        models: viewModel.availableModels,
                        selectedModel: model,
                        isHighlightedAsError: modelAvailability.isError
                    ) { selected in
                        model = selected
                    }
                }
            }

            PromptBadgesView(
                model: model, availability: modelAvailability, webSearchEnabled: webSearchEnabled
            )

            modelStatusMessage
        }
    }

    @ViewBuilder
    private var modelStatusMessage: some View {
        if modelAvailability == .loading {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Loading models…")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if let warning = modelAvailability.warningMessage(for: model) {
            Text(warning)
                .font(.caption)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func savePrompt() {
        switch mode {
        case .new:
            viewModel.addPrompt(
                Prompt(
                    title: title, template: template, icon: icon,
                    webSearchEnabled: webSearchEnabled, model: model
                )
            )
        case .editing(var existing):
            existing.title = title
            existing.template = template
            existing.icon = icon
            existing.webSearchEnabled = webSearchEnabled
            existing.model = model
            viewModel.updatePrompt(existing)
        }
    }
}

// MARK: - Prompt Row View

/// A single row in the prompts list with badges, edit and delete actions.
private struct PromptRowView: View {
    let prompt: Prompt
    let modelAvailability: ModelAvailability
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)
                .font(.caption)

            Image(systemName: prompt.icon)
                .frame(width: 20)
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(prompt.title)
                    .font(.body)
                PromptBadgesView(
                    model: prompt.model,
                    availability: modelAvailability,
                    webSearchEnabled: prompt.webSearchEnabled
                )
                Text(prompt.template)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)

            Button {
                onDelete()
            } label: {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Prompt Drag Preview

/// Visual preview shown while dragging a prompt item.
private struct PromptDragPreview: View {
    let prompt: Prompt

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: prompt.icon)
                .foregroundStyle(Color.accentColor)
            Text(prompt.title)
                .font(.body)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 4)
    }
}
