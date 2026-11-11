#!/bin/sh
# Takes the App Store screenshots on a 6.9" iPhone simulator.
#
# Builds the app in Debug, launches it once per screenshot scene (see
# Metronome/Screenshots/ScreenshotScene.swift) with sample presets and a clean
# status bar, and saves one PNG per scene in screenshots/, numbered in App Store
# order, without an alpha channel. Old PNGs in screenshots/ are removed first.
#
# It uses a simulator of its own, "Metronome screenshots", created on the first
# run and set to US English so the status bar reads 9:41. Your other simulators
# are not touched.
#
# Environment:
#   SCREENSHOT_DEVICE_TYPE  device type for the simulator (default: iPhone 17 Pro Max)
#   SCREENSHOT_DELAY        seconds to wait before each capture (default: 3)
cd "$(dirname "$0")/.." || exit 1

sim="Metronome screenshots"
device_type="${SCREENSHOT_DEVICE_TYPE:-iPhone 17 Pro Max}"
delay="${SCREENSHOT_DELAY:-3}"
bundle_id=com.metsahalme.metronome
scenes="playing library setlist timeSignature settings"
app=build/DerivedData/Build/Products/Debug-iphonesimulator/Metronome.app

mkdir -p build screenshots
rm -f screenshots/*.png
echo "Building"
if ! xcodebuild build \
  -project Metronome.xcodeproj \
  -scheme Metronome \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/DerivedData > build/screenshots.log 2>&1; then
  grep -E 'error:|\*\* BUILD' build/screenshots.log | tail -20
  exit 1
fi

boot() {
  xcrun simctl boot "$sim" 2>/dev/null
  xcrun simctl bootstatus "$sim" -b > /dev/null
}

if ! xcrun simctl list devices | grep -q "$sim ("; then
  echo "Creating the $sim simulator ($device_type)"
  xcrun simctl create "$sim" "$device_type" > /dev/null || exit 1
fi
boot || exit 1

# The status bar takes the region format only after a restart.
if [ "$(xcrun simctl spawn "$sim" defaults read -g AppleLocale 2>/dev/null)" != en_US ]; then
  xcrun simctl spawn "$sim" defaults write -g AppleLanguages -array en-US
  xcrun simctl spawn "$sim" defaults write -g AppleLocale en_US
  xcrun simctl shutdown "$sim"
  boot || exit 1
fi

xcrun simctl ui "$sim" appearance dark
xcrun simctl status_bar "$sim" override \
  --time 9:41 \
  --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 \
  --batteryState charged --batteryLevel 100 || exit 1
xcrun simctl install "$sim" "$app" || exit 1

status=0
number=1
for scene in $scenes; do
  file="screenshots/$number-$scene.png"
  xcrun simctl terminate "$sim" "$bundle_id" 2>/dev/null
  xcrun simctl launch "$sim" "$bundle_id" -screenshotScene "$scene" > /dev/null || { status=1; break; }
  sleep "$delay"
  if xcrun simctl io "$sim" screenshot --type=png "$file" > /dev/null 2>&1; then
    echo "Saved $file"
  else
    echo "Could not capture $scene"
    status=1
  fi
  number=$((number + 1))
done

xcrun simctl terminate "$sim" "$bundle_id" 2>/dev/null
xcrun simctl shutdown "$sim"

# App Store Connect rejects screenshots with an alpha channel.
xcrun swift scripts/flatten-png.swift screenshots/*.png || status=1
exit $status
