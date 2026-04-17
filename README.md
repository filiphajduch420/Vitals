# Vitals

A lightweight macOS menu bar app that monitors your system in real time with a beautiful Liquid Glass interface.

Built with SwiftUI and designed for **macOS 26 (Tahoe)**.

**Current version: 2.3** — See [CHANGELOG.md](CHANGELOG.md) for full release history.

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
- **WiFi** — Connection status, signal strength, link speed, channel, local IP, public IP
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

## What's New in v2.3

- Redesigned desktop widgets with Liquid Glass-style donut rings, angular gradients, and status-color glow
- New **System Overview** widget (medium + large) combining Battery + Storage donut rings with network info
- Network widget now displays signal quality % derived from RSSI
- SF Pro Rounded typography and support for the accented widget rendering mode
- Native look tuned for macOS Tahoe

### Security & Stability in v2.3

- Memory leak fixes (`IOObjectRelease` via `defer`) in DiskMonitor and GPUMonitor
- PowerStateMonitor retain/release fix on context pointer (use-after-free prevention)
- ThermalMonitor SMC bounds check prevents buffer overread when reading thermal sensors
- Public IP lookup: HTTP status check and IPv4/IPv6 format validation
- WiFi SSID lookup wrapped in `autoreleasepool` to prevent long-lived CF leaks
- `metrics.json` written with owner-only permissions (`0o600`)
- `NSAppTransportSecurity` disallows arbitrary loads (HTTPS only)
- Safe URL unwrap in General settings (no force-unwrap crash on GitHub link)
- Release-config symbol stripping reduces binary size and attack surface

## What's New in v2.0

- GPU monitoring (utilization, VRAM, temperature)
- Battery health tracking (capacity degradation, cycle count)
- Local & Public IP addresses
- Desktop widgets (System Health, Storage, Battery, Network Info)
- Menu bar item reordering with arrow buttons
- Native `NSGlassEffectView` for authentic Liquid Glass
- Light/dark mode adaptive glass opacity
- Scrollable popover for smaller screens

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

Check the [Releases](https://github.com/filiphajduch420/Vitals/releases) page for pre-built `.dmg` downloads.

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

## License

MIT License — see [LICENSE](LICENSE) for details.

## Author

Filip Hajduch ([@filiphajduch420](https://github.com/filiphajduch420))
