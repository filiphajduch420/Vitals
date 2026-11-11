import AppKit

/// How the battery item is drawn in the menu bar.
enum BatteryStyle: String, CaseIterable, Identifiable, Sendable {
    /// SF Symbol battery icon followed by the percentage (the original style).
    case icon
    /// The values drawn inside a battery shape, e.g. "6:28 · 95%".
    case capsule

    var id: String { rawValue }

    var label: String {
        switch self {
        case .icon:    return String(localized: "Icon")
        case .capsule: return String(localized: "Capsule")
        }
    }
}

/// Draws the battery capsule for the menu bar: a filled battery body with a
/// small terminal on the right and the text cut out of it, so the menu bar
/// shows through the letters.
///
/// The image is a template, so macOS tints it like any other menu bar icon
/// (dark on a light menu bar, light on a dark one). Low battery (20 % or less,
/// on battery power) is drawn in red instead.
enum BatteryCapsule {
    static func image(percentage: Int, timeRemaining: TimeInterval?, isCharging: Bool, isPluggedIn: Bool) -> NSImage {
        var text = "\(percentage)%"
        if let time = timeRemaining, time > 0 {
            text = "\(clock(time)) · " + text
        }

        let font = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .bold)
        let textSize = (text as NSString).size(withAttributes: [.font: font])

        // Charging → bolt; on power but not charging (full, or paused by
        // Optimized Charging) → plug, like the macOS battery menu.
        let glyph: NSImage? = {
            let name = isCharging ? "bolt.fill" : (isPluggedIn ? "powerplug.portrait.fill" : nil)
            guard let name else { return nil }
            let config = NSImage.SymbolConfiguration(pointSize: 9, weight: .bold)
            return (NSImage(systemSymbolName: name, accessibilityDescription: nil)
                ?? NSImage(systemSymbolName: "powerplug.fill", accessibilityDescription: nil))?
                .withSymbolConfiguration(config)
        }()
        let boltWidth: CGFloat = glyph.map { ceil($0.size.width) + 2 } ?? 0
        let padding: CGFloat = 5
        let bodyHeight: CGFloat = 15
        let bodyWidth = ceil(padding + boltWidth + textSize.width + padding)
        let nubWidth: CGFloat = 2.5
        let size = NSSize(width: bodyWidth + 1 + nubWidth, height: bodyHeight)

        let isLow = percentage <= 20 && !isCharging && !isPluggedIn

        let image = NSImage(size: size, flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let fill: NSColor = isLow ? .systemRed : .black

            // Body
            let body = NSRect(x: 0, y: 0, width: bodyWidth, height: bodyHeight)
            fill.setFill()
            NSBezierPath(roundedRect: body, xRadius: 4.5, yRadius: 4.5).fill()

            // Terminal (the little nub on the right)
            let nub = NSRect(x: bodyWidth + 1, y: bodyHeight / 2 - 3, width: nubWidth, height: 6)
            fill.setFill()
            NSBezierPath(roundedRect: nub, xRadius: 1.25, yRadius: 1.25).fill()

            // Cut the content out of the body
            ctx.setBlendMode(.destinationOut)
            var x = padding
            if let glyph {
                let g = glyph.size
                glyph.draw(in: NSRect(x: x, y: (bodyHeight - g.height) / 2, width: g.width, height: g.height),
                           from: .zero, operation: .destinationOut, fraction: 1)
                x += boltWidth
            }
            let textY = (bodyHeight - textSize.height) / 2 + 0.5
            (text as NSString).draw(at: NSPoint(x: x, y: textY),
                                    withAttributes: [.font: font, .foregroundColor: NSColor.black])
            ctx.setBlendMode(.normal)
            return true
        }
        image.isTemplate = !isLow
        image.accessibilityDescription = String(localized: "Battery") + " " + text
        return image
    }

    /// "6:28" style (hours:minutes), like the time remaining in the macOS battery menu.
    static func clock(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        return String(format: "%d:%02d", minutes / 60, minutes % 60)
    }
}
