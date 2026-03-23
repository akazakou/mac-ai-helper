// LaunchAtLoginService.swift
// Manages the app's launch-at-login state using SMAppService (macOS 13+).

import Foundation
import ServiceManagement

struct LaunchAtLoginService: Sendable {
    /// Registers the app to launch at system login.
    static func enable() throws {
        try SMAppService.mainApp.register()
    }

    /// Unregisters the app from launching at system login.
    static func disable() throws {
        try SMAppService.mainApp.unregister()
    }

    /// Returns whether the app is currently registered to launch at login.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Sets the launch-at-login state, registering or unregistering as needed.
    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try enable()
        } else {
            try disable()
        }
    }
}
