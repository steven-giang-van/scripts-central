#!/bin/bash

TARGET_VERSION="ADD VERSION HERE"
CHROME_APP="/Applications/Google Chrome.app"
PLIST="$CHROME_APP/Contents/Info.plist"

echo "Checking installed Chrome version..."

# Function to compare versions
version_lt() {
    [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" != "$2" ]
}

# Check if Chrome exists
if [ ! -d "$CHROME_APP" ]; then
    echo "Chrome not installed. Proceeding with cleanup..."
else
    INSTALLED_VERSION=$(/usr/bin/defaults read "$PLIST" CFBundleShortVersionString 2>/dev/null)

    echo "Installed Chrome version: $INSTALLED_VERSION"
    echo "Target version: $TARGET_VERSION"

    if version_lt "$INSTALLED_VERSION" "$TARGET_VERSION"; then
        echo "Installed version is LESS than target. Proceeding with uninstall..."
    else
        echo "Installed version is up-to-date or newer. Exiting."
        exit 0
    fi
fi

echo "Starting Google Chrome uninstallation..."

# Close Chrome if running
if pgrep -x "Google Chrome" > /dev/null; then
    echo "Closing Google Chrome..."
    killall "Google Chrome" 2>/dev/null
    sleep 2
fi

# Close Chrome Helper processes
if pgrep "Google Chrome Helper" > /dev/null; then
    echo "Closing Chrome Helper processes..."
    killall "Google Chrome Helper" 2>/dev/null
    sleep 1
fi

# Remove Chrome application
if [ -d "/Applications/Google Chrome.app" ]; then
    echo "Removing Chrome application..."
    rm -rf "/Applications/Google Chrome.app"
    echo "✓ Chrome application removed"
else
    echo "Chrome application not found at /Applications/Google Chrome.app"
fi

# Remove user data for all users
for user_home in /Users/*; do
    if [ -d "$user_home" ] && [ ! -L "$user_home" ]; then
        username=$(basename "$user_home")
        
        # Skip system users
        if [ "$username" = "Shared" ] || [ "$username" = "Guest" ]; then
            continue
        fi
        
        echo "Cleaning Chrome data for user: $username"
        
        if [ -d "$user_home/Library/Application Support/Google/Chrome" ]; then
            rm -rf "$user_home/Library/Application Support/Google/Chrome"
            echo "  ✓ Removed Chrome user data"
        fi
        
        if [ -d "$user_home/Library/Caches/Google/Chrome" ]; then
            rm -rf "$user_home/Library/Caches/Google/Chrome"
            echo "  ✓ Removed Chrome cache"
        fi
        
        if [ -f "$user_home/Library/Preferences/com.google.Chrome.plist" ]; then
            rm -f "$user_home/Library/Preferences/com.google.Chrome.plist"
            echo "  ✓ Removed Chrome preferences"
        fi
        
        if [ -d "$user_home/Library/Saved Application State/com.google.Chrome.savedState" ]; then
            rm -rf "$user_home/Library/Saved Application State/com.google.Chrome.savedState"
            echo "  ✓ Removed Chrome saved state"
        fi
    fi
done

# Remove system-level Chrome items
echo "Removing system-level Chrome components..."

if [ -d "/Library/Google/GoogleSoftwareUpdate" ]; then
    rm -rf "/Library/Google/GoogleSoftwareUpdate"
    echo "✓ Removed Google Software Update"
fi

if [ -f "/Library/LaunchAgents/com.google.keystone.agent.plist" ]; then
    launchctl unload "/Library/LaunchAgents/com.google.keystone.agent.plist" 2>/dev/null
    rm -f "/Library/LaunchAgents/com.google.keystone.agent.plist"
    echo "✓ Removed Keystone Launch Agent"
fi

if [ -f "/Library/LaunchDaemons/com.google.keystone.daemon.plist" ]; then
    launchctl unload "/Library/LaunchDaemons/com.google.keystone.daemon.plist" 2>/dev/null
    rm -f "/Library/LaunchDaemons/com.google.keystone.daemon.plist"
    echo "✓ Removed Keystone Launch Daemon"
fi

if [ -d "/private/var/db/receipts" ]; then
    rm -f /private/var/db/receipts/com.google.Chrome.* 2>/dev/null
    rm -f /private/var/db/receipts/com.google.Keystone.* 2>/dev/null
    echo "✓ Removed installation receipts"
fi

echo ""
echo "Google Chrome uninstallation complete!"
exit 0
