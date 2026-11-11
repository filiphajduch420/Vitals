import AppKit
import CoreImage
import SwiftUI

/// Marketing screenshots without screen recording: `Vitals --promo <dir>` draws a
/// warm macOS desktop itself, renders the real popover, menu bar label and
/// settings tabs offscreen with fixed demo readings (`PromoDemo`) and saves PNGs.
///
/// The window server composites Liquid Glass, so it never shows up in an
/// offscreen render. In promo mode `LiquidGlassBackgroundView` therefore draws
/// `PromoGlassSurface`, which only reports where each glass card is; the glass
/// itself (blurred backdrop, edge refraction, rim light, shadow) is drawn here.
///
/// Settings are kept in a throwaway defaults domain, nothing is monitored and no
/// status item is created, so a promo run never affects the installed app.
/// `tools/screenshots.sh` builds and runs everything.
@MainActor
enum Promo {
    nonisolated static let isActive = CommandLine.arguments.contains("--promo")
    nonisolated static let suiteName = "com.filiphajduch.vitals.promo"
    nonisolated(unsafe) static let defaults: UserDefaults = UserDefaults(suiteName: suiteName) ?? .standard

    /// Coordinate space the glass cards report their frames in.
    nonisolated static let space = "promo.space"
    static var glassFrames: [UUID: CGRect] = [:]
    /// Settings window: no wallpaper behind the glass preview, so it draws its
    /// stand-in inline in SwiftUI.
    static var glassInline = false

    static var outDir: String {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--promo"), i + 1 < args.count, !args[i + 1].hasPrefix("-") { return args[i + 1] }
        return "media/promo"
    }

    /// Desktop of a 14" MacBook Pro ("looks like 1512 × 982").
    static let screen = CGSize(width: 1512, height: 982)
    static let menuH: CGFloat = 30
    static let panelWidth: CGFloat = 290
    static let dockRect = CGRect(x: 416, y: 982 - 72, width: 680, height: 64)

    static var isCzech: Bool { Bundle.main.preferredLocalizations.first?.hasPrefix("cs") == true }

    // MARK: - Run

    static func run(appState: AppState) {
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        defaults.removePersistentDomain(forName: suiteName)
        let only = ProcessInfo.processInfo.environment["VITALS_PROMO_ONLY"]
            .map { Set($0.split(separator: ",").map(String.init)) }
        func wanted(_ name: String) -> Bool { only?.contains(name) ?? true }

        Task { @MainActor in
            configure(appState)
            if isCzech {
                await renderPopoverShot(appState, name: "popover-cs")
            } else {
                if wanted("hero") { await renderHero(appState) }
                if wanted("popover") { await renderPopoverShot(appState, name: "popover") }
                if wanted("settings") { await renderSettings(appState) }
                if wanted("widgets") { renderWidgets() }
            }
            defaults.removePersistentDomain(forName: suiteName)
            exit(0)
        }
    }

    // MARK: - Demo state

    static func configure(_ s: AppState) {
        s.glassVariant = .a
        s.glassOpacity = 0.2
        s.textScale = 1.0
        s.textColorBrightness = 0.9
        s.sectionOrder = PopoverSection.allCases
        s.menuBarOrder = MenuBarItem.allCases
        let bar: Set<MenuBarItem> = [.cpuUsage, .cpuTemp, .memory, .networkDown, .networkUp, .battery, .batteryTime]
        for item in MenuBarItem.allCases { s[keyPath: s.menuBarBinding(for: item)] = bar.contains(item) }
        s.batteryStyle = .capsule
        s.powerMonitor.isOnBattery = true

        s.metrics = PromoDemo.metrics
        func fill(_ h: inout MetricHistory, _ points: [(Date, Double)]) {
            h = MetricHistory(capacity: 60)
            for (date, v) in points { h.append(v, at: date) }
        }
        let m = PromoDemo.metrics
        fill(&s.cpuHistory, PromoDemo.history(m.cpu.totalUsage, swing: 0.09, spikes: [17: 0.46, 18: 0.38, 40: 0.41], seed: 0.4))
        fill(&s.memoryHistory, PromoDemo.history(m.memory.usageRatio, swing: 0.012, seed: 1.3))
        fill(&s.diskHistory, PromoDemo.history(m.disk.usageRatio, swing: 0.0, seed: 0))
        let battery: [(Date, Double)] = (0..<60).map { (i: Int) -> (Date, Double) in
            let t = Double(i)
            return (PromoDemo.now.addingTimeInterval((t - 59) * 2), 0.87 - 0.01 * t / 59)
        }
        fill(&s.batteryHistory, battery)
        let maxSpeed = 10.0 * 1024 * 1024 * 1024
        fill(&s.networkDownHistory, PromoDemo.history(Double(m.network.downloadSpeed) / maxSpeed, swing: 0, seed: 0))
        fill(&s.networkUpHistory, PromoDemo.history(Double(m.network.uploadSpeed) / maxSpeed, swing: 0, seed: 0))

        let gb: Double = 1024 * 1024 * 1024
        s.topProcessesByCPU = [
            ProcessUsage(pid: 812, name: "Xcode", cpuPercent: 64.2, memoryBytes: UInt64(2.1 * gb)),
            ProcessUsage(pid: 2290, name: "swift-frontend", cpuPercent: 48.7, memoryBytes: UInt64(0.9 * gb)),
            ProcessUsage(pid: 402, name: "WindowServer", cpuPercent: 14.3, memoryBytes: UInt64(0.8 * gb)),
            ProcessUsage(pid: 1022, name: "Safari", cpuPercent: 9.8, memoryBytes: UInt64(1.4 * gb)),
            ProcessUsage(pid: 1530, name: "Vitals", cpuPercent: 0.4, memoryBytes: UInt64(0.04 * gb)),
        ]
        s.topProcessesByMemory = s.topProcessesByCPU.sorted { $0.memoryBytes > $1.memoryBytes }
    }

    static func setSections(_ s: AppState, all: Bool) {
        s.sectionCPU = true
        s.sectionGPU = true
        s.sectionMemory = true
        s.sectionBattery = true
        s.sectionSystem = true
        s.sectionProcesses = true
        s.sectionDisk = all
        s.sectionWiFi = all
        s.sectionNetwork = all
    }

    // MARK: - Scenes

