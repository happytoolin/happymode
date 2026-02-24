# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1] - 2026-02-24

### Added

- Production-ready project structure for the macOS app source, resources, and config.
- Screenshot section in README with captured menu bar and settings screenshots.
- GitHub Actions CI workflow for macOS builds on pull requests and `main` pushes.
- GitHub Actions release workflow for `v*` tags to build, package, and publish release artifacts.
- Tap cask rendering helper script for automated Homebrew tap updates.

### Changed

- README expanded with architecture, build, release, and CI/CD documentation.
- Project generation script moved to `scripts/create_project.rb` and aligned with the new structure.
