// UpdateViewModel.swift
// Tracks whether a newer release exists and drives its installation.

import Foundation

@Observable
@MainActor
final class UpdateViewModel {
    enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case available(AppRelease)
        case installing
        case failed(String)
    }

    /// A menu bar app can run for weeks, so the check repeats instead of running at launch only
    private static let automaticCheckInterval: Duration = .seconds(24 * 60 * 60)

    private(set) var status: Status = .idle

    /// Whether a check or an install is running
    var isBusy: Bool {
        status == .checking || status == .installing
    }

    func startAutomaticChecks() {
        Task {
            while !Task.isCancelled {
                await checkForUpdates()
                try? await Task.sleep(for: Self.automaticCheckInterval)
            }
        }
    }

    func checkForUpdates() async {
        guard !isBusy else { return }
        status = .checking
        do {
            if let release = try await UpdateService.fetchAvailableUpdate() {
                status = .available(release)
            } else {
                status = .upToDate
            }
        } catch {
            fail(error)
        }
    }

    /// Installs the release and relaunches the app. Returns only when the install failed.
    func install(_ release: AppRelease) async {
        guard !isBusy else { return }
        status = .installing
        do {
            try await UpdateService.install(release)
            UpdateService.relaunch()
        } catch {
            fail(error)
        }
    }

    private func fail(_ error: Error) {
        Log.update.error("\(error.localizedDescription)")
        status = .failed(error.localizedDescription)
    }
}
