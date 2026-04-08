#!/bin/bash
set -e

APP_NAME="Vitals"
VERSION="${1:-1.0}"
DMG_NAME="${APP_NAME}-v${VERSION}.dmg"
ARCHIVE_PATH="/tmp/${APP_NAME}.xcarchive"
STAGING_DIR="/tmp/dmg-staging"

echo "Building ${APP_NAME} v${VERSION}..."

# Generate Xcode project
xcodegen generate

# Archive
xcodebuild -project ${APP_NAME}.xcodeproj \
    -scheme ${APP_NAME} \
    -configuration Release \
    archive -archivePath "${ARCHIVE_PATH}" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" \
    -quiet

echo "Creating DMG..."

# Prepare staging directory
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"
cp -R "${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app" "${STAGING_DIR}/"

# Add Applications symlink for drag-to-install
ln -s /Applications "${STAGING_DIR}/Applications"

# Create DMG
rm -f "/tmp/${DMG_NAME}"
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov -format UDZO \
    "/tmp/${DMG_NAME}"

# Cleanup
rm -rf "${STAGING_DIR}" "${ARCHIVE_PATH}"

echo ""
echo "Done! DMG created at /tmp/${DMG_NAME}"
ls -lh "/tmp/${DMG_NAME}"
