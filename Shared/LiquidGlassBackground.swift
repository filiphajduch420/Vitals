import SwiftUI
import AppKit
import ObjectiveC

// MARK: - Glass Variant

enum GlassVariant: Int, CaseIterable, Codable, Sendable, Identifiable {
    case a = 11
    case b = 0
    case c = 2

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .a: return "A"
        case .b: return "B"
        case .c: return "C"
        }
    }

    static let `default`: GlassVariant = .a
}

// MARK: - Glass background only (no content management — SwiftUI handles layout)

struct LiquidGlassBackgroundView: NSViewRepresentable {
    let cornerRadius: CGFloat
    let variant: GlassVariant

    func makeNSView(context: Context) -> NSView {
        if let glassType = NSClassFromString("NSGlassEffectView") as? NSView.Type {
            let glass = glassType.init(frame: .zero)
            glass.setValue(cornerRadius, forKey: "cornerRadius")
            setVariant(on: glass, value: variant.rawValue)
            return glass
        }
        let fallback = NSVisualEffectView()
        fallback.material = .underWindowBackground
        fallback.wantsLayer = true
        fallback.layer?.cornerRadius = cornerRadius
        return fallback
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.setValue(cornerRadius, forKey: "cornerRadius")
        setVariant(on: nsView, value: variant.rawValue)
    }

    private typealias VariantSetterIMP = @convention(c) (AnyObject, Selector, Int) -> Void

    private func setVariant(on object: AnyObject, value: Int) {
        let sel = NSSelectorFromString("set_variant:")
        guard let m = class_getInstanceMethod(object_getClass(object), sel) else { return }
        let imp = method_getImplementation(m)
        let f = unsafeBitCast(imp, to: VariantSetterIMP.self)
        f(object, sel, value)
    }
}

// MARK: - Convenience wrapper

struct LiquidGlassBackground<Content: View>: View {
    let variant: GlassVariant
    let cornerRadius: CGFloat
    @ViewBuilder let content: () -> Content

    init(
        variant: GlassVariant = .default,
        cornerRadius: CGFloat = 14,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.variant = variant
        self.cornerRadius = cornerRadius
        self.content = content
    }

    var body: some View {
        content()
            .background {
                LiquidGlassBackgroundView(cornerRadius: cornerRadius, variant: variant)
            }
    }
}
