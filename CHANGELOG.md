# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.6] - 2026-03-01

### Fixed

- Prevented stale sunrise/sunset transition times from causing rapid refresh loops or requiring app restarts.
- Added additional solar scheduling guards for invalid/edge transition data and expanded unit test coverage.

## [0.0.5] - 2026-02-27

### Added

- SwiftLint and SwiftFormat tooling for consistent formatting and linting.

### Fixed

- Fixed permissions state getting lost after relaunch and cached last detected location to improve reliability.

### Changed

- Updated app bundle version metadata to `CFBundleShortVersionString = 0.0.5` and `CFBundleVersion = 5`.

## [0.0.4] - 2026-02-25

### Added

- New `About` settings tab with app metadata, GitHub link, and `happytoolin.com` link.
- Native update checks against the latest GitHub release with native macOS alert prompts and direct download action.
- Manual `Check for Updates...` action in both the right-click menu and the About tab.

### Changed

- Updated app bundle version metadata to `CFBundleShortVersionString = 0.0.4` and `CFBundleVersion = 4`.

## [0.0.3] - 2026-02-25

### Added

- Expanded schedule engine test coverage to 17 unit tests, including polar day/night transitions, midnight boundary transitions, and exact custom-time boundaries.
- New schedule branch tests for `.alwaysDark`, `.alwaysLight`, and mixed-day transitions to catch regressions in automatic appearance decisions.

### Changed

- Improved automatic solar scheduling logic so polar-edge cases now expose concrete next transitions (sunrise/sunset or midnight) instead of indefinite fixed states.
- Updated the menu bar summary label to reflect active automatic mode (`Sunrise/Sunset` vs `Custom light/dark times`).
- Updated the project generation script to default to Swift `5.10`.
- Refreshed README screenshots with current UI captures using London manual coordinates (`51.5074, -0.1278`).

### Fixed

- Reduced duplicate refresh/evaluation cycles when copying detected coordinates into manual fields by batching coordinate updates.
- Corrected inconsistent status messaging around “tomorrow always light” scheduling behavior.

## [0.0.1] - 2026-02-24

### Added

- Production-ready project structure for the macOS app source, resources, and config.
- Screenshot section in README with captured menu bar and settings screenshots.
- GitHub Actions CI workflow for macOS builds on pull requests and `main` pushes.
- GitHub Actions release workflow for `v*` tags to build, package, and publish release artifacts.
- Tap cask rendering helper script for automated Homebrew tap updates.
- Automatic scheduling mode selector with support for custom Light/Dark switch times.
- Unit test suite for schedule decision logic (`swift test`).

### Changed

- README expanded with architecture, build, release, and CI/CD documentation.
- Project generation script moved to `scripts/create_project.rb` and aligned with the new structure.
- Homebrew tap cask template now strips quarantine post-install for unsigned builds.
