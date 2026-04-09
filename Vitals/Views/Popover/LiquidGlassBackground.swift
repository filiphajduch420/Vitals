import SwiftUI
import AppKit
import ObjectiveC

// MARK: - Container that prevents layout recursion

private class GlassContainerView: NSView {
    override func layout() {
        super.layout()
        // Resize glass subview to match without triggering layoutSubtreeIfNeeded
        if let glass = subviews.first {
            glass.frame = bounds
        }
    }
}

// MARK: - Glass background only

struct LiquidGlassBackgroundView: NSViewRepresentable {
    let cornerRadius: CGFloat
    let variant: GlassVariant

    func makeNSView(context: Context) -> NSView {
        let container = GlassContainerView()
        container.wantsLayer = true

        if let glassType = NSClassFromString("NSGlassEffectView") as? NSView.Type {
            let glass = glassType.init(frame: .zero)
            glass.setValue(cornerRadius, forKey: "cornerRadius")
            setVariant(on: glass, value: variant.rawValue)
            glass.autoresizingMask = [.width, .height]
            container.addSubview(glass)
        } else {
            let fallback = NSVisualEffectView()
            fallback.material = .underWindowBackground
            fallback.wantsLayer = true
            fallback.layer?.cornerRadius = cornerRadius
            fallback.autoresizingMask = [.width, .height]
            container.addSubview(fallback)
        }

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let glass = nsView.subviews.first else { return }
        glass.setValue(cornerRadius, forKey: "cornerRadius")
        setVariant(on: glass, value: variant.rawValue)
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
