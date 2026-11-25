// PixelCanvas.swift
// An RGBA bitmap holding the image: it is drawn on, and a copy of the original pixels
// answers questions about the text in it (colors, ink extents, free space around it).

import CoreGraphics

struct PixelCanvas {
    private static let bytesPerPixel = 4
    private static let bitsPerComponent = 8
    private static let opaqueAlpha: UInt8 = 255

    /// A pixel counts as ink when its distance to the background is at least this part
    /// of the text color's distance (antialiased glyph edges are lighter than the stroke).
    private static let inkContrastFraction = 0.4
    /// Neighboring background pixels differ by at most this much, even in a gradient;
    /// glyph and border edges change faster.
    private static let smoothnessTolerance = 20
    /// Antialiased glyph edges just outside the measured ink, skipped before free space is scanned
    private static let glyphFringeWidth = 2
    /// Columns sampled on each side of a covered area to get its edge color
    private static let edgeSampleWidth = 3

    let context: CGContext
    let width: Int
    let height: Int
    /// Copy of the original pixels, top row first
    private let pixels: [UInt8]
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

    // MARK: - Colors

    /// Median color along the border of the frame, where text is rare.
    func backgroundColor(around frame: CGRect) -> Pixel {
        let area = pixelArea(of: frame)
        let borderPixels =
            area.columns.flatMap { [pixel($0, area.rows.lowerBound), pixel($0, area.rows.upperBound)] }
            + area.rows.flatMap { [pixel(area.columns.lowerBound, $0), pixel(area.columns.upperBound, $0)] }
        return Pixel.median(of: borderPixels)
    }

    /// The pixel inside the frame that differs most from the background: the text stroke color.
    func textColor(in frame: CGRect, background: Pixel) -> Pixel {
        let area = pixelArea(of: frame)
        var text = background
        var maxDistance = 0
        for row in area.rows {
            for column in area.columns {
                let candidate = pixel(column, row)
                let distance = candidate.distance(to: background)
                if distance > maxDistance {
                    maxDistance = distance
                    text = candidate
                }
            }
        }
        return text
    }

    // MARK: - Ink

    /// Exact extent of the text strokes inside the frame, and how many pixels they cover.
    /// Nil when the frame holds no pixel of the text color.
    func ink(in frame: CGRect, colors: TextColors) -> InkMeasurement? {
        let area = pixelArea(of: frame)
        let threshold = Int(Double(colors.text.distance(to: colors.background)) * Self.inkContrastFraction
            * Self.inkContrastFraction)
        var bounds: (minColumn: Int, maxColumn: Int, minRow: Int, maxRow: Int)?
        var pixelCount = 0
        for row in area.rows {
            for column in area.columns where pixel(column, row).distance(to: colors.background) >= threshold {
                pixelCount += 1
                bounds = (
                    min(bounds?.minColumn ?? column, column), max(bounds?.maxColumn ?? column, column),
                    min(bounds?.minRow ?? row, row), max(bounds?.maxRow ?? row, row)
                )
            }
        }
        guard let bounds else { return nil }
        let rect = CGRect(
            x: bounds.minColumn, y: bounds.minRow,
            width: bounds.maxColumn - bounds.minColumn + 1, height: bounds.maxRow - bounds.minRow + 1
        )
        return InkMeasurement(bounds: rect, pixelCount: pixelCount)
    }

    /// Number of background-only columns next to the ink `rect`, scanning left or right, up to `limit`.
    /// Background may change gradually (a gradient); the scan stops at a sharp change: other text,
    /// an icon, a button border. `isBounded` tells whether it stopped there rather than at the
    /// limit or the image edge.
    func freeSpace(beside rect: CGRect, toTheRight: Bool, colors: TextColors, limit: Int) -> FreeSpace {
        let area = pixelArea(of: rect)
        let step = toTheRight ? 1 : -1
        let start = (toTheRight ? area.columns.upperBound : area.columns.lowerBound)
            + step * (Self.glyphFringeWidth + 1)
        guard (0..<width).contains(start) else { return FreeSpace(width: 0, isBounded: false) }
        guard area.rows.allSatisfy({ !looksLikeText(pixel(start, $0), colors: colors) }) else {
            return FreeSpace(width: 0, isBounded: true)
        }

        var freeColumns = Self.glyphFringeWidth + 1
        var column = start + step
        while freeColumns < limit, (0..<width).contains(column) {
            let previous = column - step
            let isSmooth = area.rows.allSatisfy {
                isClose(pixel(column, $0), to: pixel(previous, $0), tolerance: Self.smoothnessTolerance)
            }
            guard isSmooth else { return FreeSpace(width: freeColumns, isBounded: true) }
            freeColumns += 1
            column += step
        }
        return FreeSpace(width: freeColumns, isBounded: false)
    }

    // MARK: - Covering

