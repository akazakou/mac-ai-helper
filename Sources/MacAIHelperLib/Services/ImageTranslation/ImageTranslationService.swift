// ImageTranslationService.swift
// Translates the text inside an image and returns the image with the translation drawn in place.
// Text recognition and drawing happen on the device; only the recognized text is sent to the translator.

import CoreGraphics
import Foundation
import ImageIO

enum ImageTranslationService {
    /// Returns PNG data of the image with its text translated into `language`
    /// (a model of a translation provider).
    static func translate(
        _ imageData: Data, into language: AIModel, apiKey: String
    ) async throws -> Data {
        guard
            let translator = AIServiceRouter.service(for: language.provider)
                as? TranslationServiceProtocol
        else {
            throw AppError.imageNotSupported(language.provider)
        }

        let image = try decodedImage(from: imageData)
        let blocks = try ImageTextRecognizer.recognizeTextBlocks(in: image)
        guard !blocks.isEmpty else { throw AppError.noTextInImage }

        let translations = try await translator.translate(
            blocks.map(\.text), into: language.id, apiKey: apiKey
        )
        return try TranslatedImageRenderer.render(image, replacing: blocks, with: translations)
    }

    private static func decodedImage(from data: Data) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw AppError.imageProcessingFailed("the screenshot could not be decoded")
        }
        return image
    }
}
