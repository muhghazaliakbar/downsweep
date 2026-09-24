import AppKit

/// The app icon's glyph (arrow, sweep, specks) redrawn as a menu bar template image.
///
/// Same shapes as `scripts/render-icon-layers.swift`, cropped to the glyph and retuned for 18pt:
/// heavier strokes and larger specks, which would otherwise vanish at this size.
enum MenuBarIcon {
    static let idle = make(litSpecks: 3)

    /// While scanning, the specks light up one by one as progress moves forward.
    static func scanning(progress: Double) -> NSImage {
        scanFrames[min(Int(progress * 3), 2)]
    }

    private static let scanFrames = (1...3).map { make(litSpecks: $0) }

    private static func make(litSpecks: Int) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            guard let cg = NSGraphicsContext.current?.cgContext else { return false }
            cg.setStrokeColor(NSColor.black.cgColor)
            cg.setLineCap(.round)
            cg.setLineJoin(.round)

            // Arrow.
            cg.setLineWidth(2.1)
            cg.move(to: CGPoint(x: 8, y: 1.6))
            cg.addLine(to: CGPoint(x: 8, y: 10.2))
            cg.move(to: CGPoint(x: 4.4, y: 6.8))
            cg.addLine(to: CGPoint(x: 8, y: 10.4))
            cg.addLine(to: CGPoint(x: 11.6, y: 6.8))
            cg.strokePath()

            // Sweep.
            cg.setLineWidth(1.8)
            cg.move(to: CGPoint(x: 2.6, y: 13.4))
            cg.addQuadCurve(to: CGPoint(x: 13.2, y: 13.4), control: CGPoint(x: 7.9, y: 16.8))
            cg.strokePath()

            // Specks, largest nearest the sweep.
            let specks: [(x: Double, y: Double, r: Double)] = [(15.6, 11.7, 1.1), (16.6, 8.9, 0.9), (16.9, 6.3, 0.7)]
            for (index, speck) in specks.enumerated() {
                cg.setFillColor(NSColor.black.withAlphaComponent(index < litSpecks ? 1 : 0.3).cgColor)
                cg.fillEllipse(in: CGRect(x: speck.x - speck.r, y: speck.y - speck.r, width: speck.r * 2, height: speck.r * 2))
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Downsweep"
        return image
    }
}
