// ShortcutSettingsView.swift
// Settings tab for viewing and managing keyboard shortcuts.
// Uses ShortcutRecorderView for inline shortcut editing.
// Double-tap detection is handled automatically by the recorder.

import SwiftUI

struct ShortcutSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    /// Tracks screen recording permission status (loaded asynchronously)
    @State private var hasScreenCapturePermission = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Keyboard Shortcuts")
                .font(.headline)

            Text("These global shortcuts work from any application. Click the pencil icon to change a shortcut. Press the same key twice quickly to record a double-tap sequence.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Shortcuts editor
            Form {
                Section("Text Prompt") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Trigger text prompt popup")
                                .font(.body)
                            Text("Select text in any app, then use this shortcut.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        ShortcutRecorderView(
                            shortcut: $viewModel.settings.promptShortcut,
                            onSave: { newShortcut in
                                viewModel.updatePromptShortcut(newShortcut)
                            }
                        )
                    }
                }

                Section("Screenshot") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Capture screenshot region")
                                .font(.body)
                            Text("Captures a screen region for image analysis.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        ShortcutRecorderView(
                            shortcut: $viewModel.settings.screenshotShortcut,
                            onSave: { newShortcut in
                                viewModel.updateScreenshotShortcut(newShortcut)
                            }
                        )
                    }
                }
            }
            .formStyle(.grouped)

            // Permission status
            VStack(alignment: .leading, spacing: 8) {
                Text("Permissions")
                    .font(.subheadline.bold())

                HStack {
                    Image(
                        systemName: HotkeyService.checkAccessibilityPermission()
                            ? "checkmark.circle.fill" : "xmark.circle.fill"
                    )
                    .foregroundStyle(
                        HotkeyService.checkAccessibilityPermission() ? .green : .red
                    )

                    Text("Accessibility")
                    Spacer()

                    if !HotkeyService.checkAccessibilityPermission() {
                        Button("Grant Access") {
                            HotkeyService.requestAccessibilityPermission()
                        }
                        .font(.caption)
                    }
                }

                HStack {
                    Image(
                        systemName: hasScreenCapturePermission
                            ? "checkmark.circle.fill" : "xmark.circle.fill"
                    )
                    .foregroundStyle(hasScreenCapturePermission ? .green : .red)

                    Text("Screen Recording")
                    Spacer()

                    if !hasScreenCapturePermission {
                        Button("Open Settings") {
                            NSWorkspace.shared.open(
                                URL(
                                    string:
                                        "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
                                )!)
                        }
                        .font(.caption)
                    }
                }
            }
            .padding()
            .background(.background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer()
        }
        .padding()
        .task {
            hasScreenCapturePermission = await ScreenCaptureService.checkPermission()
        }
    }
}
