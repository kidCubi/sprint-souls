#!/bin/bash
# One-line installer for sprint-souls:
#
#   curl -fsSL https://raw.githubusercontent.com/kidCubi/sprint-souls/main/get.sh | bash
#
# Downloads the latest prebuilt release (universal macOS binary) and installs
# it as a LaunchAgent. Falls back to building from source if no release exists
# (that path requires the Xcode Command Line Tools).
set -euo pipefail

REPO="kidCubi/sprint-souls"

if [ "$(uname -s)" != "Darwin" ]; then
    echo "sprint-souls is macOS-only." >&2
    exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ASSET_URL="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null \
    | grep -o '"browser_download_url": *"[^"]*macos\.tar\.gz"' \
    | head -1 | sed 's/.*"\(https[^"]*\)"/\1/' || true)"

if [ -n "${ASSET_URL:-}" ]; then
    echo "Downloading prebuilt release..."
    curl -fsSL "$ASSET_URL" -o "$TMP/pkg.tar.gz"
    tar -xzf "$TMP/pkg.tar.gz" -C "$TMP"
    "$TMP"/sprint-souls-*/install.sh
else
    echo "No prebuilt release found — building from source instead."
    if ! command -v swift >/dev/null 2>&1; then
        echo "swift not found. Install the Xcode Command Line Tools first:" >&2
        echo "    xcode-select --install" >&2
        exit 1
    fi
    curl -fsSL "https://github.com/$REPO/archive/refs/heads/main.tar.gz" -o "$TMP/src.tar.gz"
    tar -xzf "$TMP/src.tar.gz" -C "$TMP"
    "$TMP/sprint-souls-main/install.sh"
fi
