# happymode (macOS menu bar)

A minimal native macOS menu bar app that switches system Light/Dark appearance based on sunrise/sunset.

## Features

- Menu bar app (`LSUIElement`) with no Dock icon.
- Auto location using CoreLocation.
- Manual latitude/longitude override.
- Sunrise/sunset calculation using the Solar package algorithm (vendored source, no external API).
- Applies macOS appearance through System Events AppleScript.

## Run

1. Open `/Users/atlantic/Developer/happymode/happymode.xcodeproj` in Xcode.
2. Build and run the `happymode` target.

Or from terminal:

```bash
cd /Users/atlantic/Developer/happymode
xcodebuild -project happymode.xcodeproj -target happymode -configuration Debug -sdk macosx build
open build/Debug/happymode.app
```

## Required permissions

- Location permission: used to detect your current coordinates.
- Automation permission for System Events: required to change macOS dark mode.

If location is denied, open **Options...** and enter manual coordinates.