    /// The whole desktop: menu bar with the live label, the popover open below it,
    /// the Vitals widgets on the desktop and a Dock.
    static func renderHero(_ s: AppState) async {
        setSections(s, all: false)
        let popover = await renderPopover(s, height: 1000)
        let label = menuBarLabel(s)

        let c = Canvas(screen)
        drawWallpaper(c, frame: CGRect(origin: .zero, size: screen))
        let sharp = c.image()
        let backdrop = blurred(sharp, radius: 9, saturation: 1.25)
        let wideBlur = blurred(sharp, radius: 22, saturation: 1.3)
        drawDesktopWidgets(c, backdrop: wideBlur)
        drawTerminal(c, CGRect(x: 404, y: 330, width: 496, height: 330))
        let withWindows = c.image()
        drawDock(c, backdrop: blurred(withWindows, radius: 18, saturation: 1.3))
        let labelRect = drawMenuBar(c, label: label)

        // The panel is centred under the status item, 8 pt below the menu bar,
        // and reaches down to 16 pt above the Dock (StatusBarController.showPanel).
        let panelTop = menuH + 8
        let panelBottom = dockRect.minY - 8 - 16
        let panel = CGRect(x: labelRect.midX - panelWidth / 2, y: panelTop, width: panelWidth, height: panelBottom - panelTop)
        let under = blurred(c.image(), radius: 12, saturation: 1.25)
        _ = backdrop
        drawPopover(c, popover, at: panel, backdrop: under)
        save(c.image(), "hero")

        // Close-up of the menu bar around the Vitals label.
        let strip = CGRect(x: labelRect.minX - 48, y: 0, width: screen.width - labelRect.minX + 48, height: menuH)
        save(c.image().cropping(to: strip.scaled(by: Canvas.scale)), "menubar")
    }

    /// The full popover with every section, on a crop of the wallpaper.
    static func renderPopoverShot(_ s: AppState, name: String) async {
        setSections(s, all: true)
        let popover = await renderPopover(s, height: 1500)
        let pad: CGFloat = 56
        let size = CGSize(width: panelWidth + pad * 2, height: popover.contentHeight + pad * 2)
        let c = Canvas(size)
        // Place the wallpaper so the crop shows its warm right half.
        let wallH = size.height
        let wallW = wallH * screen.width / screen.height
        drawWallpaper(c, frame: CGRect(x: -wallW * 0.56, y: 0, width: wallW, height: wallH))
        let backdrop = blurred(c.image(), radius: 9, saturation: 1.25)
        drawPopover(c, popover, at: CGRect(x: pad, y: pad, width: panelWidth, height: popover.contentHeight), backdrop: backdrop)
        save(c.image(), name)
    }

    // MARK: - Popover

    struct PopoverImage {
        let image: CGImage
        let cards: [CGRect]          // glass cards, points, origin top left of the panel
        let contentHeight: CGFloat
        let size: CGSize
    }

    static func renderPopover(_ s: AppState, height: CGFloat) async -> PopoverImage {
        glassFrames = [:]
        glassInline = false
        let size = CGSize(width: panelWidth, height: height)
        let root = PopoverView()
            .environment(s)
            .environment(\.colorScheme, .dark)
            .frame(width: size.width, height: size.height, alignment: .top)
            .coordinateSpace(.named(space))
        let host = NSHostingView(rootView: root)
        let image = await snapshot(host, size: size)
        let cards = glassFrames.values.sorted { $0.minY < $1.minY }
        let bottom = (cards.map(\.maxY).max() ?? height) + 10
        return PopoverImage(image: image, cards: cards, contentHeight: ceil(bottom), size: size)
    }

    /// Glass for every card, then the SwiftUI content on top, clipped to the panel.
    static func drawPopover(_ c: Canvas, _ p: PopoverImage, at panel: CGRect, backdrop: CGImage) {
        for card in p.cards {
            let r = card.offsetBy(dx: panel.minX, dy: panel.minY)
            guard r.maxY <= panel.maxY + 1 else { continue }
            glass(c, r, radius: 16, backdrop: backdrop)
        }
        c.ctx.saveGState()
        c.ctx.clip(to: c.rect(panel))
        c.ctx.draw(p.image, in: c.rect(CGRect(origin: panel.origin, size: p.size)))
        c.ctx.restoreGState()
    }

    // MARK: - Settings

    static func renderSettings(_ s: AppState) async {
        setSections(s, all: false)
        glassInline = true
        drawAsActiveApp()
        let general = String(localized: "General"), appearance = String(localized: "Appearance")
        let shots: [(name: String, tab: Int, height: CGFloat, scroll: CGFloat)] = [
            ("settings-general", 0, 520, 0),
            ("settings-menubar", 0, 650, 440),
            ("settings-appearance", 1, 664, 0),
        ]
        for shot in shots {
            let content: AnyView = shot.tab == 0
                ? AnyView(GeneralSettingsView().environment(s))
                : AnyView(AppearanceSettingsView().environment(s))
            guard let window = await renderWindow(content, title: shot.tab == 0 ? general : appearance,
                                                  tabs: [(general, "gearshape"), (appearance, "paintbrush")],
                                                  selected: shot.tab, contentHeight: shot.height, scroll: shot.scroll)
            else { continue }
            composeWindow(window, name: shot.name)
        }
        glassInline = false
    }

    /// The settings shots should look like the frontmost app (blue switches)
    /// without actually activating it and stealing focus: within this promo
    /// process only, `NSApp.isActive` reports true.
    static func drawAsActiveApp() {
        let sel = #selector(getter: NSApplication.isActive)
        let block: @convention(block) (AnyObject) -> Bool = { _ in true }
        for sel in [sel, NSSelectorFromString("_isActiveApp")] {
            if let m = class_getInstanceMethod(NSApplication.self, sel) {
                method_setImplementation(m, imp_implementationWithBlock(block))
            }
        }
    }

    struct WindowImage {
        let image: CGImage
        let size: CGSize
        let buttons: [CGRect]        // traffic lights, points, origin top left
        let tabs: [(String, String)]
        let selected: Int
    }

