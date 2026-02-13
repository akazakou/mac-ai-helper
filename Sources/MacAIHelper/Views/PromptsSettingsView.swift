// PromptsSettingsView.swift
// Settings tab for managing user-defined AI prompts (add, edit, delete, reorder).

import SwiftUI

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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prompts")
                .font(.headline)

            Text("Configure the prompts that appear when you trigger the shortcut. Use {text} as a placeholder for the captured content.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Prompt list
            List {
                ForEach(viewModel.settings.prompts) { prompt in
                    HStack(spacing: 12) {
                        Image(systemName: prompt.icon)
                            .frame(width: 20)
                            .foregroundStyle(Color.accentColor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(prompt.title)
                                .font(.body)
                            Text(prompt.template)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button {
                            editorMode = .editing(prompt)
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless)

                        Button {
                            promptToDelete = prompt
                        } label: {
                            Image(systemName: "xmark.circle")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: viewModel.deletePrompt)
                .onMove(perform: viewModel.movePrompt)
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

    init(mode: PromptEditorMode, viewModel: SettingsViewModel, dismiss: @escaping () -> Void) {
        self.mode = mode
        self.viewModel = viewModel
        self.dismiss = dismiss

        switch mode {
        case .new:
            _title = State(initialValue: "")
            _template = State(initialValue: "{text}")
            _icon = State(initialValue: "text.bubble")
        case .editing(let prompt):
            _title = State(initialValue: prompt.title)
            _template = State(initialValue: prompt.template)
            _icon = State(initialValue: prompt.icon)
        }
    }

    private var isEditing: Bool {
        if case .editing = mode { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(isEditing ? "Edit Prompt" : "New Prompt")
                .font(.headline)

            Form {
                TextField("Title", text: $title)
                    .textFieldStyle(.roundedBorder)

                VStack(alignment: .leading) {
                    Text("Template")
                        .font(.caption)
                    TextEditor(text: $template)
                        .font(.body.monospaced())
                        .frame(minHeight: 100)
                        .border(Color.secondary.opacity(0.3))
                }

                IconPickerView(selectedIcon: $icon)
            }

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
                .disabled(title.isEmpty || template.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 350)
    }

    private func savePrompt() {
        switch mode {
        case .new:
            viewModel.addPrompt(title: title, template: template, icon: icon)
        case .editing(var existing):
            existing.title = title
            existing.template = template
            existing.icon = icon
            viewModel.updatePrompt(existing)
        }
    }
}
