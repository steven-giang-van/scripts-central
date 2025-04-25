#!/bin/bash

# Get current user and home directory
loggedInUser=$(stat -f %Su /dev/console)
userHome=$(dscl . -read /Users/"$loggedInUser" NFSHomeDirectory | awk '{print $2}')

# Target folder for Teams backgrounds
TARGET="$userHome/Library/Containers/com.microsoft.teams2/Data/Library/Application Support/Microsoft/MSTeams/Backgrounds/Uploads"
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

echo "📥 Downloading images..."
for url in "${imageLinks[@]}"; do
  filename=$(basename "${url%%\?*}") # Strip URL params
  tempPath="$TARGET/$filename"
  curl -L -o "$tempPath" "$url"
done

# Constants
MAX_SIZE=2048
THUMB_SIZE=280

# Process each downloaded image
echo "🧬 Processing and renaming images..."
for img in "$TARGET"/*.{jpg,jpeg,png,bmp}; do
  [[ -e "$img" ]] || continue

  uuid=$(uuidgen)
  newImage="$TARGET/${uuid}.jpg"
  newThumb="$TARGET/${uuid}_thumb.jpg"

  echo "🎨 Creating image: $(basename "$newImage")"
  # Convert to jpg and resize if necessary
  sips -s format jpeg -Z $MAX_SIZE "$img" --out "$newImage" >/dev/null

  echo "🖼 Creating thumbnail: $(basename "$newThumb")"
  sips -s format jpeg -Z $THUMB_SIZE "$newImage" --out "$newThumb" >/dev/null

  # Clean up original file
  rm "$img"
done

# Final permissions
chown "$loggedInUser" "$TARGET"/*.{jpg,jpeg,png,bmp} 2>/dev/null
chmod 644 "$TARGET"/*.{jpg,jpeg,png,bmp} 2>/dev/null

echo "✅ Teams backgrounds uploaded with UUIDs and thumbnails created!"
