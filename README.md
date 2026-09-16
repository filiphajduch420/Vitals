# Vitals

A lightweight macOS menu bar app that monitors your system in real time with a beautiful Liquid Glass interface.

Built with SwiftUI and designed for **macOS 26 (Tahoe)**.

**Current version: 2.4** — See [CHANGELOG.md](CHANGELOG.md) for full release history.

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
- **Desktop Widgets** — Liquid Glass-style, macOS Tahoe-native widgets with donut rings, angular gradients, status-color glow, SF Pro Rounded typography, and accented rendering mode support:
  - **System Overview** *(new in v2.3)* — medium and large sizes with two donut rings for Battery and Storage plus network info below
  - **Storage** — donut ring with used %, free space, and Used/Free/Total breakdown
  - **Battery** — donut ring with charging bolt, Status/Health/Cycles/Time remaining
  - **Network Info** — donut ring showing signal quality % (from RSSI), SSID, Local/Public IP, and signal
  - **System Health** — at-a-glance status
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

## What's New in v2.4

- **Public IP is now opt-in** — the app no longer queries `api.ipify.org` automatically; turn on "Show public IP" in General settings if you want it
- **Lighter on the battery** — Wi-Fi local IP is read via `getifaddrs()` instead of forking `ipconfig` every 2 seconds
- **Pauses on sleep** — monitoring stops when the display or system sleeps and resumes on wake
- **Smoother, quieter I/O** — `metrics.json` is written off the main thread and throttled, and slow-changing IOKit values are cached
- **Accurate memory pressure** — read from the real kernel signal, so no more false "warning"/"critical" alarms
- **Fewer timers** — the menu bar label now redraws directly when new metrics arrive
- **Data-race fix** — `WiFiMonitor` is now an actor
- **Widgets are gentler on WidgetKit's refresh budget** — no design changes; the System Health widget now reflects the corrected memory-pressure signal

### Logging & Troubleshooting

- Unified logging via `os.Logger` under the subsystem `com.filiphajduch.vitals`, with per-area categories
- New **Copy log command** button in Settings > General > About
- New **Troubleshooting / Logs** section in this README

### Distribution & Security

- Public IP lookup is opt-in and disabled by default — no automatic third-party requests
- `create-dmg.sh` now ad-hoc signs the app and widget with a hardened runtime, stages in private temp directories, and publishes a SHA-256 checksum
- `metrics.json` is created with owner-only (`0600`) permissions from the start
- Updated install instructions (Open Anyway, checksum verification, `xattr`)

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

> **Widgets and the pre-built build:** the pre-compiled (unsigned) build has no valid App Group entitlement, so the **desktop widgets may not display data**. For fully working widgets, build from source with your own Apple ID — even a free one works. On a macOS app the 7-day provisioning-profile limit doesn't get in the way, because Xcode re-signs the app on every build.

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

- macOS hides Wi-Fi SSID names from apps without Location Services permission; the Network widget shows "Wi-Fi" as a fallback label when the name can't be read.

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
