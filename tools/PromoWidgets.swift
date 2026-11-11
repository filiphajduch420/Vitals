import AppKit
import MachO
import SwiftUI
import WidgetKit

/// Renders the desktop widgets for the promo screenshots. The widget views live
/// in the extension target, so `tools/screenshots.sh` compiles them together
/// with this file into a small command-line tool; it writes one transparent PNG
/// per widget (container background included, as the system draws it) that
/// `Vitals --promo` then places on the wallpaper.
///
/// Usage: PromoWidgets <outDir>
@main
struct PromoWidgets {
    static let small = CGSize(width: 170, height: 170)
    static let medium = CGSize(width: 364, height: 170)

    @MainActor
    static func main() {
        let dir = CommandLine.arguments.dropFirst().first ?? "."
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        let m = PromoDemo.metrics
        let entry = VitalsEntry(date: PromoDemo.now, metrics: m)
        // `Text(_:style: .relative)` counts from the real clock, so boot "now minus uptime".
        let info = SystemInfoEntry(date: .now, bootDate: Date(timeIntervalSinceNow: -PromoDemo.uptime),
                                   osVersion: PromoDemo.osVersion, modelName: PromoDemo.modelName)
        // The same accents as the widgets' container backgrounds.
        let storageAccent = usageColor(m.disk.usageRatio)
        let batteryAccent: Color = .green
        let systemAccent: Color = .blue

        for (family, size, suffix) in [(WidgetFamily.systemSmall, small, "small"), (.systemMedium, medium, "medium")] {
            render(StorageWidgetView(entry: entry), family: family, size: size, accent: storageAccent,
                   to: "\(dir)/storage-\(suffix).png")
            render(BatteryWidgetView(entry: entry), family: family, size: size, accent: batteryAccent,
                   to: "\(dir)/battery-\(suffix).png")
            render(SystemInfoWidgetView(entry: info), family: family, size: size, accent: systemAccent,
                   to: "\(dir)/system-\(suffix).png")
        }
    }

    @MainActor
    static func render<V: View>(_ view: V, family: WidgetFamily, size: CGSize, accent: Color, to path: String) {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        let content = ZStack {
            WidgetGradientBackground(accentColor: accent)
            view
                .padding(16)
                .frame(width: size.width, height: size.height)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
        .transformEnvironment(\.self) { WidgetFamilyOverride.apply(&$0, small: family == .systemSmall) }
        .environment(\.colorScheme, .dark)
        .foregroundStyle(.primary)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        renderer.isOpaque = false
        guard let img = renderer.cgImage,
              let data = NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:]) else {
            print("failed: \(path)")
            return
        }
        try? data.write(to: URL(fileURLWithPath: path))
        print("saved \(path)")
    }
}

/// `\.widgetFamily` is read-only outside a widget host, so every view would
/// report `.systemMedium` here. WidgetKit stores the family under an internal
/// environment key (`WidgetFamilyKey`, value `InternalWidgetFamily`: 0 = small,
/// 1 = medium); this looks the key up in WidgetKit's Swift type metadata and
/// writes it the way the host does. Promo tool only, never shipped.
enum WidgetFamilyOverride {
    nonisolated(unsafe) static let key: (any EnvironmentKey.Type)? = findType(image: "/WidgetKit", name: "WidgetFamilyKey")
        as? any EnvironmentKey.Type

    static func apply(_ env: inout EnvironmentValues, small: Bool) {
        guard let key else { print("WidgetFamilyKey not found"); return }
        func set<K: EnvironmentKey>(_ k: K.Type) {
            guard MemoryLayout<K.Value>.size == 1 else { return }
            env[K.self] = unsafeBitCast(UInt8(small ? 0 : 1), to: K.Value.self)
        }
        set(key)
    }

    /// Finds a type by name in a loaded image's `__swift5_types` section and
    /// returns its metadata (via the descriptor's metadata access function).
    static func findType(image: String, name: String) -> Any.Type? {
        for i in 0..<_dyld_image_count() where String(cString: _dyld_get_image_name(i)).hasSuffix(image) {
            guard let header = _dyld_get_image_header(i) else { continue }
            var size: UInt = 0
            guard let section = getsectiondata(UnsafeRawPointer(header).assumingMemoryBound(to: mach_header_64.self),
                                               "__TEXT", "__swift5_types", &size) else { continue }
            let base = UnsafeRawPointer(section)
            for offset in stride(from: 0, to: Int(size), by: 4) {
                let entry = base + offset
                let raw = entry.load(as: Int32.self)
                var descriptor = entry + Int(raw & ~3)
                if raw & 1 == 1 { descriptor = descriptor.load(as: UnsafeRawPointer.self) }
                let namePtr = descriptor + 8
                let typeName = String(cString: (namePtr + Int(namePtr.load(as: Int32.self))).assumingMemoryBound(to: CChar.self))
                guard typeName == name else { continue }
                let accessorPtr = descriptor + 12
                typealias Accessor = @convention(thin) (Int) -> UnsafeRawPointer
                let accessor = unsafeBitCast(accessorPtr + Int(accessorPtr.load(as: Int32.self)), to: Accessor.self)
                return unsafeBitCast(accessor(0), to: Any.Type.self)
            }
        }
        return nil
    }
}
