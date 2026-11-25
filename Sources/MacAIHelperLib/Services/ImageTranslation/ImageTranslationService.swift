// ImageTranslationService.swift
// Translates the text inside an image and returns the image with the translation drawn in place.
// Text recognition and drawing happen on the device; only the recognized text is sent to the translator.

import CoreGraphics
import Foundation
import ImageIO

struct ImageTranslationService {
    let translator: TranslationServiceProtocol
    let apiKey: String

    /// Returns PNG data of the image with its text translated into the language `languageCode`.
    func translate(_ imageData: Data, into languageCode: String) async throws -> Data {
        let image = try Self.decodedImage(from: imageData)
        let blocks = try ImageTextRecognizer.recognizeTextBlocks(in: image)
        guard !blocks.isEmpty else { throw AppError.noTextInImage }

        let translations = try await translator.translate(
            blocks.map(\.text), into: languageCode, apiKey: apiKey
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