    /// Renders a real titled window with a preference-style toolbar offscreen,
    /// title bar included (its theme frame draws fine into a bitmap).
    static func renderWindow(_ content: AnyView, title: String, tabs: [(String, String)], selected: Int,
                             contentHeight: CGFloat, scroll: CGFloat) async -> WindowImage? {
        let size = CGSize(width: 440, height: contentHeight)
        let host = NSHostingView(rootView: content
            .environment(\.colorScheme, .dark)
            .environment(\.controlActiveState, .key)
            .frame(width: size.width, height: size.height))
        let win = KeyWindow(contentRect: CGRect(origin: .zero, size: size),
                            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        win.appearance = NSAppearance(named: .darkAqua)
        win.title = title
        let toolbarDelegate = PromoToolbar(tabs: tabs)
        let toolbar = NSToolbar(identifier: "promo.settings.\(selected)")
        toolbar.delegate = toolbarDelegate
        toolbar.displayMode = .iconAndLabel
        win.toolbar = toolbar
        win.toolbarStyle = .preference
        toolbar.selectedItemIdentifier = toolbarDelegate.ids[selected]
        win.contentView = host
        win.setFrameOrigin(CGPoint(x: -9000, y: -9000))
        win.orderFrontRegardless()
        let acquire = NSSelectorFromString("acquireKeyAppearance")
        if win.responds(to: acquire) { win.perform(acquire) }
        try? await Task.sleep(for: .seconds(1.4))
        if scroll > 0, let sv = firstScrollView(in: host) {
            sv.contentView.scroll(to: NSPoint(x: 0, y: scroll))
            sv.reflectScrolledClipView(sv.contentView)
            try? await Task.sleep(for: .seconds(0.6))
        }
        guard let frameView = win.contentView?.superview else { return nil }
        frameView.layoutSubtreeIfNeeded()
        let bounds = frameView.bounds
        guard let img = bitmap(of: frameView, size: bounds.size) else { return nil }
        let buttons: [CGRect] = [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].compactMap { type in
            guard let b = win.standardWindowButton(type) else { return nil }
            let r = b.convert(b.bounds, to: frameView)
            return frameView.isFlipped ? r : CGRect(x: r.minX, y: bounds.height - r.maxY, width: r.width, height: r.height)
        }
        win.orderOut(nil)
        withExtendedLifetime(toolbarDelegate) {}
        return WindowImage(image: img, size: bounds.size, buttons: buttons, tabs: tabs, selected: selected)
    }

    static func firstScrollView(in v: NSView) -> NSScrollView? {
        if let s = v as? NSScrollView, s.documentView != nil { return s }
        for sub in v.subviews { if let s = firstScrollView(in: sub) { return s } }
        return nil
    }

    /// The window with rounded corners, coloured traffic lights and a shadow on the wallpaper.
    static func composeWindow(_ w: WindowImage, name: String) {
        let pad: CGFloat = 64
        let size = CGSize(width: w.size.width + pad * 2, height: w.size.height + pad * 2)
        let c = Canvas(size)
        let wallH = max(size.height, size.width * screen.height / screen.width) * 1.25
        let wallW = wallH * screen.width / screen.height
        drawWallpaper(c, frame: CGRect(x: -wallW * 0.18, y: size.height - wallH * 0.86, width: wallW, height: wallH))
        let r = CGRect(x: pad, y: pad, width: w.size.width, height: w.size.height)
        let path = continuous(c.rect(r), 16)
        let ctx = c.ctx
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 50, color: rgb(0.12, 0.03, 0, 0.55))
        ctx.addPath(path)
        ctx.setFillColor(rgb(0.12, 0.12, 0.12))
        ctx.fillPath()
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.draw(w.image, in: c.rect(r))
        ctx.restoreGState()
        // Hairline border, as on every macOS window.
        ctx.addPath(continuous(c.rect(r).insetBy(dx: 0.5, dy: 0.5), 15.5))
        ctx.setStrokeColor(rgb(1, 1, 1, 0.16))
        ctx.setLineWidth(1)
        ctx.strokePath()
        drawToolbarTabs(c, w, origin: CGPoint(x: pad, y: pad))
        // Active-window traffic lights over the (inactive, grey) rendered ones.
        let colors = [rgb(1, 0.37, 0.34), rgb(1, 0.74, 0.18), rgb(0.16, 0.79, 0.25)]
        for (i, b) in w.buttons.enumerated() where i < 3 {
            let d: CGFloat = min(b.width, b.height) - 0.5
            let dot = CGRect(x: b.midX - d / 2, y: b.midY - d / 2, width: d, height: d).offsetBy(dx: pad, dy: pad)
            ctx.setFillColor(colors[i])
            ctx.fillEllipse(in: c.rect(dot))
            ctx.setStrokeColor(rgb(0, 0, 0, 0.18))
            ctx.setLineWidth(0.5)
            ctx.strokeEllipse(in: c.rect(dot).insetBy(dx: 0.25, dy: 0.25))
        }
        save(c.image(), name)
    }

    /// The toolbar's tab buttons sit on glass capsules, which render as flat
    /// boxes offscreen. Redraw that strip as the active Settings window shows
    /// it: plain icons and labels, the selected tab highlighted in the accent colour.
    static func drawToolbarTabs(_ c: Canvas, _ w: WindowImage, origin o: CGPoint) {
        let ctx = c.ctx
        // Title bar colour, sampled left of the tabs.
        var bg = rgb(0.17, 0.17, 0.17)
        if let px = w.image.cropping(to: CGRect(x: 24 * Canvas.scale, y: 60 * Canvas.scale, width: 1, height: 1)),
           let data = px.dataProvider?.data, let p = CFDataGetBytePtr(data) {
            let a = max(CGFloat(p[3]), 1)
            bg = rgb(CGFloat(p[0]) / a, CGFloat(p[1]) / a, CGFloat(p[2]) / a)
        }
        let strip = CGRect(x: o.x + 90, y: o.y + 28, width: w.size.width - 180, height: 56)
        ctx.setFillColor(bg)
        ctx.fill(c.rect(strip))
        let accent = NSColor.controlAccentColor.usingColorSpace(.sRGB) ?? .systemBlue
        let font = NSFont.systemFont(ofSize: 11, weight: .medium)
        let widths = w.tabs.map { max(56, NSAttributedString(string: $0.0, attributes: [.font: font]).size().width + 18) }
        var x = o.x + (w.size.width - widths.reduce(0, +) - 2) / 2
        for (i, tab) in w.tabs.enumerated() {
            let box = CGRect(x: x, y: o.y + 31, width: widths[i], height: 50)
            let on = i == w.selected
            if on {
                ctx.addPath(continuous(c.rect(box), 10))
                ctx.setFillColor(rgb(1, 1, 1, 0.08))
                ctx.fillPath()
                ctx.addPath(continuous(c.rect(box).insetBy(dx: 0.5, dy: 0.5), 9.5))
                ctx.setStrokeColor(rgb(1, 1, 1, 0.1))
                ctx.setLineWidth(1)
                ctx.strokePath()
            }
            let color = on ? accent : NSColor(white: 0.62, alpha: 1)
            c.ns {
                // Same point size for every icon (as the toolbar does), centred.
                let cfg = NSImage.SymbolConfiguration(pointSize: 17, weight: .regular).applying(.init(paletteColors: [color]))
                if let img = NSImage(systemSymbolName: tab.1, accessibilityDescription: nil)?.withSymbolConfiguration(cfg) {
                    let sz = img.size
                    img.draw(in: c.rect(CGRect(x: box.midX - sz.width / 2, y: box.minY + 17 - sz.height / 2,
                                               width: sz.width, height: sz.height)))
                }
                let label = NSAttributedString(string: tab.0, attributes: [.font: font, .foregroundColor: color])
                let ls = label.size()
                label.draw(at: CGPoint(x: box.midX - ls.width / 2, y: c.size.height - (box.minY + 31) - ls.height))
            }
            x += widths[i] + 2
        }
    }

