// PromptsSettingsView.swift
// Settings tab for managing user-defined AI prompts (add, edit, delete, reorder).

import SwiftUI

struct PromptsSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    /// Controls whether the add/edit sheet is presented
    @State private var showingEditor = false

    /// The prompt currently being edited (nil for new prompt)
    @State private var editingPrompt: Prompt?

    /// The prompt pending deletion (triggers confirmation alert)
    @State private var promptToDelete: Prompt?

    /// Fields for the prompt editor
    @State private var editorTitle = ""
    @State private var editorTemplate = ""
    @State private var editorIcon = "text.bubble"

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
                            startEditing(prompt)
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
                    startAddingNew()
                } label: {
                    Label("Add Prompt", systemImage: "plus")
                }

                Spacer()
            }
        }
        .padding()
        .sheet(isPresented: $showingEditor) {
            promptEditorSheet
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

    // MARK: - Prompt Editor Sheet

    private var promptEditorSheet: some View {
        VStack(spacing: 16) {
            Text(editingPrompt == nil ? "New Prompt" : "Edit Prompt")
                .font(.headline)

            Form {
                TextField("Title", text: $editorTitle)
                    .textFieldStyle(.roundedBorder)

                VStack(alignment: .leading) {
                    Text("Template")
                        .font(.caption)
                    TextEditor(text: $editorTemplate)
                        .font(.body.monospaced())
                        .frame(minHeight: 100)
                        .border(Color.secondary.opacity(0.3))
                }

                IconPickerView(selectedIcon: $editorIcon)
            }

            HStack {
                Button("Cancel") {
                    showingEditor = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(editingPrompt == nil ? "Add" : "Save") {
                    savePrompt()
                    showingEditor = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(editorTitle.isEmpty || editorTemplate.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 350)
    }

    // MARK: - Helpers

    private func startAddingNew() {
        editingPrompt = nil
        editorTitle = ""
        editorTemplate = "{text}"
        editorIcon = "text.bubble"
        showingEditor = true
    }

    private func startEditing(_ prompt: Prompt) {
        editingPrompt = prompt
        editorTitle = prompt.title
        editorTemplate = prompt.template
        editorIcon = prompt.icon
        showingEditor = true
    }

    private func confirmDelete() {
        guard let prompt = promptToDelete,
              let index = viewModel.settings.prompts.firstIndex(where: { $0.id == prompt.id }) else {
            promptToDelete = nil
            return
        }
        viewModel.deletePrompt(at: IndexSet(integer: index))
        promptToDelete = nil
    }

    private func savePrompt() {
        if var existing = editingPrompt {
            existing.title = editorTitle
            existing.template = editorTemplate
            existing.icon = editorIcon
            viewModel.updatePrompt(existing)
        } else {
            viewModel.addPrompt(title: editorTitle, template: editorTemplate, icon: editorIcon)
        }
    }
}
