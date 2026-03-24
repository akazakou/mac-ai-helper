// ShortcutSettingsView.swift
// Settings tab for viewing and managing keyboard shortcuts.
// Uses KeyboardShortcuts.Recorder for inline shortcut editing.
// No Accessibility permission required — Carbon RegisterEventHotKey
// works inside App Sandbox.

import KeyboardShortcuts
import SwiftUI

struct ShortcutSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    /// Tracks screen recording permission status (loaded asynchronously)
    @State private var hasScreenCapturePermission = false

    /// Tracks accessibility permission status (needed for text copy simulation)
    @State private var hasAccessibilityPermission = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // General section
            Text("General")
                .font(.headline)

            Toggle("Launch at Login", isOn: Binding(
                get: { viewModel.settings.launchAtLogin },
                set: { viewModel.toggleLaunchAtLogin($0) }
            ))
            .padding(.horizontal, 4)

            Divider()

            Text("Keyboard Shortcuts")
                .font(.headline)

            Text("These global shortcuts work from any application. Click the recorder field to change a shortcut.")
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

                        KeyboardShortcuts.Recorder(for: .textPrompt)
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

                        KeyboardShortcuts.Recorder(for: .screenshotCapture)
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

                // Accessibility permission row (needed for text copy simulation via Cmd+C)
                HStack {
                    Image(
                        systemName: hasAccessibilityPermission
                            ? "checkmark.circle.fill" : "xmark.circle.fill"
                    )
                    .foregroundStyle(hasAccessibilityPermission ? .green : .red)

                    Text("Accessibility")
                    Spacer()

                    if !hasAccessibilityPermission {
                        Button("Open Settings") {
                            NSWorkspace.shared.open(
                                URL(
                                    string:
                                        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
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
            hasAccessibilityPermission = PasteboardService.checkAccessibilityPermission()
        }
    }
}
