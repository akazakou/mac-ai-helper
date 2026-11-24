// TranslatedImageRenderer.swift
// Replaces text in an image: covers each text block with its background color
// and draws the translation in its place, sized to fit the block.

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum TranslatedImageRenderer {
    /// Returns the image as PNG data with every block's text replaced by its translation.
    /// `translations` must have one entry per block, in the same order.
    static func render(
        _ image: CGImage, replacing blocks: [RecognizedTextBlock], with translations: [String]
    ) throws -> Data {
        let canvas = try PixelCanvas(image: image)
        // Colors are read before anything is drawn, so one block's cover never tints its neighbor.
        let colors = blocks.map { canvas.colors(in: $0.frame) }

        for ((block, translation), blockColors) in zip(zip(blocks, translations), colors) {
            cover(block, with: blockColors.background, in: canvas.context)
            draw(translation, in: block, color: blockColors.text, context: canvas.context)
        }
        return try pngData(from: canvas.context)
    }

    // MARK: - Covering the Original Text

    /// Padding around the block, in line heights, so glyph edges outside the recognized box are covered too.
    private static let coverPadding: CGFloat = 0.12

    // ponytail: flat fill with the sampled background color; text on photos or gradients
    // gets a visible box. Inpainting would be the upgrade.
    private static func cover(_ block: RecognizedTextBlock, with color: CGColor, in context: CGContext) {
        let padding = block.lineHeight * coverPadding
        context.setFillColor(color)
        context.fill(block.frame.insetBy(dx: -padding, dy: -padding))
    }

    // MARK: - Drawing the Translation

    /// Font size relative to the height of the recognized line box.
    private static let fontSizePerLineHeight: CGFloat = 0.8
    /// The font shrinks step by step until the translation fits the block.
    private static let fontShrinkStep: CGFloat = 0.93
    /// Smallest font, relative to the starting size. Below it the text is drawn anyway and may be clipped.
    private static let minFontScale: CGFloat = 0.45
    /// CoreText suggests fractional sizes; the frame is rounded up so the last line is not dropped.
    private static let frameRounding: CGFloat = 2

    private static func draw(
        _ text: String, in block: RecognizedTextBlock, color: CGColor, context: CGContext
    ) {
        let startSize = block.lineHeight * fontSizePerLineHeight
        var fontSize = startSize
        var layout = TextLayout(text: text, fontSize: fontSize, color: color, width: block.frame.width)
        while !layout.fits(block.frame.size), fontSize > startSize * minFontScale {
            fontSize *= fontShrinkStep
            layout = TextLayout(text: text, fontSize: fontSize, color: color, width: block.frame.width)
        }

        // CoreText fills a frame from its top edge; the frame is lowered to center the text vertically.
        let height = min(layout.size.height + frameRounding, block.frame.height + frameRounding)
        let verticalSlack = max(block.frame.height - layout.size.height, 0) / 2
        let textFrame = CGRect(
            x: block.frame.minX,
            y: block.frame.maxY - verticalSlack - height,
            width: block.frame.width + frameRounding,
            height: height
        )
        layout.draw(in: textFrame, context: context)
    }

    // MARK: - PNG Encoding

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

// MARK: - Text Layout

/// A text laid out with CoreText to wrap within a given width.
private struct TextLayout {
    private let framesetter: CTFramesetter
    /// Size the wrapped text occupies
    let size: CGSize

    init(text: String, fontSize: CGFloat, color: CGColor, width: CGFloat) {
        let font = CTFontCreateUIFontForLanguage(.system, fontSize, nil)
            ?? CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
        let attributedText = NSAttributedString(
            string: text,
            attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
            ]
        )
        framesetter = CTFramesetterCreateWithAttributedString(attributedText)
        size = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter, CFRange(), nil,
            CGSize(width: width, height: .greatestFiniteMagnitude), nil
        )
    }

    func fits(_ container: CGSize) -> Bool {
        size.width <= container.width && size.height <= container.height
    }

    func draw(in frame: CGRect, context: CGContext) {
        let textFrame = CTFramesetterCreateFrame(
            framesetter, CFRange(), CGPath(rect: frame, transform: nil), nil
        )
        CTFrameDraw(textFrame, context)
    }
}

