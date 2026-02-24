# happymode

A native macOS menu bar app that automatically switches Light/Dark appearance based on sunrise/sunset or custom daily times.

## What it does

- Runs as a menu bar utility (`LSUIElement`), without a Dock icon.
- Uses CoreLocation for automatic coordinates.
- Supports manual coordinate fallback and override.
- Supports custom Light/Dark switch times that do not require location.
- Calculates solar transitions locally (vendored Solar implementation, no network dependency).
- Applies system appearance through AppleScript (`System Events`).

## Requirements

- macOS 14.0+
- Xcode 16+
- Swift 5+

## Quick start

### Xcode

1. Open `happymode.xcodeproj`.
2. Select the `happymode` scheme.
3. Build and run.

### Terminal

```bash
xcodebuild \
  -project happymode.xcodeproj \
  -scheme happymode \
  -configuration Debug \
  -sdk macosx \
  build

open build/Debug/happymode.app
```

### Run tests

```bash
swift test
```

## Project structure

```text
happymode/
├── happymode.xcodeproj/
├── happymode/
│   ├── App/
│   │   └── HappymodeApp.swift
│   ├── Features/
│   │   ├── MenuBar/
│   │   │   └── MenuBarView.swift
│   │   └── Settings/
│   │       └── SettingsView.swift
│   ├── Core/
│   │   ├── Theme/
│   │   │   └── ThemeController.swift
│   │   └── Solar/
│   │       ├── SolarCalculator.swift
│   │       └── SolarPackage.swift
│   ├── Resources/
│   │   └── Assets.xcassets/
│   └── Config/
│       └── Info.plist
├── scripts/
│   └── create_project.rb
├── Package.swift
├── happymodeTests/
│   └── AppearanceScheduleEngineTests.swift
└── README.md
```

## Screenshots

Add screenshots to `docs/screenshots/` with these file names:

- `menu-bar.png`
- `settings.png`

Then this README will render them:

![happymode menu bar](docs/screenshots/menu-bar.png)
![happymode settings](docs/screenshots/settings.png)

## Permissions and privacy

- `Location Services`: required only when using `Auto` + `Sunrise/Sunset`.
- `Automation -> System Events`: required to apply macOS Light/Dark mode.

If location permission is denied, use manual latitude/longitude in `Options...`.

## Build and release

### Debug build

```bash
xcodebuild -project happymode.xcodeproj -scheme happymode -configuration Debug -sdk macosx build
```

### Release build

```bash
xcodebuild -project happymode.xcodeproj -scheme happymode -configuration Release -sdk macosx build
```

## CI/CD

GitHub Actions workflows are included:

- `CI` (`.github/workflows/ci.yml`): builds on every pull request and on pushes to `main`.
- `Release` (`.github/workflows/release.yml`): runs when a tag like `v1.2.3` is pushed, builds a release artifact, publishes a GitHub Release, and updates the Homebrew tap cask.

### Release flow

1. Push changes to `main`.
2. Create and push a version tag:

```bash
git tag v1.0.0
git push origin v1.0.0
```

3. GitHub Actions will publish:
   - `happymode-v1.0.0.zip`
   - `happymode-v1.0.0.sha256`
   - `happymode-latest.zip`

### Required secret for tap updates

Set this repository secret in GitHub:

- `TAP_GITHUB_TOKEN`: a token with write access to `happytoolin/happytap`.

If the secret is missing, release still succeeds, but tap update is skipped.

## Troubleshooting

- App does not switch appearance:
  - Open `Options...`, click `Grant` under Automation, and allow `happymode` in macOS Privacy settings.
- Automatic location is unavailable:
  - Grant Location permission or disable automatic location and set manual coordinates.
