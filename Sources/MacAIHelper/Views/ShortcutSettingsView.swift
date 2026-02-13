// ShortcutSettingsView.swift
// Settings tab for viewing and managing keyboard shortcuts.

import SwiftUI

struct ShortcutSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    /// Tracks screen recording permission status (loaded asynchronously)
    @State private var hasScreenCapturePermission = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Keyboard Shortcuts")
                .font(.headline)

            Text("These global shortcuts work from any application.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Shortcuts display
            Form {
                Section("Text Prompt") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Trigger text prompt popup")
                                .font(.body)
                            Text("Select text in any app, then use this shortcut. The first press copies the text, the second press opens the prompt popup.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        ShortcutBadge(displayName: viewModel.settings.promptShortcut.displayName)
                    }
                }

                Section("Screenshot") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Capture screenshot region")
                                .font(.body)
                            Text("Captures a region of the screen and opens the prompt popup for image analysis.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        ShortcutBadge(
                            displayName: viewModel.settings.screenshotShortcut.displayName
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

// MARK: - Shortcut Badge

/// A styled badge displaying a keyboard shortcut.
struct ShortcutBadge: View {
    let displayName: String

    var body: some View {
        Text(displayName)
            .font(.system(.body, design: .monospaced))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
