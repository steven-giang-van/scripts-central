#!/bin/bash

TARGET_VERSION="ADD VERSION HERE"
APP="/Applications/Firefox.app"
PLIST="$APP/Contents/Info.plist"

echo "Checking Firefox version..."

# Version compare
version_lt() {
    [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" != "$2" ]
}

# Exit if not installed
if [ ! -d "$APP" ]; then
    echo "Firefox not installed. Exiting."
    exit 0
fi

# Get version safely
INSTALLED_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST" 2>/dev/null)

if [ -z "$INSTALLED_VERSION" ]; then
    echo "Could not determine Firefox version. Exiting to avoid bad uninstall."
    exit 1
fi

echo "Installed: $INSTALLED_VERSION | Target: $TARGET_VERSION"

if ! version_lt "$INSTALLED_VERSION" "$TARGET_VERSION"; then
    echo "Firefox is up-to-date. Exiting."
    exit 0
fi

echo "Proceeding with uninstall..."

# Kill ALL Firefox processes
echo "Killing Firefox processes..."
pkill -f firefox
sleep 2

# Ensure processes are gone
while pgrep -f firefox >/dev/null; do
    echo "Waiting for Firefox to exit..."
    sleep 1
done

# Remove app
rm -rf "$APP"
echo "✓ Firefox removed"

exit 0
