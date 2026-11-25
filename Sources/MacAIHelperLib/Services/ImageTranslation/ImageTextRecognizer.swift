// ImageTextRecognizer.swift
// Finds text in an image on the device (Apple Vision) and groups wrapped lines into paragraphs,
// so a sentence broken across lines is translated as a whole.

import CoreGraphics
import Vision

/// A piece of text found in an image: a single line or a paragraph of wrapped lines.
struct RecognizedTextBlock: Sendable, Equatable {
    var text: String
    /// Bounding box in image pixels, origin in the bottom-left corner
    var frame: CGRect
    /// Text of the first line; with its frame it gives the font size and baseline of the block
    let firstLineText: String
    /// Bounding box of the first line
    let firstLineFrame: CGRect
    /// Text of the last line; it decides whether the next line continues the paragraph
    private(set) var lastLineText: String
    /// Bounding box of the last line; with the first one it gives the line spacing
    private(set) var lastLineFrame: CGRect
    private(set) var lineCount = 1

    init(text: String, frame: CGRect) {
        self.text = text
        self.frame = frame
        firstLineText = text
        firstLineFrame = frame
        lastLineText = text
        lastLineFrame = frame
    }

    /// Adds the next wrapped line. A word hyphenated across the lines is joined back together.
    mutating func append(_ line: RecognizedTextBlock) {
        let isHyphenated = lastLineText.last == "-" && line.text.first?.isLowercase == true
        text = isHyphenated ? String(text.dropLast()) + line.text : text + " " + line.text
        frame = frame.union(line.frame)
        lastLineText = line.text
        lastLineFrame = line.frame
        lineCount += 1
    }

    /// Height of one text line in pixels
    var lineHeight: CGFloat {
        firstLineFrame.height
    }

    /// Distance between the baselines of neighboring lines, nil for a single line
    var linePitch: CGFloat? {
        guard lineCount > 1 else { return nil }
        return (firstLineFrame.midY - lastLineFrame.midY) / CGFloat(lineCount - 1)
    }
}

enum ImageTextRecognizer {
    /// Icons and other graphics misread as text score below this; real words score higher.
    private static let minConfidence: Float = 0.4

    /// Recognizes text in the image. The image never leaves the device.
    static func recognizeTextBlocks(in image: CGImage) throws -> [RecognizedTextBlock] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.automaticallyDetectsLanguage = true
        request.usesLanguageCorrection = true
        try VNImageRequestHandler(cgImage: image).perform([request])

        let lines = (request.results ?? []).compactMap { observation -> RecognizedTextBlock? in
            // Text without letters (numbers, bullets, misread icons) needs no translation and stays as is.
            guard let candidate = observation.topCandidates(1).first,
                candidate.confidence >= minConfidence,
                candidate.string.contains(where: \.isLetter)
            else { return nil }
            let frame = VNImageRectForNormalizedRect(observation.boundingBox, image.width, image.height)
            return RecognizedTextBlock(text: candidate.string, frame: frame)
        }
        return groupedIntoParagraphs(lines)
    }

    // MARK: - Paragraph Grouping

    /// A line shorter than this is treated as a label (menu item, button), not as a wrapped paragraph line.
    private static let minWrappedLineLength = 20
    /// Lines of one paragraph have about the same height (ratio of the smaller to the larger).
    private static let minLineHeightRatio: CGFloat = 0.75
    /// Largest gap between paragraph lines, in line heights. Wider gaps separate a heading from its text.
    private static let maxLineGap: CGFloat = 0.55
    /// Deepest overlap of neighboring lines, in line heights.
    private static let maxLineOverlap: CGFloat = 0.3
    /// How far left edges of paragraph lines may differ, in line heights.
    private static let maxLeftEdgeOffset: CGFloat = 1
    /// How far the next line may stick out to the right of a wrapped line, in line heights.
    private static let maxRightOverhang: CGFloat = 2
    private static let sentenceEndings: Set<Character> = [".", "!", "?", ":", ";", "。", "！", "？"]

    // ponytail: geometric heuristic, O(n²) over lines. RecognizeDocumentsRequest (macOS 26)
    // returns real paragraphs; switch to it once the deployment target allows.
    /// Joins lines that continue each other into paragraphs. Stand-alone lines stay as they are.
    static func groupedIntoParagraphs(_ lines: [RecognizedTextBlock]) -> [RecognizedTextBlock] {
        var paragraphs: [RecognizedTextBlock] = []
        // The origin is bottom-left, so the topmost line has the largest maxY.
        for line in lines.sorted(by: { $0.frame.maxY > $1.frame.maxY }) {
            if let index = paragraphs.firstIndex(where: { isLine(line, continuing: $0) }) {
                paragraphs[index].append(line)
            } else {
                paragraphs.append(line)
            }
        }
        return paragraphs
    }

    /// Whether `line` is the next wrapped line after the last line of `paragraph`.
    private static func isLine(
        _ line: RecognizedTextBlock, continuing paragraph: RecognizedTextBlock
    ) -> Bool {
        let previous = paragraph.lastLineFrame
        let lineHeight = previous.height
        let previousText = paragraph.lastLineText
        let endsSentence = previousText.last.map(sentenceEndings.contains) ?? true
        let isPreviousLineWrapped = previousText.count >= minWrappedLineLength && !endsSentence
        let hasSimilarHeight = min(lineHeight, line.lineHeight) / max(lineHeight, line.lineHeight)
            >= minLineHeightRatio
        let gap = previous.minY - line.frame.maxY
        let isDirectlyBelow = gap <= maxLineGap * lineHeight && gap >= -maxLineOverlap * lineHeight
        let isLeftAligned = abs(previous.minX - line.frame.minX) <= maxLeftEdgeOffset * lineHeight
        let fitsParagraphWidth = line.frame.maxX <= previous.maxX + maxRightOverhang * lineHeight

        return isPreviousLineWrapped && hasSimilarHeight && isDirectlyBelow && isLeftAligned
            && fitsParagraphWidth
    }
}
