// AIRequestLogger.swift
// Executes AI provider HTTP requests and logs request/response metadata.
// Only diagnostic metadata is logged (provider, model, endpoint, sizes, status, duration);
// prompt content, images and API keys are never logged.

import Foundation
import os

enum AIRequestLogger {
    /// Metadata describing an AI request for diagnostics. Contains no prompt or key material.
    struct Metadata: Sendable {
        let provider: AIProvider
        let model: String
        let webSearch: Bool
        let hasImage: Bool
        /// Short description of the request purpose, e.g. "model listing", "text prompt".
        let purpose: String
        /// Model listing keeps the system default timeout so unreachable providers fail fast.
        var isModelListing = false

        static func modelListing(provider: AIProvider) -> Metadata {
            Metadata(
                provider: provider, model: "-", webSearch: false, hasImage: false,
                purpose: "model listing", isModelListing: true
            )
        }
    }

    /// Web search responses arrive only after the provider has searched and read pages,
    /// so the connection stays silent far longer than for a plain prompt.
    private static let webSearchTimeout: TimeInterval = 300
    /// Image prompts and reasoning models can exceed the 60 s system default.
    private static let promptTimeout: TimeInterval = 120

    /// Performs the request, logging metadata before and after. Re-throws transport errors.
    static func perform(
        _ request: URLRequest, metadata: Metadata
    ) async throws -> (Data, URLResponse) {
        var request = request
        if let timeout = timeout(for: metadata) {
            request.timeoutInterval = timeout
        }
        logRequestStart(request, metadata: metadata)
        let startedAt = Date()

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            logResponse(response, data: data, metadata: metadata, startedAt: startedAt)
            return (data, response)
        } catch {
            logFailure(error, metadata: metadata, startedAt: startedAt)
            throw error
        }
    }

    /// Returns the timeout for prompt requests, or nil to keep the request's own (system default).
    private static func timeout(for metadata: Metadata) -> TimeInterval? {
        if metadata.isModelListing { return nil }
        return metadata.webSearch ? webSearchTimeout : promptTimeout
    }

    // MARK: - Logging

    private static func logRequestStart(_ request: URLRequest, metadata: Metadata) {
        // Endpoint is host + path only: Gemini puts the API key in the query string.
        let endpoint = request.url.map { "\($0.host ?? "?")\($0.path)" } ?? "?"
        Log.ai.info(
            "→ [\(metadata.purpose, privacy: .public)] \(metadata.provider.displayName, privacy: .public) \(request.httpMethod ?? "GET", privacy: .public) \(endpoint, privacy: .public) model=\(metadata.model, privacy: .public) webSearch=\(metadata.webSearch) hasImage=\(metadata.hasImage) bodyBytes=\(request.httpBody?.count ?? 0) timeout=\(Int(request.timeoutInterval))s"
        )
    }

    private static func logResponse(
        _ response: URLResponse, data: Data, metadata: Metadata, startedAt: Date
    ) {
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
        Log.ai.info(
            "← [\(metadata.purpose, privacy: .public)] \(metadata.provider.displayName, privacy: .public) model=\(metadata.model, privacy: .public) status=\(statusCode) responseBytes=\(data.count) elapsedMs=\(elapsedMs)"
        )
    }

    private static func logFailure(
        _ error: Error, metadata: Metadata, startedAt: Date
    ) {
        let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
        Log.ai.error(
            "✗ [\(metadata.purpose, privacy: .public)] \(metadata.provider.displayName, privacy: .public) model=\(metadata.model, privacy: .public) failed after \(elapsedMs)ms: \(error.localizedDescription, privacy: .public)"
        )
    }
}
