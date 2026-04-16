import SwiftUI

// MARK: - Environment keys

private struct GlassOpacityKey: EnvironmentKey {
    static let defaultValue: Double = 0.0
}

private struct GlassVariantKey: EnvironmentKey {
    static let defaultValue: GlassVariant = .default
}

private struct TextScaleKey: EnvironmentKey {
    static let defaultValue: Double = 1.0
}

private struct TextColorBrightnessKey: EnvironmentKey {
    static let defaultValue: Double = 1.0
}

private struct TextColorIsDarkKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var glassOpacity: Double {
        get { self[GlassOpacityKey.self] }
        set { self[GlassOpacityKey.self] = newValue }
    }
    var glassVariantEnv: GlassVariant {
        get { self[GlassVariantKey.self] }
        set { self[GlassVariantKey.self] = newValue }
    }
    var textScale: Double {
        get { self[TextScaleKey.self] }
        set { self[TextScaleKey.self] = newValue }
    }
    var textColorBrightness: Double {
        get { self[TextColorBrightnessKey.self] }
        set { self[TextColorBrightnessKey.self] = newValue }
    }
    var textColorIsDark: Bool {
        get { self[TextColorIsDarkKey.self] }
        set { self[TextColorIsDarkKey.self] = newValue }
    }
}

// MARK: - Adaptive text color helpers

extension View {
    /// Secondary text color that respects the text color brightness setting.
    func adaptiveSecondary() -> some View {
        modifier(AdaptiveSecondaryModifier())
    }
}

private struct AdaptiveSecondaryModifier: ViewModifier {
    @Environment(\.textColorBrightness) private var brightness
    @Environment(\.textColorIsDark) private var isDark
    func body(content: Content) -> some View {
        let b = isDark ? 1 - brightness : brightness
        content.foregroundStyle(Color(white: b).opacity(0.93))
    }
}

// MARK: - Scaled font helper

extension View {
    func scaledFont(_ size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        modifier(ScaledFontModifier(baseSize: size, weight: weight, design: design))
    }
}

private struct ScaledFontModifier: ViewModifier {
    @Environment(\.textScale) private var scale
    let baseSize: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    func body(content: Content) -> some View {
        content.font(.system(size: baseSize * scale, weight: weight, design: design))
    }
}

// MARK: - Glass card

struct GlassMorphicCard<Content: View>: View {
    @Environment(\.glassOpacity) private var glassOpacity
    @Environment(\.glassVariantEnv) private var glassVariant
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder let content: () -> Content

    private var overlayColor: Color {
        colorScheme == .dark ? .black : .white
    }

    var body: some View {
        content()
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(overlayColor.opacity(glassOpacity))
            )
            #if MAIN_APP
            .background {
                LiquidGlassBackgroundView(cornerRadius: 16, variant: glassVariant)
            }
            #else
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            #endif
    }
}
