// UpdateService.swift
// In-app updates from GitHub Releases: finds a newer release, downloads its .zip package,
// checks its code signature and swaps it with the running app.
// A copy downloaded by the app itself carries no quarantine flag, so Gatekeeper
// does not ask for "Open Anyway" the way it does for a browser download.

import AppKit
import Foundation
import Security

/// A published release that is newer than the running app
struct AppRelease: Equatable, Sendable {
    /// Version without the tag's "v" prefix, e.g. "1.2.0"
    let version: String
    /// Download URL of the release's .zip package
    let archiveURL: URL
}

enum UpdateService {
    private static let archiveExtension = "zip"
    private static let appExtension = "app"
    private static let tagPrefix = "v"
    private static let successStatusCode = 200

    /// Subset of the GitHub "latest release" response
    private struct GitHubRelease: Decodable {
        struct Asset: Decodable {
            let name: String
            let browserDownloadUrl: URL
        }

        let tagName: String
        let assets: [Asset]
    }

    // MARK: - Check

    /// Returns the latest published release, or nil when the running app is not older than it.
    static func fetchAvailableUpdate() async throws -> AppRelease? {
        var request = URLRequest(url: AppConstants.latestReleaseAPIURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let release = try decoder.decode(GitHubRelease.self, from: data)

        let version = release.tagName.hasPrefix(tagPrefix)
            ? String(release.tagName.dropFirst(tagPrefix.count))
            : release.tagName
        guard version.compare(currentVersion, options: .numeric) == .orderedDescending else {
            return nil
        }
        guard let archive = release.assets.first(where: { $0.name.hasSuffix(".\(archiveExtension)") }) else {
            throw AppError.updateFailed("release \(version) has no .\(archiveExtension) package")
        }
        return AppRelease(version: version, archiveURL: archive.browserDownloadUrl)
    }

    private static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    private static func validate(_ response: URLResponse) throws {
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard statusCode == successStatusCode else {
            throw AppError.apiError(statusCode: statusCode, message: "GitHub did not return the release")
        }
    }

    // MARK: - Install

    /// Replaces the running app bundle with the release. Call `relaunch()` afterwards.
    // ponytail: works when the user owns the app bundle (drag-and-drop install). A copy installed
    // by the .pkg belongs to root and fails here; add a privileged helper if that matters.
    static func install(_ release: AppRelease) async throws {
        let installedApp = Bundle.main.bundleURL
        guard installedApp.pathExtension == appExtension else {
            throw AppError.updateFailed("the app is not running from an .\(appExtension) bundle")
        }

        // A folder on the app's own volume, so the final swap is a rename and not a copy.
        let workDirectory = try FileManager.default.url(
            for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: installedApp, create: true
        )
        defer { try? FileManager.default.removeItem(at: workDirectory) }

        let (archive, response) = try await URLSession.shared.download(from: release.archiveURL)
        defer { try? FileManager.default.removeItem(at: archive) }
        try validate(response)

        let downloadedApp = try unzipApp(from: archive, into: workDirectory)
        try verifySignature(of: downloadedApp)
        _ = try FileManager.default.replaceItemAt(installedApp, withItemAt: downloadedApp)
        Log.update.info("Installed version \(release.version)")
    }

    /// Starts the installed copy once this process has exited, then quits.
    @MainActor
    static func relaunch() {
        let relauncher = Process()
        relauncher.executableURL = URL(fileURLWithPath: "/bin/sh")
        // The bundle path is passed as $0, so it needs no shell escaping.
        relauncher.arguments = [
            "-c",
            "while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done; open \"$0\"",
            Bundle.main.bundlePath,
        ]
        do {
            try relauncher.run()
        } catch {
            Log.update.error("Relaunch failed, the update starts on the next launch: \(error.localizedDescription)")
        }
        NSApp.terminate(nil)
    }

    private static func unzipApp(from archive: URL, into directory: URL) throws -> URL {
        let ditto = Process()
        ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        ditto.arguments = ["-x", "-k", archive.path, directory.path]
        try ditto.run()
        ditto.waitUntilExit()

        let extractedItems = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        )
        guard ditto.terminationStatus == 0,
              let app = extractedItems.first(where: { $0.pathExtension == appExtension })
        else {
            throw AppError.updateFailed("the downloaded package could not be unpacked")
        }
        return app
    }

    /// Accepts only an intact app that meets the running app's designated requirement:
    /// the same bundle identifier, signed with the same certificate.
    private static func verifySignature(of app: URL) throws {
        var runningCode: SecCode?
        var runningStaticCode: SecStaticCode?
        var requirement: SecRequirement?
        var downloadedCode: SecStaticCode?

        guard SecCodeCopySelf([], &runningCode) == errSecSuccess, let runningCode,
              SecCodeCopyStaticCode(runningCode, [], &runningStaticCode) == errSecSuccess,
              let runningStaticCode,
              SecCodeCopyDesignatedRequirement(runningStaticCode, [], &requirement) == errSecSuccess,
              let requirement,
              SecStaticCodeCreateWithPath(app as CFURL, [], &downloadedCode) == errSecSuccess,
              let downloadedCode
        else {
            throw AppError.updateFailed("the code signature could not be read")
        }

        let checks = SecCSFlags(
            rawValue: kSecCSCheckAllArchitectures | kSecCSCheckNestedCode | kSecCSStrictValidate
        )
        let status = SecStaticCodeCheckValidity(downloadedCode, checks, requirement)
        guard status == errSecSuccess else {
            let reason = SecCopyErrorMessageString(status, nil) as String? ?? "status \(status)"
            throw AppError.updateFailed("the download is not signed like this app (\(reason))")
        }
    }
}
