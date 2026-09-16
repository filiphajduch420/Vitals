#!/bin/bash
# Vitals - macOS System Monitor
# Setup script: installs xcodegen and generates Xcode project

set -e

echo "=== Vitals Setup ==="

# Check for Xcode
if ! xcode-select -p | grep -q "Xcode.app"; then
    echo ""
    echo "WARNING: Full Xcode is not installed (only Command Line Tools detected)."
    echo "Please install Xcode from the App Store or developer.apple.com"
    echo "Then run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    echo ""
    echo "Without Xcode, the project cannot be built."
    exit 1
fi

# Install xcodegen if needed
if ! command -v xcodegen &> /dev/null; then
    echo "Installing xcodegen via Homebrew..."
    if ! command -v brew &> /dev/null; then
        echo "Homebrew not found. Install from https://brew.sh"
        exit 1
    fi
    brew install xcodegen
fi

# Generate Xcode project
echo "Generating Xcode project..."
cd "$(dirname "$0")"
xcodegen generate

echo ""
echo "=== Done! ==="
echo "Open Vitals.xcodeproj in Xcode, select your team in Signing & Capabilities,"
echo "then build and run (Cmd+R)."
echo ""
echo "The App Group ID is generated automatically as <TEAM_ID>.com.filiphajduch.vitals"
echo "based on the team selected in Signing & Capabilities - no manual setup needed."
echo "If widgets don't show data, make sure BOTH targets (Vitals and VitalsWidgets)"
echo "use the same team in Xcode."
