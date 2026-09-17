# Vitals

A lightweight macOS menu bar app that monitors your system in real time with a beautiful Liquid Glass interface.

Built with SwiftUI and designed for **macOS 26 (Tahoe)**.

**Current version: 2.5** — See [CHANGELOG.md](CHANGELOG.md) for full release history.

> **Note:** This app is not signed with an Apple Developer certificate. When you first open it, macOS will show a warning saying it "cannot verify the app is free of malware." To open it, go to **System Settings > Privacy & Security** and click **"Open Anyway"** next to the Vitals message. I'm a student and can't afford the $99/year Apple Developer Program fee, but the app is fully open source — you can review every line of code and build it yourself.

## Features

- **Menu Bar** — Live CPU, GPU, memory, network, battery, disk stats right in your menu bar
- **Liquid Glass UI** — Native `NSGlassEffectView` with 3 style variants and adjustable opacity
- **CPU** — Usage breakdown (user/system/idle), core count, temperature, fan RPM, power draw
- **GPU** — Utilization, VRAM usage, temperature (Apple Silicon + Intel/AMD)
- **Memory** — Used/total with active, wired, and compressed breakdown
- **Network** — Live upload/download speeds with sparkline graphs and total transfer stats
- **Battery** — Charge level, health %, cycle count, charging status, time remaining, temperature
- **Disk** — Usage bar, free space, read/write speeds, SSD temperature
- **WiFi** — Connection status, signal strength, link speed, channel, local IP, and public IP (opt-in — the public IP lookup is disabled by default and queries an external service only when you enable it)
- **System Info** — Computer name, user, macOS version, uptime
- **Top Processes** — Top 5 processes by CPU or Memory (segmented switch) in the popover, with Activity Monitor-style CPU %; the scan only runs while the popover is open, so it stays battery-friendly
- **Desktop Widgets** — Liquid Glass-style, macOS Tahoe-native widgets with donut rings, angular gradients, status-color glow, SF Pro Rounded typography, and accented rendering mode support. Each widget computes its own data inside the widget process, so it shows real data everywhere — including the pre-built (unsigned) build with no App Group:
  - **Storage** — donut ring with used %, free space, and Used/Free/Total breakdown
  - **Battery** — donut ring with charging bolt, Status/Health/Cycles/Time remaining, including battery health % and cycle count (a figure macOS doesn't show anywhere obvious)
  - **System Info** — a live, ticking uptime that stays current without spending refresh budget, plus macOS version, Mac model, and boot time
- **Localization** — The whole app and its widgets are localized; the language follows your system by default, with a System / English / Čeština switch (and Relaunch) in General settings
- **Check for Updates** — A button in Settings > General > About that checks the GitHub Releases API on demand (privacy-first — only when you click it)
- **Customizable** — Reorder sections and menu bar items, toggle visibility, adjust text size, choose glass style

## Screenshots

### Popover
![Vitals Popover](media/gui.png)

### Menu Bar
![Menu Bar](media/menu_bar.png)

### Settings - Appearance
![Settings Appearance](media/settings_app.png)

### Settings - General
![Settings General](media/settings_general.png)

## What's New in v2.5

- **Widgets that work for everyone** — the Storage, Battery, and System Info widgets now compute their data themselves inside the widget process, so they show real data even on the pre-built (unsigned) DMG build with no App Group
- **Battery health on your desktop** — the Battery widget now surfaces battery health % and cycle count, a figure macOS doesn't show anywhere obvious
- **Live uptime** — the new System Info widget renders a ticking uptime that stays current without spending refresh budget, alongside macOS version, Mac model, and boot time
- **Real-time widgets removed** — System Overview, System Health, and Network Info are gone; WidgetKit's ~15-minute refresh budget made their instantaneous values stale and misleading (real-time lives in the menu bar and popover, where it works)
- **Top Processes** — a new popover card listing the top 5 processes by CPU or Memory, with Activity Monitor-style CPU %; it scans only while the popover is open
- **Czech localization** — the whole app and its widgets are localized, with a System / English / Čeština switch (and Relaunch) in General settings
- **Check for Updates** — a privacy-first button in About that checks the GitHub Releases API only when you click it
- **Widget redesign** — unified headers, full-width two-column layouts, SF Pro Rounded typography, and monospaced digits across every widget
- **Fixed: battery health on Apple Silicon** — capacity is now also read from the nested `BatteryData` dictionary; health % had been missing from the popover since v2.3 on these Macs

See [CHANGELOG.md](CHANGELOG.md) for the complete list of changes.

## Requirements

- macOS 26.0 (Tahoe) or later
- Xcode 26 with Swift 6.0

## Installation

### Build from source

1. Clone the repository:
   ```bash
   git clone https://github.com/filiphajduch420/Vitals.git
   cd Vitals
   ```

2. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) if you don't have it:
   ```bash
   brew install xcodegen
   ```