    // ponytail: each row is filled with a blend of its left and right edge colors, which hides text
    // on flat colors and gradients; photos still show a smoothed patch. Inpainting would be the upgrade.
    /// Paints over the rect with the background, following color changes along its edges.
    /// An edge sample that looks like text or other content touching the rect is replaced by `colors.background`.
    func cover(_ rect: CGRect, colors: TextColors) {
        guard let data = context.data?.assumingMemoryBound(to: UInt8.self) else { return }
        let area = pixelArea(of: rect)
        let columnSpan = CGFloat(max(area.columns.count - 1, 1))
        for row in area.rows {
            let left = edgeColor(row: row, beside: area.columns.lowerBound, step: -1, colors: colors)
            let right = edgeColor(row: row, beside: area.columns.upperBound, step: 1, colors: colors)
            for column in area.columns {
                let color = left.blended(with: right, fraction: CGFloat(column - area.columns.lowerBound) / columnSpan)
                let offset = memoryOffset(column, row)
                data[offset] = color.red
                data[offset + 1] = color.green
                data[offset + 2] = color.blue
                data[offset + 3] = Self.opaqueAlpha
            }
        }
    }

    /// Background color just outside the rect in this row. A gradient is followed;
    /// an uneven sample (glyph or icon edge) or one closer to the text color is not trusted.
    private func edgeColor(row: Int, beside column: Int, step: Int, colors: TextColors) -> Pixel {
        let samples = (1...Self.edgeSampleWidth)
            .map { column + $0 * step }
            .filter { (0..<width).contains($0) }
            .map { pixel($0, row) }
        guard let first = samples.first else { return colors.background }
        let sample = Pixel.median(of: samples)
        let isSmooth = samples.allSatisfy { isClose($0, to: first, tolerance: Self.smoothnessTolerance) }
        return isSmooth && !looksLikeText(sample, colors: colors) ? sample : colors.background
    }

    /// Closer to the text color than to the background (glyphs of this or a neighboring text)
    private func looksLikeText(_ pixel: Pixel, colors: TextColors) -> Bool {
        pixel.distance(to: colors.text) < pixel.distance(to: colors.background)
    }

    private func isClose(_ pixel: Pixel, to other: Pixel, tolerance: Int) -> Bool {
        pixel.distance(to: other) <= tolerance * tolerance
    }

    // MARK: - Pixel Access

    /// Pixel rows and columns covered by a rect, clamped to the image
    private func pixelArea(of rect: CGRect) -> (columns: ClosedRange<Int>, rows: ClosedRange<Int>) {
        (
            clamped(rect.minX, below: width)...clamped(rect.maxX - 1, below: width),
            clamped(rect.minY, below: height)...clamped(rect.maxY - 1, below: height)
        )
    }

    /// Nearest valid pixel index for a coordinate along an axis with `limit` pixels.
    private func clamped(_ coordinate: CGFloat, below limit: Int) -> Int {
        min(max(Int(coordinate.rounded(.down)), 0), limit - 1)
    }

    /// Original pixel at CoreGraphics coordinates (origin bottom-left)
    private func pixel(_ column: Int, _ row: Int) -> Pixel {
        let offset = memoryOffset(column, row)
        return Pixel(red: pixels[offset], green: pixels[offset + 1], blue: pixels[offset + 2])
    }

    /// Memory rows run top to bottom, CoreGraphics rows bottom to top.
    private func memoryOffset(_ column: Int, _ row: Int) -> Int {
        (height - 1 - row) * bytesPerRow + column * Self.bytesPerPixel
    }
}

// MARK: - Measurements

struct TextColors {
    let text: Pixel
    let background: Pixel
}

struct InkMeasurement {
    /// Smallest rect holding every ink pixel
    let bounds: CGRect
    let pixelCount: Int

    /// Share of the bounds covered by ink; heavier fonts cover more
    var coverage: CGFloat {
        CGFloat(pixelCount) / max(bounds.width * bounds.height, 1)
    }
}

struct FreeSpace {
    let width: Int
    let isBounded: Bool
}

struct Pixel: Equatable {
    private static let maxComponent: CGFloat = 255

    let red: UInt8
    let green: UInt8
    let blue: UInt8

    var cgColor: CGColor {
        CGColor(
            srgbRed: CGFloat(red) / Self.maxComponent,
            green: CGFloat(green) / Self.maxComponent,
            blue: CGFloat(blue) / Self.maxComponent,
            alpha: 1
        )
    }

    /// Squared color distance
    func distance(to other: Pixel) -> Int {
        let redDelta = Int(red) - Int(other.red)
        let greenDelta = Int(green) - Int(other.green)
        let blueDelta = Int(blue) - Int(other.blue)
        return redDelta * redDelta + greenDelta * greenDelta + blueDelta * blueDelta
    }

    /// Linear blend: fraction 0 gives this color, 1 gives `other`.
    func blended(with other: Pixel, fraction: CGFloat) -> Pixel {
        func blend(_ channel: KeyPath<Pixel, UInt8>) -> UInt8 {
            let start = CGFloat(self[keyPath: channel])
            let end = CGFloat(other[keyPath: channel])
            return UInt8((start + (end - start) * fraction).rounded())
        }
        return Pixel(red: blend(\.red), green: blend(\.green), blue: blend(\.blue))
    }

    /// Per-channel median: a few text pixels on the border do not shift it.
    static func median(of pixels: [Pixel]) -> Pixel {
        func median(_ channel: KeyPath<Pixel, UInt8>) -> UInt8 {
            pixels.map { $0[keyPath: channel] }.sorted()[pixels.count / 2]
        }
        return Pixel(red: median(\.red), green: median(\.green), blue: median(\.blue))
    }
}
