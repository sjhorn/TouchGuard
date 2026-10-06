// Renders docs/images/banner.png (1280×640): README hero and GitHub social preview.
// Usage: swift scripts/assets/make-banner.swift
import AppKit

let size = NSSize(width: 1280, height: 640)
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let icon = NSImage(contentsOf: root.appendingPathComponent("TouchGuardApp/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png"))!

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let gradient = NSGradient(colors: [NSColor(srgbRed: 0.09, green: 0.11, blue: 0.16, alpha: 1),
                                   NSColor(srgbRed: 0.16, green: 0.20, blue: 0.30, alpha: 1)])!
gradient.draw(in: NSRect(origin: .zero, size: size), angle: 315)

let iconSide: CGFloat = 300
icon.draw(in: NSRect(x: 110, y: (size.height - iconSide) / 2, width: iconSide, height: iconSide))

func draw(_ text: String, size points: CGFloat, weight: NSFont.Weight, color: NSColor, at y: CGFloat) {
    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: points, weight: weight),
                                                .foregroundColor: color]
    NSAttributedString(string: text, attributes: attrs).draw(at: NSPoint(x: 480, y: y))
}
draw("TouchGuard", size: 96, weight: .bold, color: .white, at: 330)
draw("Stop accidental trackpad clicks", size: 40, weight: .medium, color: NSColor(white: 0.88, alpha: 1), at: 262)
draw("while you type.", size: 40, weight: .medium, color: NSColor(white: 0.88, alpha: 1), at: 212)
draw("Free · Open source · Private · macOS 14+", size: 26, weight: .regular, color: NSColor(white: 0.65, alpha: 1), at: 140)

NSGraphicsContext.restoreGraphicsState()
let out = root.appendingPathComponent("docs/images/banner.png")
try! rep.representation(using: .png, properties: [:])!.write(to: out)
print("Wrote \(out.path)")
