#!/bin/bash

# Opera Full Uninstall Script (MDM-safe, multi-location, version-aware)

echo "===== Opera Uninstall Script ====="

# Version compare
version_lt() {
    [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" != "$2" ]
}

# Find ALL Opera app locations
echo "Searching for Opera installations..."

OPERA_PATHS=()

# System locations
[ -d "/Applications/Opera.app" ] && OPERA_PATHS+=("/Applications/Opera.app")
[ -d "/Applications/Opera GX.app" ] && OPERA_PATHS+=("/Applications/Opera GX.app")
[ -d "/Applications (Managed)/Opera.app" ] && OPERA_PATHS+=("/Applications (Managed)/Opera.app")

# User locations
for user_home in /Users/*; do
    [ -d "$user_home" ] || continue
    OPERA_USER_APP="$user_home/Applications/Opera.app"
    OPERA_GX_USER_APP="$user_home/Applications/Opera GX.app"

    [ -d "$OPERA_USER_APP" ] && OPERA_PATHS+=("$OPERA_USER_APP")
    [ -d "$OPERA_GX_USER_APP" ] && OPERA_PATHS+=("$OPERA_GX_USER_APP")
done

# Exit if nothing found
if [ ${#OPERA_PATHS[@]} -eq 0 ]; then
    echo "No Opera installations found. Exiting."
    exit 0
fi

echo "Found Opera installations:"
for path in "${OPERA_PATHS[@]}"; do
    echo " - $path"
done

echo "Proceeding with uninstall..."

# 🔥 Force kill ALL Opera processes (no prompts)
echo "Force quitting Opera..."

pkill -9 -f "Opera" 2>/dev/null

# Extra safety kills
killall -9 "Opera" 2>/dev/null
killall -9 "Opera Helper" 2>/dev/null
killall -9 "Opera Helper (Renderer)" 2>/dev/null
killall -9 "Opera Helper (GPU)" 2>/dev/null
killall -9 "Opera Helper (Plugin)" 2>/dev/null

# Wait until fully terminated
while pgrep -f "Opera" >/dev/null; do
    echo "Waiting for Opera to fully terminate..."
    sleep 1
done

echo "✓ Opera fully terminated"

# Remove ALL discovered app paths
echo "Removing Opera applications..."

for path in "${OPERA_PATHS[@]}"; do
    if [ -d "$path" ]; then
        rm -rf "$path"
        echo "✓ Removed $path"
    fi
done

# Remove user data
echo "Cleaning user data..."

for user_home in /Users/*; do
    if [ -d "$user_home" ] && [ ! -L "$user_home" ]; then
        username=$(basename "$user_home")

        if [ "$username" = "Shared" ] || [ "$username" = "Guest" ]; then
            continue
        fi

        echo "Cleaning Opera data for user: $username"

        rm -rf "$user_home/Library/Application Support/com.operasoftware.Opera" 2>/dev/null
        rm -rf "$user_home/Library/Caches/com.operasoftware.Opera" 2>/dev/null
        rm -rf "$user_home/Library/Saved Application State/com.operasoftware.Opera.savedState" 2>/dev/null
        rm -rf "$user_home/Library/Logs/Opera" 2>/dev/null
        rm -rf "$user_home/Library/WebKit/com.operasoftware.Opera" 2>/dev/null
        rm -f "$user_home/Library/Preferences/com.operasoftware.Opera.plist" 2>/dev/null
    fi
done

# Remove system-level items
echo "Cleaning system-level components..."

rm -rf "/Library/Application Support/Opera" 2>/dev/null

# Launch agents
if [ -f "/Library/LaunchAgents/com.operasoftware.Opera.plist" ]; then
    launchctl unload "/Library/LaunchAgents/com.operasoftware.Opera.plist" 2>/dev/null
    rm -f "/Library/LaunchAgents/com.operasoftware.Opera.plist"
fi

# User launch agents
for user_home in /Users/*; do
    plist="$user_home/Library/LaunchAgents/com.operasoftware.Opera.plist"
    if [ -f "$plist" ]; then
        launchctl unload "$plist" 2>/dev/null
        rm -f "$plist"
    fi
done

# Remove receipts
rm -f /private/var/db/receipts/com.operasoftware.* 2>/dev/null

echo ""
echo "===== Opera Uninstallation Complete ====="
exit 0
