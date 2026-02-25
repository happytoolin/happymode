#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  echo "Usage: $0 <version> <sha256> [repo]" >&2
  echo "Example: $0 0.0.4 deadbeef... happytoolin/happymode" >&2
  exit 1
fi

VERSION="$1"
SHA256="$2"
REPO="${3:-happytoolin/happymode}"

cat <<EOF
cask "happymode" do
  version "${VERSION}"
  sha256 "${SHA256}"

  url "https://github.com/${REPO}/releases/download/v#{version}/happymode-v#{version}.zip"
  name "happymode"
  desc "Menu bar app that switches Light/Dark mode based on sunrise and sunset"
  homepage "https://github.com/${REPO}"

  app "happymode.app"

  # Unsigned app: strip quarantine so Homebrew installs run without manual Gatekeeper bypass.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/happymode.app"]
  end

  caveats <<~EOS
    happymode is distributed unsigned (no Apple Developer ID).
    If macOS still blocks launch on your machine, run:
      xattr -dr com.apple.quarantine "/Applications/happymode.app"
  EOS
end
EOF
