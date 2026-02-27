# happymode

[![CI](https://github.com/happytoolin/happymode/actions/workflows/ci.yml/badge.svg)](https://github.com/happytoolin/happymode/actions/workflows/ci.yml)
[![Release](https://github.com/happytoolin/happymode/actions/workflows/release.yml/badge.svg)](https://github.com/happytoolin/happymode/actions/workflows/release.yml)
[![Latest release](https://img.shields.io/github/v/release/happytoolin/happymode?display_name=tag)](https://github.com/happytoolin/happymode/releases)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

Native macOS menu bar app that controls Light/Dark appearance based on sunrise/sunset or custom daily times.

![happymode OG image](docs/og-image.png)

## Highlights

- Menu bar utility (no Dock icon) with popup controls and right-click context menu.
- `Auto`, `Light`, and `Dark` modes.
- Two scheduling options:
  - `Sunrise and sunset` (automatic by location or manual coordinates).
  - `Custom times` (user-defined daily switch times).
- Countdown in the menu bar for time remaining to next sunrise/sunset transition.
- Local solar calculations (no external API calls).

## Install

### Homebrew (recommended)

```bash
brew tap happytoolin/happytap
brew install --cask happymode
```

### Direct download

Download the latest build from [Releases](https://github.com/happytoolin/happymode/releases), then move `happymode.app` to `/Applications`.

## First launch on macOS

If Gatekeeper blocks launch, use one of these:

1. Open `System Settings -> Privacy & Security` and click `Open Anyway`.
2. Right-click `happymode.app` in `/Applications`, then click `Open`.

If needed:

```bash
xattr -dr com.apple.quarantine "/Applications/happymode.app"
```

## Usage

1. Launch `happymode`.
2. Click the menu bar icon to open the popup.
3. Set `Mode` to `Auto`, `Light`, or `Dark`.
4. In `Auto`, choose either:
   - `Sunrise and sunset`
   - `Custom times`
5. Open `Options...` for location/manual coordinates and permission setup.
6. (Optional) In `Settings -> General`, enable `Start happymode at login`.

## Screenshots

![Menu bar](docs/screenshots/menu-bar.png)
![Options popup](docs/screenshots/settings.png)

## Permissions

- `Automation -> System Events`: required to apply macOS appearance.
- `Location Services`: required only for `Sunrise and sunset` in automatic location mode.

If location is denied, disable automatic location and set manual latitude/longitude in `Options...`.

## Development

### Requirements

- macOS 15+
- Xcode 16+
- Swift 5.10+

### Build (Debug)

```bash
xcodebuild \
  -project happymode.xcodeproj \
  -scheme happymode \
  -configuration Debug \
  -sdk macosx \
  CODE_SIGNING_ALLOWED=NO \
  SYMROOT="$PWD/build" \
  clean build
```

### Run tests

```bash
swift test
```

## Release

Releases are automated with GitHub Actions on version tags (`v*`).

1. Merge changes to `main`.
2. Tag and push:

```bash
git tag v0.0.4
git push origin v0.0.4
```

The release workflow publishes:

- `happymode-vX.Y.Z.zip`
- `happymode-vX.Y.Z.sha256`
- `happymode-latest.zip`

To auto-update the Homebrew tap cask, set repository secret:

- `TAP_GITHUB_TOKEN` (write access to `happytoolin/homebrew-happytap`)

If this secret is missing, the release still succeeds and tap update is skipped.

## Troubleshooting

- App does not switch appearance:
  - Open `Options...`, grant Automation permission, and allow `happymode` under Privacy settings.
- Sunrise/sunset schedule is unavailable:
  - Grant Location permission or switch to manual coordinates/custom times.

## License

Licensed under [GNU GPL v3](LICENSE).