    // MARK: - Widgets

    /// Widget pictures come from `tools/PromoWidgets.swift` (the widget views
    /// live in the extension target); this places them on the wallpaper.
    static var widgetDir: String? { ProcessInfo.processInfo.environment["VITALS_PROMO_WIDGETS"] }

    static func widgetImage(_ name: String) -> CGImage? {
        guard let dir = widgetDir,
              let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: "\(dir)/\(name).png") as CFURL, nil)
        else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }

    static let small: CGFloat = 170
    static let medium = CGSize(width: 364, height: 170)
    static let gap: CGFloat = 18

    static func drawWidget(_ c: Canvas, _ name: String, at r: CGRect, backdrop: CGImage) {
        guard let img = widgetImage(name) else { return }
        glass(c, r, radius: 22, backdrop: backdrop, tint: 0, rim: 0.55, refraction: 0, shadow: 0.22)
        c.ctx.draw(img, in: c.rect(r))
    }

    /// Storage and Battery (small) and System Info (medium) in the desktop's top left corner.
    static func drawDesktopWidgets(_ c: Canvas, backdrop: CGImage) {
        let x: CGFloat = 26, y = menuH + 22
        drawWidget(c, "storage-small", at: CGRect(x: x, y: y, width: small, height: small), backdrop: backdrop)
        drawWidget(c, "battery-small", at: CGRect(x: x + small + gap + 6, y: y, width: small, height: small), backdrop: backdrop)
        drawWidget(c, "system-medium", at: CGRect(x: x, y: y + small + gap + 6, width: medium.width, height: medium.height),
                   backdrop: backdrop)
    }

    static func renderWidgets() {
        guard widgetImage("storage-small") != nil else {
            print("widgets: no widget images (set VITALS_PROMO_WIDGETS) – skipped")
            return
        }
        let pad: CGFloat = 60
        let row1 = small * 2 + medium.width + gap * 2
        let size = CGSize(width: row1 + pad * 2, height: small * 2 + gap + pad * 2)
        let c = Canvas(size)
        let wallH = size.height * 1.9
        let wallW = wallH * screen.width / screen.height
        drawWallpaper(c, frame: CGRect(x: -wallW * 0.12, y: size.height - wallH * 0.88, width: wallW, height: wallH))
        let backdrop = blurred(c.image(), radius: 22, saturation: 1.3)
        var x = pad
        let y1 = pad, y2 = pad + small + gap
        drawWidget(c, "storage-small", at: CGRect(x: x, y: y1, width: small, height: small), backdrop: backdrop)
        x += small + gap
        drawWidget(c, "battery-small", at: CGRect(x: x, y: y1, width: small, height: small), backdrop: backdrop)
        x += small + gap
        drawWidget(c, "system-medium", at: CGRect(x: x, y: y1, width: medium.width, height: medium.height), backdrop: backdrop)
        let w2 = (row1 - gap) / 2
        drawWidget(c, "storage-medium", at: CGRect(x: pad, y: y2, width: w2, height: medium.height), backdrop: backdrop)
        drawWidget(c, "battery-medium", at: CGRect(x: pad + w2 + gap, y: y2, width: w2, height: medium.height), backdrop: backdrop)
        save(c.image(), "widgets")
    }

    // MARK: - Offscreen rendering

    /// Hosts a view in an invisible borderless window far off screen and draws it at 2×.
    static func snapshot(_ host: NSView, size: CGSize) async -> CGImage {
        let win = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless],
                           backing: .buffered, defer: false)
        win.appearance = NSAppearance(named: .darkAqua)
        win.backgroundColor = .clear
        win.isOpaque = false
        host.frame = CGRect(origin: .zero, size: size)
        win.contentView = host
        win.setFrameOrigin(CGPoint(x: -9000, y: -9000))
        win.orderFrontRegardless()
        try? await Task.sleep(for: .seconds(1.2))
        host.layoutSubtreeIfNeeded()
        let img = bitmap(of: host, size: size)
        win.orderOut(nil)
        return img ?? Canvas(size).image()
    }

    static func bitmap(of view: NSView, size: CGSize) -> CGImage? {
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * Canvas.scale),
                                         pixelsHigh: Int(size.height * Canvas.scale), bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { return nil }
        rep.size = size
        view.cacheDisplay(in: view.bounds, to: rep)
        return rep.cgImage
    }

    static func save(_ img: CGImage?, _ name: String) {
        guard let img, let data = NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:]) else {
            print("failed: \(name)")
            return
        }
        let path = "\(outDir)/\(name).png"
        try? data.write(to: URL(fileURLWithPath: path))
        print("saved \(path) (\(img.width)×\(img.height))")
    }

    // MARK: - Glass

    nonisolated(unsafe) static let ciContext = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])

    static func blurred(_ img: CGImage, radius: CGFloat, saturation: CGFloat) -> CGImage {
        let src = CIImage(cgImage: img)
        let out = src.clampedToExtent()
            .applyingGaussianBlur(sigma: Double(radius * Canvas.scale))
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: saturation])
            .cropped(to: src.extent)
        return ciContext.createCGImage(out, from: src.extent) ?? img
    }

    static func continuous(_ r: CGRect, _ radius: CGFloat) -> CGPath {
        RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: r).cgPath
    }

    /// Liquid Glass stand-in: the blurred, slightly more saturated desktop seen
    /// through the shape, a refracting band along the edge, a faint tint, an
    /// inner glow, a specular rim (bright top left and bottom right) and a soft
    /// shadow. `r` is in points with the origin top left.
    static func glass(_ c: Canvas, _ r: CGRect, radius: CGFloat, backdrop: CGImage, tint: CGFloat = 0.08,
                      rim: CGFloat = 1, refraction: CGFloat = 7, shadow: CGFloat = 0.3) {
        let ctx = c.ctx
        let rr = c.rect(r)
        let path = continuous(rr, radius)
        let full = CGRect(origin: .zero, size: c.size)

        if shadow > 0 {
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: -5), blur: 18, color: rgb(0.1, 0.02, 0, shadow))
            ctx.addPath(path)
            ctx.setFillColor(rgb(0, 0, 0, 1))
            ctx.fillPath()
            ctx.restoreGState()
        }

        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.draw(backdrop, in: full)

        // Refraction: near the edge the glass shows the backdrop magnified
        // towards the centre, fading out a few points in.
        if refraction > 0, let mask = edgeMask(size: rr.size, radius: radius, band: refraction * 1.6) {
            ctx.saveGState()
            ctx.clip(to: rr, mask: mask)
            let sx = 1 + refraction / (rr.width / 2), sy = 1 + refraction / (rr.height / 2)
            ctx.translateBy(x: rr.midX, y: rr.midY)
            ctx.scaleBy(x: sx, y: sy)
            ctx.translateBy(x: -rr.midX, y: -rr.midY)
            ctx.draw(backdrop, in: full)
            ctx.restoreGState()
            ctx.saveGState()
            ctx.clip(to: rr, mask: mask)
            ctx.setFillColor(rgb(1, 0.95, 0.9, 0.035))
            ctx.fill(rr)
            ctx.restoreGState()
        }

        if tint > 0 {
            // Like the real glass, darken more over bright backgrounds so white text stays legible.
            let lum = luminance(of: backdrop, in: rr, canvas: c.size)
            ctx.setFillColor(rgb(0.08, 0.03, 0.02, min(0.6, tint + max(0, lum - 0.3) * 0.9)))
            ctx.fill(rr)
        }
        // A soft sheen over the upper half.
        gradient(ctx, [rgb(1, 1, 1, 0.07 * rim), rgb(1, 1, 1, 0)],
                 from: CGPoint(x: rr.minX, y: rr.maxY), to: CGPoint(x: rr.minX, y: rr.maxY - min(60, rr.height * 0.6)))

        // Inner glow along the edge.
        let frame = CGMutablePath()
        frame.addRect(rr.insetBy(dx: -40, dy: -40))
        frame.addPath(path)
        ctx.setShadow(offset: .zero, blur: 9, color: rgb(1, 0.96, 0.92, 0.2 * rim))
        ctx.addPath(frame)
        ctx.setFillColor(rgb(1, 1, 1, 1))
        ctx.fillPath(using: .evenOdd)
        ctx.restoreGState()

        // Specular rim.
        ctx.saveGState()
        ctx.addPath(continuous(rr.insetBy(dx: 0.6, dy: 0.6), max(0, radius - 0.6)))
        ctx.setLineWidth(1.2)
        ctx.replacePathWithStrokedPath()
        ctx.clip()
        let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [
            rgb(1, 1, 1, 0.9 * rim), rgb(1, 1, 1, 0.3 * rim), rgb(1, 1, 1, 0.1 * rim),
            rgb(1, 1, 1, 0.3 * rim), rgb(1, 1, 1, 0.7 * rim),
        ] as CFArray, locations: [0, 0.12, 0.5, 0.88, 1])!
        ctx.drawLinearGradient(g, start: CGPoint(x: rr.minX, y: rr.maxY), end: CGPoint(x: rr.maxX, y: rr.minY), options: [])
        ctx.restoreGState()
        // Edge definition.
        ctx.addPath(continuous(rr.insetBy(dx: 0.25, dy: 0.25), radius))
        ctx.setStrokeColor(rgb(1, 1, 1, 0.12 * rim))
        ctx.setLineWidth(0.5)
        ctx.strokePath()
    }

    /// Average luminance (0…1) of `img` inside `r` (CG coordinates, points).
    static func luminance(of img: CGImage, in r: CGRect, canvas: CGSize) -> CGFloat {
        let px = CGRect(x: r.minX * Canvas.scale, y: (canvas.height - r.maxY) * Canvas.scale,
                        width: r.width * Canvas.scale, height: r.height * Canvas.scale)
        guard let crop = img.cropping(to: px) else { return 0 }
        var rgba = [UInt8](repeating: 0, count: 4)
        guard let ctx = CGContext(data: &rgba, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0 }
        ctx.interpolationQuality = .medium
        ctx.draw(crop, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return (0.2126 * CGFloat(rgba[0]) + 0.7152 * CGFloat(rgba[1]) + 0.0722 * CGFloat(rgba[2])) / 255
    }

    /// White along the shape's edge fading to black `band` points inwards.
    static func edgeMask(size: CGSize, radius: CGFloat, band: CGFloat) -> CGImage? {
        let s = Canvas.scale
        guard let ctx = CGContext(data: nil, width: Int(size.width * s), height: Int(size.height * s), bitsPerComponent: 8,
                                  bytesPerRow: 0, space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.scaleBy(x: s, y: s)
        let r = CGRect(origin: .zero, size: size)
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(r)
        ctx.addPath(continuous(r, radius))
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.fillPath()
        ctx.setShadow(offset: .zero, blur: band * 1.4, color: CGColor(gray: 0, alpha: 1))
        ctx.addPath(continuous(r.insetBy(dx: band, dy: band), radius))
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fillPath()
        return ctx.makeImage()
    }

    // MARK: - Wallpaper

    /// A warm desert dusk: deep oxblood sky over amber and terracotta dunes,
    /// with a low sun on the left. Drawn into `frame` (CG coordinates).
    static func drawWallpaper(_ c: Canvas, frame f: CGRect) {
        let ctx = c.ctx
        ctx.saveGState()
        ctx.clip(to: CGRect(origin: .zero, size: c.size))
        func p(_ u: CGFloat, _ v: CGFloat) -> CGPoint { CGPoint(x: f.minX + u * f.width, y: f.minY + v * f.height) }

        // Sky.
        let sky = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [
            rgb(0.98, 0.80, 0.52), rgb(0.95, 0.58, 0.30), rgb(0.80, 0.34, 0.16), rgb(0.50, 0.17, 0.09),
            rgb(0.27, 0.09, 0.06), rgb(0.15, 0.05, 0.04),
        ] as CFArray, locations: [0, 0.12, 0.3, 0.52, 0.76, 1])!
        ctx.drawLinearGradient(sky, start: p(0, 0.3), end: p(0, 1), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

        // Low sun on the left with a wide warm glow; the right side stays deeper.
        radial(ctx, p(0.17, 0.33), f.width * 0.62, [rgb(1, 0.82, 0.52, 0.55), rgb(1, 0.6, 0.3, 0.18), rgb(1, 0.5, 0.25, 0)])
        radial(ctx, p(0.95, 0.85), f.width * 0.5, [rgb(0.10, 0.03, 0.03, 0.45), rgb(0.10, 0.03, 0.03, 0)])
        radial(ctx, p(0.17, 0.335), f.width * 0.075, [rgb(1, 0.97, 0.86, 1), rgb(1, 0.9, 0.7, 0.85), rgb(1, 0.8, 0.55, 0)])
        // Soft streaks of haze.
        for (u, v, w, a) in [(0.18, 0.47, 0.42, 0.16), (0.62, 0.43, 0.5, 0.12), (0.4, 0.58, 0.36, 0.08)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
            ctx.saveGState()
            ctx.translateBy(x: p(u, v).x, y: p(u, v).y)
            ctx.scaleBy(x: 1, y: 0.09)
            radial(ctx, .zero, f.width * w, [rgb(1, 0.78, 0.52, a), rgb(1, 0.7, 0.45, 0)])
            ctx.restoreGState()
        }

        // Dunes, back to front.
        func dune(base: CGFloat, amp: CGFloat, seed: CGFloat, top: CGColor, bottom: CGColor, crest: CGColor) {
            let path = CGMutablePath()
            path.move(to: p(0, 0))
            var u: CGFloat = 0
            var peak: CGFloat = 0
            while u <= 1.0001 {
                let v = base + amp * (0.62 * sin(u * 5.1 + seed) + 0.28 * sin(u * 11.3 + seed * 1.9) + 0.1 * sin(u * 23 + seed * 3.1))
                peak = max(peak, v)
                path.addLine(to: p(u, v))
                u += 0.004
            }
            path.addLine(to: p(1, 0))
            path.closeSubpath()
            ctx.saveGState()
            ctx.addPath(path)
            ctx.clip()
            gradient(ctx, [top, bottom], from: p(0, peak), to: p(0, max(0, base - amp * 2.2)))
            ctx.restoreGState()
            // Sunlit crest.
            ctx.saveGState()
            ctx.addPath(path)
            ctx.clip()
            ctx.translateBy(x: 0, y: -1.2)
            ctx.addPath(path)
            ctx.setStrokeColor(crest)
            ctx.setLineWidth(2.2)
            ctx.strokePath()
            ctx.restoreGState()
        }
        dune(base: 0.30, amp: 0.028, seed: 0.6, top: rgb(0.88, 0.47, 0.25), bottom: rgb(0.74, 0.33, 0.17), crest: rgb(1, 0.78, 0.5, 0.5))
        dune(base: 0.23, amp: 0.045, seed: 2.2, top: rgb(0.72, 0.31, 0.16), bottom: rgb(0.55, 0.21, 0.11), crest: rgb(1, 0.66, 0.4, 0.4))
        dune(base: 0.15, amp: 0.055, seed: 4.0, top: rgb(0.50, 0.19, 0.10), bottom: rgb(0.35, 0.12, 0.07), crest: rgb(0.95, 0.55, 0.32, 0.32))
        dune(base: 0.065, amp: 0.05, seed: 5.3, top: rgb(0.30, 0.10, 0.06), bottom: rgb(0.19, 0.06, 0.04), crest: rgb(0.85, 0.45, 0.26, 0.22))

        // Fine grain so the gradients never band.
        if let grain = grainTile {
            ctx.setBlendMode(.overlay)
            ctx.setAlpha(0.07)
            ctx.draw(grain, in: CGRect(x: 0, y: 0, width: 256, height: 256), byTiling: true)
        }
        ctx.restoreGState()
    }

    static let grainTile: CGImage? = {
        let noise = CIFilter(name: "CIRandomGenerator")?.outputImage?
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0.33, y: 0.33, z: 0.33, w: 0),
                "inputGVector": CIVector(x: 0.33, y: 0.33, z: 0.33, w: 0),
                "inputBVector": CIVector(x: 0.33, y: 0.33, z: 0.33, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            ])
            .cropped(to: CGRect(x: 0, y: 0, width: 512, height: 512))
        return noise.flatMap { ciContext.createCGImage($0, from: $0.extent) }
    }()

    // MARK: - Desktop pieces

    /// Menu bar: Finder menus on the left, the real Vitals label and the system items on the right.
    /// Returns the label's rectangle (points, origin top left).
    @discardableResult
    static func drawMenuBar(_ c: Canvas, label: NSAttributedString) -> CGRect {
        let ctx = c.ctx
        let bar = CGRect(x: 0, y: 0, width: c.size.width, height: menuH)
        gradient(ctx, [rgb(0.08, 0.02, 0.02, 0.32), rgb(0.08, 0.02, 0.02, 0.18)],
                 from: CGPoint(x: 0, y: c.size.height), to: CGPoint(x: 0, y: c.size.height - menuH))
        _ = bar
        var right = c.size.width - 18
        let barH = menuH
        c.ns {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor(white: 0, alpha: 0.25)
            shadow.shadowBlurRadius = 2
            shadow.shadowOffset = CGSize(width: 0, height: -0.5)
            func attr(_ s: String, bold: Bool = false) -> NSAttributedString {
                NSAttributedString(string: s, attributes: [
                    .font: NSFont.systemFont(ofSize: 13.5, weight: bold ? .bold : .medium),
                    .foregroundColor: NSColor.white, .shadow: shadow,
                ])
            }
            func draw(_ a: NSAttributedString, x: CGFloat) {
                let sz = a.size()
                a.draw(at: CGPoint(x: x, y: c.size.height - barH + (barH - sz.height) / 2))
            }
            // Left: Apple menu and Finder.
            symbol("apple.logo", in: CGRect(x: 20, y: 7, width: 16, height: 16), c: c, color: .white)
            var x: CGFloat = 50
            for (i, m) in ["Finder", "File", "Edit", "View", "Go", "Window", "Help"].enumerated() {
                let a = attr(m, bold: i == 0)
                draw(a, x: x)
                x += a.size().width + 19
            }
            // Right: clock, Control Centre, Wi-Fi, then Vitals.
            let clock = attr("Wed 11 Nov  9:41")
            right -= clock.size().width
            draw(clock, x: right)
            right -= 34
            symbol("switch.2", in: CGRect(x: right, y: 7, width: 17, height: 16), c: c, color: .white)
            right -= 34
            symbol("wifi", in: CGRect(x: right, y: 7.5, width: 18, height: 15), c: c, color: .white)
            right -= 18
        }
        let labelSize = label.size()
        let rect = CGRect(x: right - labelSize.width, y: (menuH - labelSize.height) / 2, width: labelSize.width,
                          height: labelSize.height)
        c.ns { label.draw(at: CGPoint(x: rect.minX, y: c.size.height - rect.maxY)) }
        return rect.insetBy(dx: -6, dy: 0)
    }

    /// The status item's real attributed title, in white like on a dark menu bar.
    static func menuBarLabel(_ s: AppState) -> NSAttributedString {
        let label = NSMutableAttributedString(attributedString: StatusBarController.label(for: s))
        let all = NSRange(location: 0, length: label.length)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(white: 0, alpha: 0.25)
        shadow.shadowBlurRadius = 2
        shadow.shadowOffset = CGSize(width: 0, height: -0.5)
        label.addAttribute(.foregroundColor, value: NSColor.white, range: all)
        label.addAttribute(.shadow, value: shadow, range: all)
        label.enumerateAttribute(.attachment, in: all) { value, range, _ in
            guard let a = value as? NSTextAttachment, let img = a.image else { return }
            let white = NSImage(size: img.size, flipped: false) { r in
                img.draw(in: r)
                NSColor.white.set()
                r.fill(using: .sourceAtop)
                return true
            }
            let t = NSTextAttachment()
            t.image = white
            t.bounds = a.bounds
            label.addAttribute(.attachment, value: t, range: range)
        }
        return label
    }

    static func drawDock(_ c: Canvas, backdrop: CGImage) {
        glass(c, dockRect, radius: 22, backdrop: backdrop, tint: 0, rim: 0.8, refraction: 5, shadow: 0.25)
        c.ctx.saveGState()
        c.ctx.addPath(continuous(c.rect(dockRect), 22))
        c.ctx.setFillColor(rgb(1, 0.95, 0.9, 0.1))
        c.ctx.fillPath()
        c.ctx.restoreGState()
        let icons: [(String, CGColor, CGColor, NSColor)] = [
            ("folder.fill", rgb(0.45, 0.78, 1), rgb(0.12, 0.45, 0.95), .white),
            ("safari", rgb(0.96, 0.97, 1), rgb(0.82, 0.86, 0.92), NSColor(red: 0.1, green: 0.45, blue: 0.95, alpha: 1)),
            ("envelope.fill", rgb(0.4, 0.7, 1), rgb(0.1, 0.4, 0.95), .white),
            ("message.fill", rgb(0.45, 0.92, 0.5), rgb(0.12, 0.72, 0.28), .white),
            ("music.note", rgb(1, 0.42, 0.5), rgb(0.92, 0.16, 0.3), .white),
            ("photo.fill", rgb(1, 0.8, 0.35), rgb(0.96, 0.45, 0.35), .white),
            ("calendar", rgb(1, 1, 1), rgb(0.9, 0.9, 0.92), NSColor(red: 0.9, green: 0.22, blue: 0.2, alpha: 1)),
            ("note.text", rgb(1, 0.9, 0.45), rgb(1, 0.76, 0.18), .white),
            ("terminal.fill", rgb(0.27, 0.27, 0.3), rgb(0.09, 0.09, 0.11), .white),
            ("hammer.fill", rgb(0.35, 0.7, 1), rgb(0.12, 0.35, 0.85), .white),
            ("gearshape.fill", rgb(0.68, 0.69, 0.72), rgb(0.42, 0.43, 0.47), .white),
        ]
        var x = dockRect.minX + 12
        let y = dockRect.minY + 8
        for (i, ic) in icons.enumerated() {
            let r = CGRect(x: x, y: y, width: 48, height: 48)
            let path = continuous(c.rect(r), 11)
            c.ctx.saveGState()
            c.ctx.setShadow(offset: CGSize(width: 0, height: -1.5), blur: 3, color: rgb(0, 0, 0, 0.3))
            c.ctx.addPath(path)
            c.ctx.setFillColor(ic.2)
            c.ctx.fillPath()
            c.ctx.restoreGState()
            c.ctx.saveGState()
            c.ctx.addPath(path)
            c.ctx.clip()
            gradient(c.ctx, [ic.1, ic.2], from: CGPoint(x: 0, y: c.rect(r).maxY), to: CGPoint(x: 0, y: c.rect(r).minY))
            c.ctx.restoreGState()
            c.ns { symbol(ic.0, in: r.insetBy(dx: 11, dy: 11), c: c, color: ic.3) }
            if i == 8 || i == 0 || i == 1 {   // running apps
                c.ctx.setFillColor(rgb(1, 1, 1, 0.75))
                c.ctx.fillEllipse(in: c.rect(CGRect(x: r.midX - 2, y: dockRect.maxY - 5.5, width: 4, height: 4)))
            }
            x += 54
        }
        // Separator and Trash.
        c.ctx.setFillColor(rgb(1, 1, 1, 0.3))
        c.ctx.fill(c.rect(CGRect(x: x + 1, y: dockRect.minY + 12, width: 1, height: 40)))
        x += 10
        let trash = CGRect(x: x, y: y, width: 48, height: 48)
        c.ctx.saveGState()
        c.ctx.addPath(continuous(c.rect(trash), 11))
        c.ctx.clip()
        gradient(c.ctx, [rgb(0.9, 0.9, 0.92), rgb(0.7, 0.71, 0.75)], from: CGPoint(x: 0, y: c.rect(trash).maxY),
                 to: CGPoint(x: 0, y: c.rect(trash).minY))
        c.ctx.restoreGState()
        c.ns { symbol("trash.fill", in: trash.insetBy(dx: 12, dy: 12), c: c, color: NSColor(white: 0.32, alpha: 1)) }
    }

    /// A Terminal window finishing a build – the reason the CPU is busy.
    static func drawTerminal(_ c: Canvas, _ r: CGRect) {
        let ctx = c.ctx
        let rr = c.rect(r)
        let path = continuous(rr, 16)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -16), blur: 44, color: rgb(0.1, 0.02, 0, 0.5))
        ctx.addPath(path)
        ctx.setFillColor(rgb(0.11, 0.1, 0.1, 0.96))
        ctx.fillPath()
        ctx.restoreGState()
        ctx.addPath(continuous(rr.insetBy(dx: 0.5, dy: 0.5), 15.5))
        ctx.setStrokeColor(rgb(1, 1, 1, 0.14))
        ctx.setLineWidth(1)
        ctx.strokePath()
        for (i, col) in [rgb(1, 0.37, 0.34), rgb(1, 0.74, 0.18), rgb(0.16, 0.79, 0.25)].enumerated() {
            ctx.setFillColor(col)
            ctx.fillEllipse(in: c.rect(CGRect(x: r.minX + 16 + CGFloat(i) * 20, y: r.minY + 14, width: 12, height: 12)))
        }
        c.ns {
            let title = NSAttributedString(string: "atlas — zsh — 80×24", attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: NSColor(white: 0.78, alpha: 1),
            ])
            title.draw(at: CGPoint(x: r.midX - title.size().width / 2, y: c.size.height - r.minY - 29))
            let prompt = NSColor(red: 1, green: 0.72, blue: 0.45, alpha: 1)
            let plain = NSColor(white: 0.82, alpha: 1)
            let dim = NSColor(white: 0.55, alpha: 1)
            let ok = NSColor(red: 0.5, green: 0.85, blue: 0.5, alpha: 1)
            let lines: [(String, NSColor)] = [
                ("~/Projects/Atlas % xcodebuild -scheme Atlas build", prompt),
                ("CompileSwift normal arm64 Sources/Atlas/MapView.swift", dim),
                ("CompileSwift normal arm64 Sources/Atlas/TileCache.swift", dim),
                ("CompileSwift normal arm64 Sources/Atlas/RouteSolver.swift", dim),
                ("Ld Atlas.app/Contents/MacOS/Atlas normal arm64", dim),
                ("CodeSign Atlas.app", dim),
                ("** BUILD SUCCEEDED ** [41.8 sec]", ok),
                ("~/Projects/Atlas % ▋", plain),
            ]
            var y = r.minY + 54
            for (l, col) in lines {
                let a = NSAttributedString(string: l, attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular), .foregroundColor: col,
                ])
                a.draw(at: CGPoint(x: r.minX + 20, y: c.size.height - y - 16))
                y += 27
            }
        }
    }

    // MARK: - Drawing helpers

    static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: r, green: g, blue: b, alpha: a)
    }

    static func gradient(_ ctx: CGContext, _ colors: [CGColor], from a: CGPoint, to b: CGPoint) {
        guard let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: nil)
        else { return }
        ctx.drawLinearGradient(g, start: a, end: b, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    static func radial(_ ctx: CGContext, _ center: CGPoint, _ radius: CGFloat, _ colors: [CGColor]) {
        guard let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: nil)
        else { return }
        ctx.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
    }

    /// An SF Symbol fitted into `r` (points, origin top left). Call inside `c.ns`.
    static func symbol(_ name: String, in r: CGRect, c: Canvas, color: NSColor, weight: NSFont.Weight = .medium) {
        let cfg = NSImage.SymbolConfiguration(pointSize: r.height, weight: weight)
            .applying(.init(paletteColors: [color]))
        guard let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(cfg) else { return }
        let s = img.size
        let k = min(r.width / s.width, r.height / s.height)
        let w = s.width * k, h = s.height * k
        img.draw(in: c.rect(CGRect(x: r.midX - w / 2, y: r.midY - h / 2, width: w, height: h)))
    }
}

