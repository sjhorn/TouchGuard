// Renders App Store screenshots (2880×1800) into build/appstore-screenshots:
// a caption over the banner gradient, with one 2× capture of the App Store
// build from docs/app-store/captures (no Sparkle "Check for Updates…" item).
// Usage: swift scripts/assets/make-appstore-screenshots.swift
import AppKit

let canvas = NSSize(width: 2880, height: 1800)
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let outDir = root.appendingPathComponent("build/appstore-screenshots")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

struct Shot { let file: String; let title: String; let subtitle: String; let image: String; let scale: CGFloat }
let shots = [
    Shot(file: "1-menu", title: "Stop accidental trackpad taps",
         subtitle: "Clicks are held back for a moment after each key you release.", image: "menu.png", scale: 2),
    Shot(file: "2-delay", title: "Tune it to your typing",
         subtitle: "Choose 50–1000 ms. Changes apply instantly.", image: "custom-delay.png", scale: 1.8),
    Shot(file: "3-private", title: "Private by design",
         subtitle: "TouchGuard never reads, records or sends what you type.", image: "onboarding.png", scale: 1.3),
]

func draw(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, centerY: CGFloat) {
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight),
                                                .foregroundColor: color, .paragraphStyle: style]
    let string = NSAttributedString(string: text, attributes: attrs)
    let height = string.size().height
    string.draw(in: NSRect(x: 0, y: centerY - height / 2, width: canvas.width, height: height))
}

for shot in shots {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(canvas.width), pixelsHigh: Int(canvas.height),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    context.imageInterpolation = .high
    NSGraphicsContext.current = context

    NSGradient(colors: [NSColor(srgbRed: 0.09, green: 0.11, blue: 0.16, alpha: 1),
                        NSColor(srgbRed: 0.16, green: 0.20, blue: 0.30, alpha: 1)])!
        .draw(in: NSRect(origin: .zero, size: canvas), angle: 315)

    draw(shot.title, size: 120, weight: .bold, color: .white, centerY: 1560)
    draw(shot.subtitle, size: 56, weight: .medium, color: NSColor(white: 0.8, alpha: 1), centerY: 1410)

    let image = NSImage(contentsOf: root.appendingPathComponent("docs/app-store/captures/\(shot.image)"))!
    // Captures are 2×: NSImage reports point size from the PNG's DPI, so use pixels.
    let pixels = image.representations.first.map { NSSize(width: $0.pixelsWide, height: $0.pixelsHigh) } ?? image.size
    let size = NSSize(width: pixels.width * shot.scale, height: pixels.height * shot.scale)
    let frame = NSRect(x: (canvas.width - size.width) / 2, y: (1260 - size.height) / 2 + 40, width: size.width, height: size.height)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(white: 0, alpha: 0.5)
    shadow.shadowBlurRadius = 60
    shadow.shadowOffset = NSSize(width: 0, height: -20)
    shadow.set()
    let clip = NSBezierPath(roundedRect: frame, xRadius: 24 * shot.scale, yRadius: 24 * shot.scale)
    NSColor.black.setFill()
    clip.fill()
    NSShadow().set()
    NSGraphicsContext.current?.saveGraphicsState()
    clip.addClip()
    image.draw(in: frame)
    NSGraphicsContext.current?.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()
    // App Store screenshots must not have an alpha channel: write a JPEG.
    let out = outDir.appendingPathComponent("\(shot.file).jpg")
    try! rep.representation(using: .jpeg, properties: [.compressionFactor: 0.92])!.write(to: out)
    print("Wrote \(out.path)")
}
