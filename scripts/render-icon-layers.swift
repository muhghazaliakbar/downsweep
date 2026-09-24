// Renders the foreground layers of Downsweep's Icon Composer icon.
//
//   swift scripts/render-icon-layers.swift Downsweep/AppIcon.icon/Assets
//
// Layers are white on transparent; Icon Composer supplies the background fill,
// Liquid Glass highlights and per-appearance tinting.
import AppKit

let outputFolder = URL(filePath: CommandLine.arguments.dropFirst().first ?? ".")
let size = 1024.0

func render(_ name: String, _ draw: (CGContext) -> Void) throws {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.current = context
    let cg = context.cgContext
    // Draw in a top-left origin, like the design grid.
    cg.translateBy(x: 0, y: size)
    cg.scaleBy(x: 1, y: -1)
    cg.setStrokeColor(NSColor.white.cgColor)
    cg.setFillColor(NSColor.white.cgColor)
    cg.setLineCap(.round)
    cg.setLineJoin(.round)
    draw(cg)
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: outputFolder.appending(path: "\(name).png"))
}

try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)

// Front layer: a bold arrow pointing down.
try render("arrow") { cg in
    cg.setLineWidth(112)
    cg.move(to: CGPoint(x: 512, y: 228))
    cg.addLine(to: CGPoint(x: 512, y: 600))
    cg.move(to: CGPoint(x: 352, y: 452))
    cg.addLine(to: CGPoint(x: 512, y: 612))
    cg.addLine(to: CGPoint(x: 672, y: 452))
    cg.strokePath()
}

// Back layer: the sweep, a shallow curve under the arrow with a few specks swept aside.
try render("sweep") { cg in
    cg.setLineWidth(84)
    cg.move(to: CGPoint(x: 262, y: 742))
    cg.addQuadCurve(to: CGPoint(x: 700, y: 742), control: CGPoint(x: 481, y: 862))
    cg.strokePath()
    for (x, y, r) in [(786.0, 700.0, 30.0), (842.0, 626.0, 22.0), (866.0, 546.0, 15.0)] {
        cg.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }
}
print("Rendered layers into \(outputFolder.path)")
