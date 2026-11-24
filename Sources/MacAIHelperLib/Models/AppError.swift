// AppError.swift
// Custom error types for the application.

import Foundation

public enum AppError: LocalizedError, Sendable {
    case noAPIKey(AIProvider)
    case noModelSelected
    case modelUnavailable(String)
    case imageNotSupported(AIProvider)
    case noTextInImage
    case imageProcessingFailed(String)
    case networkError(String)
    case apiError(statusCode: Int, message: String)
    case decodingError(String)
    case keyStoreError(String)
    case updateFailed(String)
    case accessibilityPermissionDenied
    case screenCapturePermissionDenied
    case screenCaptureCancelled

    public var errorDescription: String? {
        switch self {
        case .noAPIKey(let provider):
            "No API key configured for \(provider.rawValue)"
        case .noModelSelected:
            "No AI model selected for this prompt. Choose one in Settings → Prompts."
        case .modelUnavailable(let modelName):
            "Model \"\(modelName)\" is no longer available. Choose another model for this prompt in Settings → Prompts."
        case .imageNotSupported(let provider):
            "\(provider.rawValue) works with text only. Pick an AI model prompt for screenshots."
        case .noTextInImage:
            "No text was found in the screenshot."
        case .imageProcessingFailed(let msg):
            "Failed to process the image: \(msg)"
        case .networkError(let msg):
            "Network error: \(msg)"
        case .apiError(let code, let msg):
            "API error (\(code)): \(msg)"
        case .decodingError(let msg):
            "Failed to decode response: \(msg)"
        case .keyStoreError(let msg):
            "API key storage error: \(msg)"
        case .updateFailed(let msg):
            "Update failed: \(msg)"
        case .accessibilityPermissionDenied:
            "Accessibility permission is required for global shortcuts"
        case .screenCapturePermissionDenied:
            "Screen recording permission is required for screenshots"
        case .screenCaptureCancelled:
            "Screenshot capture was cancelled"
        }
    }
}
