// AppError.swift
// Custom error types for the application.

import Foundation

enum AppError: LocalizedError, Sendable {
    case noAPIKey(AIProvider)
    case noModelSelected
    case networkError(String)
    case apiError(statusCode: Int, message: String)
    case decodingError(String)
    case keychainError(String)
    case accessibilityPermissionDenied
    case screenCapturePermissionDenied
    case screenCaptureCancelled

    var errorDescription: String? {
        switch self {
        case .noAPIKey(let provider):
            "No API key configured for \(provider.rawValue)"
        case .noModelSelected:
            "No AI model selected"
        case .networkError(let msg):
            "Network error: \(msg)"
        case .apiError(let code, let msg):
            "API error (\(code)): \(msg)"
        case .decodingError(let msg):
            "Failed to decode response: \(msg)"
        case .keychainError(let msg):
            "Keychain error: \(msg)"
        case .accessibilityPermissionDenied:
            "Accessibility permission is required for global shortcuts"
        case .screenCapturePermissionDenied:
            "Screen recording permission is required for screenshots"
        case .screenCaptureCancelled:
            "Screenshot capture was cancelled"
        }
    }
}
