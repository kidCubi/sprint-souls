#!/bin/bash
# Builds sprint-souls and installs it as a LaunchAgent so it runs at login
# and stays in the background watching for unlock/wake.
set -euo pipefail

cd "$(dirname "$0")"

LABEL="com.yassine.sprint-souls"
INSTALL_DIR="$HOME/.local/share/sprint-souls"
BIN="$INSTALL_DIR/sprint-souls"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

echo "Building..."
swift build -c release

echo "Installing binary to $BIN"
mkdir -p "$INSTALL_DIR"
# Stop a previous instance before overwriting the binary.
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
cp .build/release/SprintSouls "$BIN"
[ -f icon.png ] && cp icon.png "$INSTALL_DIR/icon.png"

echo "Writing LaunchAgent $PLIST"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BIN</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>StandardErrorPath</key>
    <string>/tmp/sprint-souls.log</string>
</dict>
</plist>
EOF

launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo
echo "Installed. Config lives at ~/.config/sprint-souls/config.json"
echo "Preview the animation with: $BIN --preview"
