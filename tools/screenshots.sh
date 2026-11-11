#!/bin/zsh
# Renders the marketing screenshots into media/promo/ – no screen recording needed.
# Vitals draws a desktop itself and renders its real popover, menu bar label and
# settings tabs offscreen with fixed demo readings (see Vitals/App/Promo.swift).
# The widgets are rendered by a small tool built from the widget views
# (tools/PromoWidgets.swift). Nothing touches the installed app or its settings.
#
#   tools/screenshots.sh               all images
#   VITALS_PROMO_ONLY=hero,popover tools/screenshots.sh
set -euo pipefail
cd "$(dirname "$0")/.."

OUT=media/promo
BUILD=build/promo
mkdir -p "$OUT" "$BUILD"

# 1. Widgets: compile the widget views with the shared code into a command-line tool.
xcrun swiftc -parse-as-library -swift-version 5 -O -target "$(uname -m)-apple-macos26.0" \
  Shared/*.swift Vitals/App/PromoDemo.swift \
  VitalsWidgets/LocalMetrics.swift VitalsWidgets/Providers/ConfigurableWidgetProvider.swift \
  VitalsWidgets/Components/WidgetComponents.swift VitalsWidgets/Views/*.swift \
  tools/PromoWidgets.swift -o "$BUILD/PromoWidgets"
"$BUILD/PromoWidgets" "$BUILD/widgets" -AppleLanguages '(en)' -AppleLocale en_US

# 2. The app (Debug build into build/promo, never /Applications).
xcodegen generate --quiet
xcodebuild -project Vitals.xcodeproj -scheme Vitals -configuration Debug \
  -derivedDataPath "$BUILD" build -quiet
APP="$BUILD/Build/Products/Debug/Vitals.app/Contents/MacOS/Vitals"

export VITALS_PROMO_WIDGETS="$PWD/$BUILD/widgets"
"$APP" --promo "$OUT" -AppleLanguages '(en)' -AppleLocale en_US
# Czech popover (the app renders only popover-cs.png when its language is Czech).
if [[ -z "${VITALS_PROMO_ONLY:-}" || "${VITALS_PROMO_ONLY}" == *popover-cs* ]]; then
  "$APP" --promo "$OUT" -AppleLanguages '(cs)' -AppleLocale cs_CZ
fi

# The promo run keeps its settings in a throwaway domain; drop the empty file it leaves.
defaults delete com.filiphajduch.vitals.promo 2>/dev/null || true
rm -f ~/Library/Preferences/com.filiphajduch.vitals.promo.plist

echo "Screenshots in $OUT/"
