// ModelAvailability.swift
// Describes whether a prompt's saved model can currently be used.

import Foundation

public enum ModelAvailability: Sendable {
    /// The prompt has no model assigned
    case notSelected
    /// Provider model lists are still being fetched
    case loading
    /// The model is present in the fetched models list
    case available
    /// The provider list loaded, but no longer contains this model
    case outdated
    /// The provider's models list could not be loaded (missing or invalid API key, network error)
    case providerLoadFailed

    /// Whether the model should be highlighted as a problem in the UI
    var isError: Bool {
        self == .outdated || self == .providerLoadFailed
    }

    /// User-facing explanation of the problem, if any.
    func warningMessage(for model: AIModel?) -> String? {
        switch self {
        case .outdated:
            "This model is no longer available. Select another model for this prompt."
        case .providerLoadFailed:
            model.map {
                "Can't load the \($0.provider.rawValue) models list. "
                    + "Check your API key or replace it in the API Keys tab."
            }
        case .notSelected, .loading, .available:
            nil
        }
    }
}
