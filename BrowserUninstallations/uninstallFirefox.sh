#!/bin/bash

# Firefox Uninstall Script for macOS
# Designed for MDM deployment with sudo privileges

echo "Starting Firefox uninstallation..."

# Close Firefox if running
if pgrep -x "firefox" > /dev/null; then
    echo "Closing Firefox..."
    killall "firefox" 2>/dev/null
    sleep 2
fi

# Close any Firefox helper processes
if pgrep "plugin-container" > /dev/null; then
    echo "Closing Firefox plugin containers..."
    killall "plugin-container" 2>/dev/null
    sleep 1
fi

# Remove Firefox application
if [ -d "/Applications/Firefox.app" ]; then
    echo "Removing Firefox application..."
    rm -rf "/Applications/Firefox.app"
    echo "✓ Firefox application removed"
else
    echo "Firefox application not found at /Applications/Firefox.app"
fi

# Remove user data for all users
for user_home in /Users/*; do
    if [ -d "$user_home" ] && [ ! -L "$user_home" ]; then
        username=$(basename "$user_home")
        
        # Skip system users
        if [ "$username" = "Shared" ] || [ "$username" = "Guest" ]; then
            continue
        fi
        
        echo "Cleaning Firefox data for user: $username"
        
        # Remove Firefox profiles and data
        if [ -d "$user_home/Library/Application Support/Firefox" ]; then
            rm -rf "$user_home/Library/Application Support/Firefox"
            echo "  ✓ Removed Firefox user data"
        fi
        
        # Remove Firefox caches
        if [ -d "$user_home/Library/Caches/Firefox" ]; then
            rm -rf "$user_home/Library/Caches/Firefox"
            echo "  ✓ Removed Firefox cache"
        fi
        
        if [ -d "$user_home/Library/Caches/Mozilla" ]; then
            rm -rf "$user_home/Library/Caches/Mozilla"
            echo "  ✓ Removed Mozilla cache"
        fi
        
        # Remove Firefox preferences
        if [ -f "$user_home/Library/Preferences/org.mozilla.firefox.plist" ]; then
            rm -f "$user_home/Library/Preferences/org.mozilla.firefox.plist"
            echo "  ✓ Removed Firefox preferences"
        fi
        
        # Remove Firefox saved state
        if [ -d "$user_home/Library/Saved Application State/org.mozilla.firefox.savedState" ]; then
            rm -rf "$user_home/Library/Saved Application State/org.mozilla.firefox.savedState"
            echo "  ✓ Removed Firefox saved state"
        fi
        
        # Remove Firefox crash reports
        if [ -d "$user_home/Library/Application Support/CrashReporter/Firefox_*.plist" ]; then
            rm -f "$user_home/Library/Application Support/CrashReporter/Firefox_"*.plist 2>/dev/null
            echo "  ✓ Removed Firefox crash reports"
        fi
        
        # Remove Mozilla folder (contains Firefox data)
        if [ -d "$user_home/Library/Mozilla" ]; then
            rm -rf "$user_home/Library/Mozilla"
            echo "  ✓ Removed Mozilla folder"
        fi
    fi
done

# Remove system-level Firefox items
echo "Removing system-level Firefox components..."

# Remove receipts
if [ -d "/private/var/db/receipts" ]; then
    rm -f /private/var/db/receipts/org.mozilla.firefox.* 2>/dev/null
    echo "✓ Removed installation receipts"
fi

# Remove any Firefox-related Launch Agents/Daemons (if present)
for plist in /Library/LaunchAgents/org.mozilla.* /Library/LaunchDaemons/org.mozilla.*; do
    if [ -f "$plist" ]; then
        launchctl unload "$plist" 2>/dev/null
        rm -f "$plist"
        echo "✓ Removed $(basename "$plist")"
    fi
done

echo ""
echo "Firefox uninstallation complete!"
exit 0
