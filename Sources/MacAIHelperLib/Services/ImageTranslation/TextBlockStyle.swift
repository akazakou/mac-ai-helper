// TextBlockStyle.swift
// Measures how a text block looks in the original image (size, weight, colors, baseline,
// alignment, free space around it), so its translation can be drawn to match.

import AppKit
import CoreText

struct TextBlockStyle {
    enum Alignment {
        case leading
        case center
    }

    let colors: TextColors
    /// Font size in image pixels
    let fontSize: CGFloat
    let weight: NSFont.Weight
    /// Baseline of the first line
    let firstBaseline: CGFloat
    /// Distance between baselines of neighboring lines
    let linePitch: CGFloat
    let lineCount: Int
    let alignment: Alignment
    /// Horizontal range the translation may use: the original text plus free space next to it
    let textArea: ClosedRange<CGFloat>
    /// Pixels of the original text; covered before the translation is drawn
    let originalTextBounds: CGRect

    // MARK: - Measuring

    /// Search area around Vision's boxes, in line heights; the boxes sometimes clip glyph edges.
    private static let searchPadding: CGFloat = 0.15
    /// Below this squared color distance between text and background, pixels can't be measured.
    private static let minContrast = 30 * 30
    /// Guard against a wrong measurement: the font size stays within this range of line heights.
    private static let fontSizeRange: ClosedRange<CGFloat> = 0.5...1.5
    /// Free space is scanned up to this many font sizes away from the text.
    private static let maxFreeSpaceInFontSizes: CGFloat = 6
    /// Gap kept between a translation and neighboring content, in font sizes.
    private static let marginInFontSizes: CGFloat = 0.3
    /// Free space on both sides may differ by this share of their sum for the text to count as centered.
    private static let centeringTolerance: CGFloat = 0.2
    /// Centered text has at least this much padding on each side (a button, a tab), in font sizes.
    private static let minCenteringPaddingInFontSizes: CGFloat = 0.25
    /// Line spacing assumed for a single line, in font sizes
    private static let defaultLineSpacing: CGFloat = 1.2
    /// Without measurable pixels: font size and baseline height relative to Vision's line box
    private static let estimatedFontSizePerLineHeight: CGFloat = 0.8
    private static let estimatedBaselinePerLineHeight: CGFloat = 0.25

    /// Measures the block on the original pixels of `canvas`.
    static func measure(_ block: RecognizedTextBlock, on canvas: PixelCanvas) -> TextBlockStyle {
        let background = canvas.backgroundColor(around: block.frame)
        let colors = TextColors(
            text: canvas.textColor(in: block.frame, background: background), background: background
        )
        let padding = block.lineHeight * searchPadding
        guard colors.text.distance(to: colors.background) >= minContrast,
            let blockInk = canvas.ink(in: block.frame.insetBy(dx: -padding, dy: -padding), colors: colors),
            let lineInk = canvas.ink(
                in: block.firstLineFrame.insetBy(dx: -padding, dy: -padding), colors: colors
            )
        else {
            return estimated(block, colors: colors)
        }

        let glyphBounds = TextFont.glyphBounds(of: block.firstLineText)
        let plausibleSizes =
            block.lineHeight * fontSizeRange.lowerBound...block.lineHeight * fontSizeRange.upperBound
        let fontSize = (lineInk.bounds.height / glyphBounds.height).clamped(to: plausibleSizes)
        let placement = textPlacement(
            block: block, lineInk: lineInk.bounds, blockInk: blockInk.bounds,
            context: PlacementContext(canvas: canvas, colors: colors, fontSize: fontSize)
        )

        return TextBlockStyle(
            colors: colors,
            fontSize: fontSize,
            weight: TextFont.weight(
                matchingCoverage: lineInk.coverage, of: block.firstLineText, fontSize: fontSize
            ),
            // Glyph bounds start below the baseline for descenders (negative minY).
            firstBaseline: lineInk.bounds.minY - glyphBounds.minY * fontSize,
            linePitch: block.linePitch ?? fontSize * defaultLineSpacing,
            lineCount: block.lineCount,
            alignment: placement.alignment,
            textArea: placement.textArea,
            originalTextBounds: blockInk.bounds
        )
    }

    /// Style from Vision's boxes alone, for text whose pixels can't be told from the background.
    private static func estimated(_ block: RecognizedTextBlock, colors: TextColors) -> TextBlockStyle {
        let fontSize = block.lineHeight * estimatedFontSizePerLineHeight
        return TextBlockStyle(
            colors: colors,
            fontSize: fontSize,
            weight: .regular,
            firstBaseline: block.firstLineFrame.minY + block.lineHeight * estimatedBaselinePerLineHeight,
            linePitch: block.linePitch ?? fontSize * defaultLineSpacing,
            lineCount: block.lineCount,
            alignment: .leading,
            textArea: block.frame.minX...block.frame.maxX,
            originalTextBounds: block.frame
        )
    }

    // MARK: - Alignment and Free Space

    private struct PlacementContext {
        let canvas: PixelCanvas
        let colors: TextColors
        let fontSize: CGFloat
    }

    /// A single line with equal free space on both sides up to other content (a button, a tab)
    /// is centered. Otherwise the text is left-aligned and may grow into the free space on its right.
    private static func textPlacement(
        block: RecognizedTextBlock, lineInk: CGRect, blockInk: CGRect, context: PlacementContext
    ) -> (alignment: Alignment, textArea: ClosedRange<CGFloat>) {
        guard block.lineCount == 1 else {
            return (.leading, blockInk.minX...blockInk.maxX)
        }

        let limit = Int(context.fontSize * maxFreeSpaceInFontSizes)
        let left = context.canvas.freeSpace(
            beside: lineInk, toTheRight: false, colors: context.colors, limit: limit
        )
        let right = context.canvas.freeSpace(
            beside: lineInk, toTheRight: true, colors: context.colors, limit: limit
        )
        let margin = context.fontSize * marginInFontSizes
        let hasPadding = CGFloat(min(left.width, right.width))
            >= context.fontSize * minCenteringPaddingInFontSizes
        let isCentered = left.isBounded && right.isBounded && hasPadding
            && CGFloat(abs(left.width - right.width)) <= centeringTolerance * CGFloat(left.width + right.width)

        if isCentered {
            let extra = max(CGFloat(min(left.width, right.width)) - margin, 0)
            return (.center, (lineInk.minX - extra)...(lineInk.maxX + extra))
        }
        return (.leading, lineInk.minX...(lineInk.maxX + max(CGFloat(right.width) - margin, 0)))
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
