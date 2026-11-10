#!/bin/sh
# Builds the app for the iPhone simulator.
# The app ends up in build/DerivedData/Build/Products/Debug-iphonesimulator/Metronome.app
cd "$(dirname "$0")/.." || exit 1
mkdir -p build
xcodebuild build \
  -project Metronome.xcodeproj \
  -scheme Metronome \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/DerivedData \
  "$@" > build/build.log 2>&1
status=$?
grep -E 'error:|warning:|\*\* BUILD' build/build.log | grep -v 'appintentsmetadataprocessor' | tail -40
exit $status
