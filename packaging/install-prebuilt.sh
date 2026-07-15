#!/bin/bash
# Installs the prebuilt sprint-souls binary (shipped next to this script) as a
# LaunchAgent so it runs at login and stays in the background.
# This is the install.sh bundled inside release tarballs — no build step needed.
set -euo pipefail

cd "$(dirname "$0")"

LABEL="com.yassine.sprint-souls"
INSTALL_DIR="$HOME/.local/share/sprint-souls"
BIN="$INSTALL_DIR/sprint-souls"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

echo "Installing binary to $BIN"
mkdir -p "$INSTALL_DIR"
# Stop a previous instance before overwriting the binary.
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
cp sprint-souls "$BIN"
chmod +x "$BIN"
[ -f icon.png ] && cp icon.png "$INSTALL_DIR/icon.png"
# Clear the quarantine flag browsers add so Gatekeeper doesn't block the agent.
xattr -d com.apple.quarantine "$BIN" 2>/dev/null || true

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
echo "Click the flame icon in the menu bar to set your sprint schedule."
echo "Preview the animation with: $BIN --preview"