/// A 2× bitmap canvas. Layout is in points with the origin top left (like the
/// screen and SwiftUI); `rect(_:)` converts to Core Graphics coordinates.
@MainActor
final class Canvas {
    static let scale: CGFloat = 2
    let ctx: CGContext
    let size: CGSize

    init(_ size: CGSize) {
        self.size = size
        ctx = CGContext(data: nil, width: Int(size.width * Self.scale), height: Int(size.height * Self.scale),
                        bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.scaleBy(x: Self.scale, y: Self.scale)
        ctx.interpolationQuality = .high
    }

    func rect(_ r: CGRect) -> CGRect { CGRect(x: r.minX, y: size.height - r.maxY, width: r.width, height: r.height) }
    func image() -> CGImage { ctx.makeImage()! }

    /// Runs AppKit drawing (text, symbols) into this canvas.
    func ns(_ body: () -> Void) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        body()
        NSGraphicsContext.restoreGraphicsState()
    }
}

private extension CGRect {
    func scaled(by k: CGFloat) -> CGRect { CGRect(x: minX * k, y: minY * k, width: width * k, height: height * k) }
}

/// Reports the frame of a glass card in promo mode (see `LiquidGlassBackgroundView`).
/// In the settings window there is no wallpaper behind it, so it draws a
/// simple glass look itself.
struct PromoGlassSurface: View {
    let cornerRadius: CGFloat
    @State private var id = UUID()

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            if Promo.glassInline {
                shape.fill(Color.white.opacity(0.06))
                shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.08), .white.opacity(0.04),
                                                           .white.opacity(0.35)],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            } else {
                Color.clear
            }
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Promo.space)) } action: { Promo.glassFrames[id] = $0 }
    }
}

