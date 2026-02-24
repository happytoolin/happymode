# Lighter (macOS menu bar)

A minimal native macOS menu bar app that switches system Light/Dark appearance based on sunrise/sunset.

## Features

- Menu bar app (`LSUIElement`) with no Dock icon.
- Auto location using CoreLocation.
- Manual latitude/longitude override.
- Sunrise/sunset calculation using a built-in solar algorithm (no external API).
- Applies macOS appearance through System Events AppleScript.

## Run

1. Open `/Users/atlantic/Developer/lighter/Lighter.xcodeproj` in Xcode.
2. Build and run the `Lighter` target.

Or from terminal:

```bash
cd /Users/atlantic/Developer/lighter
xcodebuild -project Lighter.xcodeproj -target Lighter -configuration Debug -sdk macosx build
open build/Debug/Lighter.app
```

## Required permissions

- Location permission: used to detect your current coordinates.
- Automation permission for System Events: required to change macOS dark mode.

If location is denied, open **Options...** and enter manual coordinates.
