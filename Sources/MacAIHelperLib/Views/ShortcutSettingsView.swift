// ShortcutSettingsView.swift
// Settings tab for viewing and managing keyboard shortcuts.
// Uses KeyboardShortcuts.Recorder for inline shortcut editing.
// No Accessibility permission required — Carbon RegisterEventHotKey
// works inside App Sandbox.

import KeyboardShortcuts
import os
import SwiftUI

struct ShortcutSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    /// Tracks screen recording permission status (loaded asynchronously)
    @State private var hasScreenCapturePermission = false

    var body: some View {
        let _ = Log.ui.debug("ShortcutSettingsView body evaluation started")
        VStack(alignment: .leading, spacing: 16) {
            let _ = Log.ui.debug("ShortcutSettingsView: rendering General section")
            // General section
            Text("General")
                .font(.headline)

            Toggle("Launch at Login", isOn: Binding(
                get: { viewModel.settings.launchAtLogin },
                set: { viewModel.toggleLaunchAtLogin($0) }
            ))
            .padding(.horizontal, 4)

            Divider()

            let _ = Log.ui.debug("ShortcutSettingsView: rendering Keyboard Shortcuts header")
            Text("Keyboard Shortcuts")
                .font(.headline)

            Text("These global shortcuts work from any application. Click the recorder field to change a shortcut.")
                .font(.caption)
                .foregroundStyle(.secondary)

            let _ = Log.ui.debug("ShortcutSettingsView: about to create Form with KeyboardShortcuts.Recorder")
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

                        let _ = Log.ui.debug("ShortcutSettingsView: creating textPrompt Recorder")
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

                        let _ = Log.ui.debug("ShortcutSettingsView: creating screenshotCapture Recorder")
                        KeyboardShortcuts.Recorder(for: .screenshotCapture)
                    }
                }
            }
            .formStyle(.grouped)

            let _ = Log.ui.debug("ShortcutSettingsView: rendering Permissions section")
            // Permission status — only Screen Recording needed now
            let _ = Log.ui.debug("ShortcutSettingsView: Permissions — creating VStack")
            VStack(alignment: .leading, spacing: 8) {
                let _ = Log.ui.debug("ShortcutSettingsView: Permissions — inside VStack")
                Text("Permissions")
                    .font(.subheadline.bold())

                let _ = Log.ui.debug("ShortcutSettingsView: Permissions — creating HStack with image/text")
                HStack {
                    let _ = Log.ui.debug("ShortcutSettingsView: Permissions — creating permission icon, hasPermission=\(hasScreenCapturePermission)")
                    Image(
                        systemName: hasScreenCapturePermission
                            ? "checkmark.circle.fill" : "xmark.circle.fill"
                    )
                    .foregroundStyle(hasScreenCapturePermission ? .green : .red)

                    let _ = Log.ui.debug("ShortcutSettingsView: Permissions — creating Screen Recording text")
                    Text("Screen Recording")
                    Spacer()

                    let _ = Log.ui.debug("ShortcutSettingsView: Permissions — checking if button needed")
                    if !hasScreenCapturePermission {
                        let _ = Log.ui.debug("ShortcutSettingsView: Permissions — creating Open Settings button")
                        Button("Open Settings") {
                            NSWorkspace.shared.open(
                                URL(
                                    string:
                                        "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
                                )!)
                        }
                        .font(.caption)
                    }
                    let _ = Log.ui.debug("ShortcutSettingsView: Permissions — HStack content complete")
                }
                let _ = Log.ui.debug("ShortcutSettingsView: Permissions — VStack content complete")
            }
            .padding()
            .background(.background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            let _ = Log.ui.debug("ShortcutSettingsView: Permissions section modifiers applied")
            let _ = Log.ui.debug("ShortcutSettingsView: body construction complete")
            Spacer()
        }
        .padding()
        .task {
            Log.ui.debug("ShortcutSettingsView: .task started — checking screen capture permission")
            hasScreenCapturePermission = await ScreenCaptureService.checkPermission()
            Log.ui.debug("ShortcutSettingsView: .task completed — permission=\(hasScreenCapturePermission)")
        }
    }
}
