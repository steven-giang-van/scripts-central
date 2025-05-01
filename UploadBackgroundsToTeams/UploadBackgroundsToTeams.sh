#!/bin/bash

# Get current user and home directory
loggedInUser=$(stat -f %Su /dev/console)
userHome=$(dscl . -read /Users/"$loggedInUser" NFSHomeDirectory | awk '{print $2}')

# Create folders
DESKTOP_BG_FOLDER="$userHome/Desktop/Backgrounds"
TARGET="$userHome/Library/Containers/com.microsoft.teams2/Data/Library/Application Support/Microsoft/MSTeams/Backgrounds/Uploads"
mkdir -p "$DESKTOP_BG_FOLDER"
mkdir -p "$TARGET"

# Raw GitHub links for images
imageLinks=(
  "https://raw.githubusercontent.com/steven-giang-van/BackgroundImages/main/Slingshot%20Space%20Backround%204.jpg"
  "https://raw.githubusercontent.com/steven-giang-van/BackgroundImages/main/Slingshot%20Stars%20Backround%205.jpg"
  "https://raw.githubusercontent.com/steven-giang-van/BackgroundImages/main/Telescope%20Slingshot%20Backround%206.jpg"
  "https://raw.githubusercontent.com/steven-giang-van/BackgroundImages/main/Zoom%20Background%201.png"
  "https://raw.githubusercontent.com/steven-giang-van/BackgroundImages/main/Zoom%20Background%202.png"
  "https://raw.githubusercontent.com/steven-giang-van/BackgroundImages/main/Zoom%20Background%203.png"
  "https://raw.githubusercontent.com/steven-giang-van/BackgroundImages/main/Zoom%20Background%204.png"
)

echo "📥 Downloading images to $DESKTOP_BG_FOLDER..."
for url in "${imageLinks[@]}"; do
  filename=$(basename "${url%%\?*}") # Strip URL params
  destPath="$DESKTOP_BG_FOLDER/$filename"
  curl -L -o "$destPath" "$url"
done

# Copy images to processing target folder
echo "📄 Copying downloaded images to Teams background folder..."
cp "$DESKTOP_BG_FOLDER"/*.{jpg,jpeg,png,bmp} "$TARGET" 2>/dev/null

# Constants
MAX_SIZE=2048
THUMB_SIZE=280

# Process each copied image
echo "🧬 Processing and renaming images..."
for img in "$TARGET"/*.{jpg,jpeg,png,bmp}; do
  [[ -e "$img" ]] || continue

  uuid=$(uuidgen)
  newImage="$TARGET/${uuid}.jpg"
  newThumb="$TARGET/${uuid}_thumb.jpg"

  echo "🎨 Creating image: $(basename "$newImage")"
  sips -s format jpeg -Z $MAX_SIZE "$img" --out "$newImage" >/dev/null

  echo "🖼 Creating thumbnail: $(basename "$newThumb")"
  sips -s format jpeg -Z $THUMB_SIZE "$newImage" --out "$newThumb" >/dev/null

  # Clean up copied file
  rm "$img"
done

# Final permissions
chown "$loggedInUser" "$TARGET"/*.{jpg,jpeg,png,bmp} 2>/dev/null
chmod 644 "$TARGET"/*.{jpg,jpeg,png,bmp} 2>/dev/null

echo "✅ Images downloaded to Desktop, duplicated for Teams, processed with UUIDs and thumbnails!"