3. Generate the Xcode project and open it:
   ```bash
   xcodegen generate
   open Vitals.xcodeproj
   ```

4. Select the **Vitals** scheme, set your signing team, and hit **Run** (Cmd+R).

### Download release

The recommended way to install a pre-built build:

1. Download the latest `.dmg` from the [Releases](https://github.com/filiphajduch420/Vitals/releases) page (grab the matching `.sha256` file too).
2. Verify the checksum:
   ```bash
   shasum -a 256 -c Vitals-vX.dmg.sha256
   ```
   It should print `Vitals-vX.dmg: OK`.
3. Open the DMG and drag **Vitals** into your Applications folder.
4. The first launch will be blocked because the app isn't signed with an Apple Developer certificate. Go to **System Settings > Privacy & Security**, scroll to the Vitals message, and click **"Open Anyway"**. You only need to do this once.

> **Note:** Since macOS 15 Sequoia, right-clicking the app and choosing "Open" no longer bypasses Gatekeeper for unsigned apps — use the **"Open Anyway"** button in System Settings instead.

**Alternative (Terminal):** remove the quarantine attribute directly:
```bash
xattr -dr com.apple.quarantine /Applications/Vitals.app
```

> **Widgets and the pre-built build:** as of v2.5 the desktop widgets **work on the pre-compiled (unsigned) build too** — they compute their data themselves inside the widget process instead of relying on the App Group. Building from source with your own Apple ID (even a free one) is still worthwhile: with a valid App Group entitlement the widgets can prefer fresh data straight from the running app when it's available.

## Usage

After launching, Vitals lives in your menu bar. Click the menu bar items to open the popover with detailed system stats.

- **Settings** — Click the gear icon in the popover header
- **Glass Style** — Choose between 3 Liquid Glass variants (A, B, C) in Appearance settings
- **Opacity** — Adjust the glass darkness with the opacity slider
- **Section Order** — Reorder cards with the arrow buttons in Appearance settings
- **Menu Bar Order** — Reorder menu bar items with arrow buttons in General settings
- **Text Size** — Scale the UI from 80% to 130%
- **Widgets** — Add desktop widgets via Edit Widgets > Vitals

## Tech Stack

- **SwiftUI** — All UI
- **AppKit** — NSPanel for popover, NSGlassEffectView for Liquid Glass
- **CoreWLAN** — WiFi monitoring
- **IOKit** — Battery, GPU, and thermal data
- **Swift Charts** — Sparkline graphs
- **WidgetKit** — Desktop widgets
- **XcodeGen** — Project generation

## Known limitations

- macOS hides Wi-Fi SSID names from apps without Location Services permission; the WiFi section shows "Wi-Fi" as a fallback label when the name can't be read.
- The per-app language override doesn't propagate to the widget extension, so widgets follow the system language; Czech widget strings show when the system language is Czech.

## Troubleshooting / Logs

Vitals logs to the unified macOS logging system under the subsystem `com.filiphajduch.vitals`. When something misbehaves — the widgets show no data, a sensor reads zero, or the public IP lookup fails — the logs usually say why (IOKit/SMC read failures, a missing App Group container, `sysctl`/`getifaddrs` errors, network errors, or JSON decode problems).

**Show the last 30 minutes of logs:**

```bash
log show --predicate 'subsystem == "com.filiphajduch.vitals"' --info --debug --last 30m
```

This is the exact command behind the **Copy log command** button in **Settings > General > About**.

**Follow the logs live** while you reproduce the issue:

```bash
log stream --predicate 'subsystem == "com.filiphajduch.vitals"' --info
```

You can narrow the output to a single area with the `category` field — `app`, `power`, `sharing`, `widgets`, or a specific monitor (`cpu`, `gpu`, `memory`, `battery`, `thermal`, `network`, `wifi`, `disk`, `systemInfo`). For example, to debug why widgets show no data, watch the shared-data pipeline:

```bash
log stream --predicate 'subsystem == "com.filiphajduch.vitals" AND category == "sharing"' --info --debug
```

Sensitive values (IP addresses, Wi-Fi SSID, error details) are logged as `private` and appear as `<private>` unless you explicitly enable private-data logging on your own machine.

## License

MIT License — see [LICENSE](LICENSE) for details.

## Author

Filip Hajduch ([@filiphajduch420](https://github.com/filiphajduch420))
