#!/usr/bin/env swift

import AppKit

let sizes: [(CGFloat, String)] = [
    (16, "icon_16x16"),
    (32, "icon_16x16@2x"),
    (32, "icon_32x32"),
    (64, "icon_32x32@2x"),
    (128, "icon_128x128"),
    (256, "icon_128x128@2x"),
    (256, "icon_256x256"),
    (512, "icon_256x256@2x"),
    (512, "icon_512x512"),
    (1024, "icon_512x512@2x"),
]

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.representations.forEach { image.removeRepresentation($0) }
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: size, height: size)
    image.addRepresentation(rep)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let ctx = NSGraphicsContext.current!.cgContext
    let s = size

    // Background - dark rounded rectangle
    let bgRect = CGRect(x: 0, y: 0, width: s, height: s)
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: s * 0.22, cornerHeight: s * 0.22, transform: nil)
    ctx.addPath(bgPath)
    ctx.setFillColor(CGColor(red: 0.08, green: 0.10, blue: 0.15, alpha: 1.0))
    ctx.fillPath()

    // Inner glow
    let innerRect = bgRect.insetBy(dx: s * 0.04, dy: s * 0.04)
    let innerPath = CGPath(roundedRect: innerRect, cornerWidth: s * 0.18, cornerHeight: s * 0.18, transform: nil)
    ctx.addPath(innerPath)
    ctx.setFillColor(CGColor(red: 0.10, green: 0.13, blue: 0.20, alpha: 1.0))
    ctx.fillPath()

    // Heartbeat/pulse line
    let lineWidth = s * 0.035
    ctx.setLineWidth(lineWidth)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    let midY = s * 0.50
    let pulse = CGMutablePath()

    // Flat start
    pulse.move(to: CGPoint(x: s * 0.10, y: midY))
    pulse.addLine(to: CGPoint(x: s * 0.28, y: midY))

    // First small dip
    pulse.addLine(to: CGPoint(x: s * 0.32, y: midY + s * 0.04))
    pulse.addLine(to: CGPoint(x: s * 0.35, y: midY))

    // Big spike up
    pulse.addLine(to: CGPoint(x: s * 0.42, y: midY - s * 0.28))

    // Big dip down
    pulse.addLine(to: CGPoint(x: s * 0.50, y: midY + s * 0.18))

    // Recovery spike
    pulse.addLine(to: CGPoint(x: s * 0.56, y: midY - s * 0.10))
    pulse.addLine(to: CGPoint(x: s * 0.62, y: midY))

    // Small bump
    pulse.addLine(to: CGPoint(x: s * 0.68, y: midY - s * 0.04))
    pulse.addLine(to: CGPoint(x: s * 0.72, y: midY))

    // Flat end
    pulse.addLine(to: CGPoint(x: s * 0.90, y: midY))

    // Green glow (shadow)
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: s * 0.06, color: CGColor(red: 0.2, green: 0.9, blue: 0.4, alpha: 0.8))
    ctx.addPath(pulse)
    ctx.setStrokeColor(CGColor(red: 0.2, green: 0.9, blue: 0.4, alpha: 1.0))
    ctx.strokePath()
    ctx.restoreGState()

    // Main green line
    ctx.addPath(pulse)
    ctx.setStrokeColor(CGColor(red: 0.3, green: 1.0, blue: 0.5, alpha: 1.0))
    ctx.strokePath()

    NSGraphicsContext.restoreGraphicsState()
    return image
}

// Output directory
let iconsetPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.appiconset"
let fm = FileManager.default
try? fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

// Generate all sizes
for (size, name) in sizes {
    let image = drawIcon(size: size)
    guard let rep = image.representations.first as? NSBitmapImageRep,
          let png = rep.representation(using: .png, properties: [:]) else {
        print("Failed to generate \(name)")
        continue
    }
    let path = "\(iconsetPath)/\(name).png"
    try! png.write(to: URL(fileURLWithPath: path))
    print("Generated \(name).png (\(Int(size))x\(Int(size)))")
}

// Generate Contents.json
let contents = """
{
  "images" : [
    { "filename" : "icon_16x16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16x16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32x32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32x32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128x128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""
try! contents.write(toFile: "\(iconsetPath)/Contents.json", atomically: true, encoding: .utf8)
print("Generated Contents.json")
print("Done!")