/// Draws as the active window (coloured controls, accented toolbar selection)
/// without activating the app.
private final class KeyWindow: NSWindow {
    override var isKeyWindow: Bool { true }
    override var isMainWindow: Bool { true }
    // AppKit asks these (not isKeyWindow) when drawing controls and the title bar.
    @objc func _hasActiveAppearance() -> Bool { true }
    @objc func _hasActiveAppearanceIgnoringKeyFocus() -> Bool { true }
    @objc func _hasActiveControls() -> Bool { true }
    @objc func _hasKeyAppearance() -> Bool { true }
    @objc func _hasMainAppearance() -> Bool { true }
    @objc func hasKeyAppearance() -> Bool { true }
    @objc func _hasActiveAppearanceForStandardWindowButton(_ button: Int) -> Bool { true }
}

/// The two tabs of the Settings window as a preference-style toolbar.
@MainActor
private final class PromoToolbar: NSObject, NSToolbarDelegate {
    let tabs: [(String, String)]
    let ids: [NSToolbarItem.Identifier]

    init(tabs: [(String, String)]) {
        self.tabs = tabs
        ids = tabs.indices.map { NSToolbarItem.Identifier("promo.tab.\($0)") }
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { ids }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { ids }
    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { ids }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let i = ids.firstIndex(of: id) else { return nil }
        let item = NSToolbarItem(itemIdentifier: id)
        item.label = tabs[i].0
        item.image = NSImage(systemSymbolName: tabs[i].1, accessibilityDescription: tabs[i].0)
        item.isBordered = false
        return item
    }
}