// MARK: - Pixel Canvas

/// An RGBA bitmap holding the image, used both to draw on and to read pixel colors from.
private struct PixelCanvas {
    private static let bytesPerPixel = 4
    private static let bitsPerComponent = 8
    private static let maxComponent: CGFloat = 255

    let context: CGContext
    /// Copy of the original pixels, top row first
    private let pixels: [UInt8]
    private let width: Int
    private let height: Int
    private let bytesPerRow: Int

    init(image: CGImage) throws {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil, width: image.width, height: image.height,
                bitsPerComponent: Self.bitsPerComponent, bytesPerRow: 0, space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            throw AppError.imageProcessingFailed("could not create a drawing canvas")
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let data = context.data else {
            throw AppError.imageProcessingFailed("could not read the image pixels")
        }

        self.context = context
        width = image.width
        height = image.height
        bytesPerRow = context.bytesPerRow
        pixels = Array(
            UnsafeBufferPointer(
                start: data.assumingMemoryBound(to: UInt8.self), count: bytesPerRow * image.height
            )
        )
    }

    /// Background and text colors of a text block.
    /// The background is the median color along the block's border, where text is rare.
    /// The text color is the pixel inside the block that differs most from the background.
    func colors(in frame: CGRect) -> (background: CGColor, text: CGColor) {
        let columns = clamped(frame.minX, below: width)...clamped(frame.maxX, below: width)
        let rows = clamped(frame.minY, below: height)...clamped(frame.maxY, below: height)

        let borderPixels = columns.flatMap { [pixel($0, rows.lowerBound), pixel($0, rows.upperBound)] }
            + rows.flatMap { [pixel(columns.lowerBound, $0), pixel(columns.upperBound, $0)] }
        let background = Pixel.median(of: borderPixels)

        var text = background
        var maxDistance = 0
        for row in rows {
            for column in columns {
                let candidate = pixel(column, row)
                let distance = candidate.distance(to: background)
                if distance > maxDistance {
                    maxDistance = distance
                    text = candidate
                }
            }
        }
        return (cgColor(background), cgColor(text))
    }

    /// Nearest valid pixel index for a coordinate along an axis with `limit` pixels.
    private func clamped(_ coordinate: CGFloat, below limit: Int) -> Int {
        min(max(Int(coordinate), 0), limit - 1)
    }

    /// Pixel at CoreGraphics coordinates (origin bottom-left); memory rows run top to bottom.
    private func pixel(_ column: Int, _ row: Int) -> Pixel {
        let offset = (height - 1 - row) * bytesPerRow + column * Self.bytesPerPixel
        return Pixel(red: pixels[offset], green: pixels[offset + 1], blue: pixels[offset + 2])
    }

    private func cgColor(_ pixel: Pixel) -> CGColor {
        CGColor(
            srgbRed: CGFloat(pixel.red) / Self.maxComponent,
            green: CGFloat(pixel.green) / Self.maxComponent,
            blue: CGFloat(pixel.blue) / Self.maxComponent,
            alpha: 1
        )
    }
}

private struct Pixel {
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    /// Squared color distance
    func distance(to other: Pixel) -> Int {
        let redDelta = Int(red) - Int(other.red)
        let greenDelta = Int(green) - Int(other.green)
        let blueDelta = Int(blue) - Int(other.blue)
        return redDelta * redDelta + greenDelta * greenDelta + blueDelta * blueDelta
    }

    /// Per-channel median: a few text pixels on the border do not shift it.
    static func median(of pixels: [Pixel]) -> Pixel {
        func median(_ channel: KeyPath<Pixel, UInt8>) -> UInt8 {
            pixels.map { $0[keyPath: channel] }.sorted()[pixels.count / 2]
        }
        return Pixel(red: median(\.red), green: median(\.green), blue: median(\.blue))
    }
}
