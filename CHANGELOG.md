# Changelog

All notable changes to Vitals will be documented in this file.

## [2.0] - 2026-04-09

### Added
- **GPU monitoring** — utilization, VRAM usage, temperature (Apple Silicon + Intel/AMD)
- **Battery health** — capacity degradation %, cycle count from IOKit
- **Local & Public IP** — displayed in WiFi section and optionally in menu bar
- **Battery Time** — remaining time in menu bar with infinity symbol when plugged in
- **Desktop widgets** — System Health (traffic light), Storage, Battery, Network Info
- **Menu bar ordering** — reorder items with arrow buttons in Settings
- **Menu bar reset** — "Reset to Default" button in Settings
- **Section reset** — "Reset to Default" button for popover section order
- **App icon** — monitor with heartbeat/pulse design
- **Glass opacity default** — 20% for better readability out of the box

### Changed
- **Liquid Glass** — switched from SwiftUI `.glassEffect()` to native `NSGlassEffectView` via AppKit for authentic Apple glass look
- **Glass variants** — reduced to 3 styles (A, B, C) with segmented picker
- **Light/dark mode** — opacity overlay adapts (black in dark mode, white in light mode)
- **Default sections** — CPU, GPU, Memory, Battery, System visible; Disk, WiFi, Network hidden
- **Default menu bar** — CPU Usage, GPU Usage, Memory enabled; rest disabled
- **Battery display** — shows infinity symbol when plugged in instead of "0m"
- **ScrollView** — popover scrolls on smaller screens (MacBook Air fix)
- **Text scaling** — proper font scaling via environment instead of scaleEffect
- **Sub-icons** — all detail icons are now white/secondary for consistency

### Fixed
- **WiFi detection** — IP-based fallback when CoreWLAN lacks permissions
- **Widget data sharing** — Team ID prefix for App Group (fixes macOS Sequoia/Tahoe)
- **Widget registration** — proper code signing for widget gallery visibility
- **Layout recursion** — GlassContainerView wrapper prevents NSGlassEffectView layout crash
- **Battery health** — reads AppleRawMaxCapacity instead of MaxCapacity (was showing 1%)
- **Icon sizes** — correct pixel dimensions for all Retina scales

## [1.1] - 2026-04-08

### Added
- App icon (heartbeat/pulse design)
- ScrollView for small screens
- DMG installer with Applications shortcut
- Author and GitHub link in Settings > About

### Changed
- System section defaults to bottom
- Light mode opacity fix

## [1.0] - 2026-04-08

### Added
- Initial release
- Menu bar system monitor with CPU, Memory, Network, Battery, Disk, WiFi, System info
- Liquid Glass UI with customizable opacity and style variants
- Customizable section order and visibility
- Adjustable text size
- Settings with General and Appearance tabs
- Built with SwiftUI for macOS 26 (Tahoe)
