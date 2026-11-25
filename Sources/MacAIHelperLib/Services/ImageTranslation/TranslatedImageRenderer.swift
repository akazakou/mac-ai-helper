// TranslatedImageRenderer.swift
// Replaces text in an image: measures how each text block looks, covers it with its background
// and draws the translation in its place in a matching size, weight, color and alignment.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum TranslatedImageRenderer {
    /// Padding around covered text, in font sizes, so antialiased glyph edges are covered too.
    private static let coverPaddingInFontSizes: CGFloat = 0.1

    /// Returns the image as PNG data with every block's text replaced by its translation.
    /// `translations` must have one entry per block, in the same order.
    static func render(
        _ image: CGImage, replacing blocks: [RecognizedTextBlock], with translations: [String]
    ) throws -> Data {
        let canvas = try PixelCanvas(image: image)
        // Everything is measured on the original pixels before any block is covered.
        let styles = blocks.map { TextBlockStyle.measure($0, on: canvas) }
        let layouts = zip(translations, styles).map { TranslationLayout($0, style: $1) }

        // All covers go first, so no cover can hide a translation drawn next to it.
        for (style, layout) in zip(styles, layouts) {
            let padding = style.fontSize * coverPaddingInFontSizes
            canvas.cover(
                style.originalTextBounds.union(layout.bounds).insetBy(dx: -padding, dy: -padding),
                colors: style.colors
            )
        }
        for layout in layouts {
            layout.draw(in: canvas.context)
        }
        return try pngData(from: canvas.context)
    }

    private static func pngData(from context: CGContext) throws -> Data {
        let data = NSMutableData()
        guard let image = context.makeImage(),
            let destination = CGImageDestinationCreateWithData(
                data, UTType.png.identifier as CFString, 1, nil
            )
        else {
            throw AppError.imageProcessingFailed("could not create the translated image")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw AppError.imageProcessingFailed("could not encode the translated image as PNG")
        }
        return data as Data
    }
}
