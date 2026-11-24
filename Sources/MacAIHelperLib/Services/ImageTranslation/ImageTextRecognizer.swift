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
    /// Height of one text line in pixels, used to size the translated text
    let lineHeight: CGFloat

    init(text: String, frame: CGRect) {
        self.text = text
        self.frame = frame
        lineHeight = frame.height
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
    /// Largest gap between paragraph lines, in line heights.
    private static let maxLineGap: CGFloat = 0.8
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
        var paragraphs: [Paragraph] = []
        // The origin is bottom-left, so the topmost line has the largest maxY.
        for line in lines.sorted(by: { $0.frame.maxY > $1.frame.maxY }) {
            if let index = paragraphs.firstIndex(where: { isLine(line, continuing: $0.lastLine) }) {
                paragraphs[index].append(line)
            } else {
                paragraphs.append(Paragraph(block: line, lastLine: line))
            }
        }
        return paragraphs.map(\.block)
    }

    /// Whether `line` is the next wrapped line after `previous` in the same paragraph.
    private static func isLine(
        _ line: RecognizedTextBlock, continuing previous: RecognizedTextBlock
    ) -> Bool {
        let lineHeight = previous.lineHeight
        let endsSentence = previous.text.last.map(sentenceEndings.contains) ?? true
        let isPreviousLineWrapped = previous.text.count >= minWrappedLineLength && !endsSentence
        let hasSimilarHeight = min(lineHeight, line.lineHeight) / max(lineHeight, line.lineHeight)
            >= minLineHeightRatio
        let gap = previous.frame.minY - line.frame.maxY
        let isDirectlyBelow = gap <= maxLineGap * lineHeight && gap >= -maxLineOverlap * lineHeight
        let isLeftAligned = abs(previous.frame.minX - line.frame.minX) <= maxLeftEdgeOffset * lineHeight
        let fitsParagraphWidth = line.frame.maxX <= previous.frame.maxX + maxRightOverhang * lineHeight

        return isPreviousLineWrapped && hasSimilarHeight && isDirectlyBelow && isLeftAligned
            && fitsParagraphWidth
    }
}

/// A paragraph under construction: the merged block plus its last line,
/// which decides whether the next line belongs to it.
private struct Paragraph {
    var block: RecognizedTextBlock
    var lastLine: RecognizedTextBlock

    mutating func append(_ line: RecognizedTextBlock) {
        block.text += " " + line.text
        block.frame = block.frame.union(line.frame)
        lastLine = line
    }
}
