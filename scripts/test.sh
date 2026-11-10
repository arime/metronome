#!/bin/sh
# Runs the unit tests on the iPhone 17 Pro simulator.
# Full output goes to build/test.log; only a summary is printed.
cd "$(dirname "$0")/.." || exit 1
mkdir -p build
xcodebuild test \
  -project Metronome.xcodeproj \
  -scheme Metronome \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build/DerivedData \
  "$@" > build/test.log 2>&1
status=$?
grep -E 'error:|warning:|✘|recorded an issue|Test run with|\*\* TEST|\*\* BUILD' build/test.log \
  | grep -v 'not stripping binary' | tail -40
exit $status
