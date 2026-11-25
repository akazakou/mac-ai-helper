// TranslationLayout.swift
// Lays out a translation in the measured style of the original text: same size and weight,
// same baseline and line spacing, wrapped and shrunk only as much as needed to fit.

import AppKit
import CoreText

struct TranslationLayout {
    /// The font shrinks step by step until the translation fits.
    private static let fontShrinkStep: CGFloat = 0.93
    /// Smallest font relative to the original; a longer translation is cut with an ellipsis.
    private static let minFontScale: CGFloat = 0.6

    private let lines: [CTLine]
    private let origins: [CGPoint]
    /// Area the drawn translation occupies; covered together with the original text
    let bounds: CGRect

    init(_ text: String, style: TextBlockStyle) {
        let typesetting = Typesetting(text: text, style: style)
        var scale: CGFloat = 1
        var fitted = typesetting.wrapped(scale: scale)
        while !fitted.fits, scale * Self.fontShrinkStep >= Self.minFontScale {
            scale *= Self.fontShrinkStep
            fitted = typesetting.wrapped(scale: scale)
        }

        let font = typesetting.font(scale: scale)
        let lines = fitted.fits ? fitted.lines : typesetting.truncated(fitted, font: font)
        let firstBaseline = Self.firstBaseline(style: style, font: font)
        let pitch = style.linePitch * scale

        var origins: [CGPoint] = []
        var bounds = CGRect.null
        for (index, line) in lines.enumerated() {
            let lineWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
                - CGFloat(CTLineGetTrailingWhitespaceWidth(line))
            let originX = style.alignment == .center
                ? (style.textArea.lowerBound + style.textArea.upperBound - lineWidth) / 2
                : style.textArea.lowerBound
            let origin = CGPoint(x: originX, y: firstBaseline - CGFloat(index) * pitch)
            origins.append(origin)
            bounds = bounds.union(
                CGRect(
                    x: origin.x, y: origin.y - CTFontGetDescent(font),
                    width: lineWidth, height: CTFontGetAscent(font) + CTFontGetDescent(font)
                )
            )
        }
        self.lines = lines
        self.origins = origins
        self.bounds = bounds
    }

    func draw(in context: CGContext) {
        context.textMatrix = .identity
        for (line, origin) in zip(lines, origins) {
            context.textPosition = origin
            CTLineDraw(line, context)
        }
    }

    /// The translation keeps the original baseline; a smaller font is centered on a single line
    /// and kept at the original top in a paragraph.
    private static func firstBaseline(style: TextBlockStyle, font: CTFont) -> CGFloat {
        let originalFont = TextFont.system(size: style.fontSize, weight: style.weight)
        let capHeightDifference = CTFontGetCapHeight(originalFont) - CTFontGetCapHeight(font)
        return style.firstBaseline + (style.lineCount == 1 ? capHeightDifference / 2 : capHeightDifference)
    }

    // MARK: - Typesetting

    /// Lines of a wrapped translation, and how many fit in the original block's height.
    private struct FittedText {
        let lines: [CTLine]
        let maxLines: Int

        var fits: Bool { lines.count <= maxLines }
    }

    /// Wraps the translation into the width of the style's text area at different font scales.
    private struct Typesetting {
        private static let ellipsis = "…"

        let text: String
        let style: TextBlockStyle

        private var width: CGFloat {
            style.textArea.upperBound - style.textArea.lowerBound
        }

        func font(scale: CGFloat) -> CTFont {
            TextFont.system(size: style.fontSize * scale, weight: style.weight)
        }

        /// A smaller font fits more lines in the same height.
        func wrapped(scale: CGFloat) -> FittedText {
            let maxLines = max(Int((CGFloat(style.lineCount) / scale).rounded(.down)), 1)
            let typesetter = CTTypesetterCreateWithAttributedString(attributed(text, font: font(scale: scale)))
            let length = (text as NSString).length
            var lines: [CTLine] = []
            var start = 0
            while start < length {
                let count = max(CTTypesetterSuggestLineBreak(typesetter, start, Double(width)), 1)
                lines.append(CTTypesetterCreateLine(typesetter, CFRange(location: start, length: count)))
                start += count
            }
            return FittedText(lines: lines, maxLines: maxLines)
        }

        /// Keeps the lines that fit; the last one takes the rest of the text and ends with an ellipsis.
        func truncated(_ fitted: FittedText, font: CTFont) -> [CTLine] {
            let keptLines = Array(fitted.lines.prefix(fitted.maxLines - 1))
            let restStart = CTLineGetStringRange(fitted.lines[fitted.maxLines - 1]).location
            let rest = (text as NSString).substring(from: restStart)
            let restLine = CTLineCreateWithAttributedString(attributed(rest, font: font))
            let ellipsisLine = CTLineCreateWithAttributedString(attributed(Self.ellipsis, font: font))
            let lastLine = CTLineCreateTruncatedLine(restLine, Double(width), .end, ellipsisLine) ?? restLine
            return keptLines + [lastLine]
        }

        private func attributed(_ string: String, font: CTFont) -> NSAttributedString {
            NSAttributedString(
                string: string,
                attributes: [
                    NSAttributedString.Key(kCTFontAttributeName as String): font,
                    NSAttributedString.Key(kCTForegroundColorAttributeName as String): style.colors.text.cgColor,
                ]
            )
        }
    }
}
