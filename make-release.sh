#!/bin/bash
# Builds a universal (arm64 + x86_64) release tarball into dist/.
# Usage: ./make-release.sh [version]   (default 0.1.0)
set -euo pipefail

cd "$(dirname "$0")"

VERSION="${1:-0.1.0}"
PKG="sprint-souls-${VERSION}-macos"

echo "Building universal binary..."
swift build -c release --arch arm64 --arch x86_64

rm -rf "dist/$PKG"
mkdir -p "dist/$PKG"
cp .build/apple/Products/Release/SprintSouls "dist/$PKG/sprint-souls"
cp icon.png sound.mp3 uninstall.sh README.md "dist/$PKG/"
cp packaging/install-prebuilt.sh "dist/$PKG/install.sh"
chmod +x "dist/$PKG/install.sh" "dist/$PKG/uninstall.sh" "dist/$PKG/sprint-souls"

tar -czf "dist/$PKG.tar.gz" -C dist "$PKG"
echo
echo "Created dist/$PKG.tar.gz"
echo "Publish it with: gh release create v$VERSION dist/$PKG.tar.gz --title \"v$VERSION\""
