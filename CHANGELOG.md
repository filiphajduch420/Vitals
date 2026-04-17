# Changelog

All notable changes to Vitals will be documented in this file.

## [2.3.1] - 2026-04-17

### Fixed
- **SMC read regression** — `output2` vs `output` typo in `ThermalMonitor.smcRead` caused all SMC sensor reads to return nil, hiding CPU temperature, fan RPM, GPU temperature, and system power in the popover

## [2.3] - 2026-04-17

### Added
- **System Overview widget** — new medium + large widget showing Battery and Storage as side-by-side donut rings with network info below (SSID, signal bars, IPs on large)
- **Widget tinted mode** — `widgetAccentable` support for macOS Tahoe tinted rendering
- **Shared widget components** — `DonutRing`, `WidgetGradientBackground`, `WidgetHeader`, `WidgetStatRow`, `BigPercent` extracted into `VitalsWidgets/Components/WidgetComponents.swift` for reuse

### Changed
- **Complete widget redesign** — all widgets now use donut rings with angular gradients, dark gradient backgrounds with status-color glow, and SF Pro Rounded typography
- **Storage widget** — large donut ring showing used %, free space below
- **Battery widget** — donut ring with lightning bolt overlay when charging; Status/Health/Cycles/Time rows on medium
- **Network Info widget** — donut ring showing signal quality % mapped from RSSI, IP and signal details below

### Fixed
- **Widget data sharing** — restored App Group container (regression from v2.2 refactor had broken widget data reads)
- **WiFi empty SSID** — handle empty string (not just nil); shows "Wi-Fi" label when macOS hides the network name

### Security
- **Memory leaks** — `IOObjectRelease` via `defer` in DiskMonitor and GPUMonitor prevents leaked IOKit handles on error paths
- **PowerStateMonitor** — retain/release fix on context pointer eliminates use-after-free risk
- **ThermalMonitor** — SMC bounds check prevents buffer overread when reading thermal sensor data
- **Public IP lookup** — HTTP status check and IPv4/IPv6 format validation before trusting response
- **WiFi SSID lookup** — `autoreleasepool` wrap around `SCDynamicStore` calls to prevent long-lived CF leaks
- **File permissions** — `metrics.json` written with `0o600` (owner-only read/write)
- **App Transport Security** — `NSAppTransportSecurity` disallows arbitrary loads (HTTPS only)
- **Safe URL unwrap** — `GeneralSettingsView` GitHub link guarded against invalid URL
- **Binary size** — release-config symbol stripping reduces attack surface

## [2.2] - 2026-04-16

### Added
- **Battery saving mode** — polls less frequently when running on battery
- **Configurable battery saving interval** in General settings
- **Text contrast slider** in Appearance settings
- **Network Info widget** added to widget gallery
- **Smooth number animations** for metric values

### Changed
- **Smarter polling** — expensive sensors read less often on battery
- **Menu bar updates** synced with polling interval
- **Widget refresh interval** reduced from 5 to 2 minutes
- **Improved light mode contrast** for accent colors and text
- **Faster, snappier animations** throughout the UI

### Fixed
- Crash on displays without a screen detected
- Battery widget showing stale data
- Battery widget text invisible in light mode
- Long WiFi names and IP addresses now truncate properly

## [2.1] - 2026-04-09

### Added
- **Glass Reset to Default** — button in Appearance settings to reset glass style and opacity

### Changed
- **Section toggle real-time** — toggling sections in Settings now updates the popover instantly
- **Panel full-height** — popover panel extends full screen height (transparent) so new sections appear without delay
- **Network widget** — compact bottom row layout, units no longer cut off; removed small widget size
- **Battery layout** — Health and Cycles left-aligned next to each other

### Fixed
- **Widget data sharing** — App Group ID now resolves correctly with DEVELOPMENT_TEAM
- **Widget version mismatch** — widget bundle version matches main app (was causing widgets to disappear from gallery)
- **WiFi SSID fallback** — added SystemConfiguration-based SSID reader as additional fallback

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
