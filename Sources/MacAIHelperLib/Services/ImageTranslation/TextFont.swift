// TextFont.swift
// System fonts for redrawn text, and measurements that match them to text in an image.

import AppKit
import CoreText

enum TextFont {
    /// Size at which glyph shapes are measured; results are scaled to 1 pt.
    private static let measuringSize: CGFloat = 100
    /// Antialiased pixels this opaque count as ink, matching PixelCanvas.ink
    private static let inkAlphaFraction: CGFloat = 0.4
    /// Ink coverage of the original relative to the regular system font, from which a heavier
    /// weight is chosen. Measured on sample images: regular 0.91-0.99, medium 1.11, semibold 1.20, bold 1.33.
    private static let mediumCoverageRatio: CGFloat = 1.06
    private static let semiboldCoverageRatio: CGFloat = 1.15
    private static let boldCoverageRatio: CGFloat = 1.27

    static func system(size: CGFloat, weight: NSFont.Weight) -> CTFont {
        NSFont.systemFont(ofSize: size, weight: weight) as CTFont
    }

    /// Bounds of the glyph shapes of `text` in the regular system font at 1 pt.
    /// minY is negative when the text has descenders.
    static func glyphBounds(of text: String) -> CGRect {
        let bounds = CTLineGetBoundsWithOptions(line(text, size: measuringSize), .useGlyphPathBounds)
        return CGRect(
            x: bounds.minX / measuringSize, y: bounds.minY / measuringSize,
            width: bounds.width / measuringSize, height: max(bounds.height, 1) / measuringSize
        )
    }

    /// Weight whose strokes cover about as much of the text's bounds as the original's do.
    static func weight(matchingCoverage originalCoverage: CGFloat, of text: String, fontSize: CGFloat) -> NSFont.Weight {
        guard let regularCoverage = coverage(of: text, size: fontSize), regularCoverage > 0 else {
            return .regular
        }
        let ratio = originalCoverage / regularCoverage
        if ratio >= boldCoverageRatio { return .bold }
        if ratio >= semiboldCoverageRatio { return .semibold }
        if ratio >= mediumCoverageRatio { return .medium }
        return .regular
    }

    /// Share of the glyph bounds that the regular system font covers with ink at the given size.
    private static func coverage(of text: String, size: CGFloat) -> CGFloat? {
        let line = line(text, size: size)
        let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds).integral
        guard bounds.width > 0, bounds.height > 0,
            let context = CGContext(
                data: nil, width: Int(bounds.width), height: Int(bounds.height), bitsPerComponent: 8,
                bytesPerRow: 0, space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ),
            let data = context.data?.assumingMemoryBound(to: UInt8.self)
        else { return nil }

        context.setFillColor(gray: 1, alpha: 1)
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: -bounds.minX, y: -bounds.minY)
        // White text on black: each pixel's value is its ink coverage.
        let whiteLine = CTLineCreateWithAttributedString(
            NSAttributedString(
                string: text,
                attributes: [
                    NSAttributedString.Key(kCTFontAttributeName as String): system(size: size, weight: .regular),
                    NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 1, alpha: 1),
                ]
            )
        )
        CTLineDraw(whiteLine, context)

        let threshold = UInt8(inkAlphaFraction * 255)
        let inkPixels = (0..<context.height).reduce(0) { count, row in
            count + (0..<context.width).filter { data[row * context.bytesPerRow + $0] >= threshold }.count
        }
        return CGFloat(inkPixels) / (bounds.width * bounds.height)
    }

    private static func line(_ text: String, size: CGFloat) -> CTLine {
        CTLineCreateWithAttributedString(
            NSAttributedString(
                string: text,
                attributes: [NSAttributedString.Key(kCTFontAttributeName as String): system(size: size, weight: .regular)]
            )
        )
    }
}
