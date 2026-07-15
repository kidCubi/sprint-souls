#!/bin/bash
set -euo pipefail

LABEL="com.yassine.sprint-souls"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$PLIST"
rm -rf "$HOME/.local/share/sprint-souls"
echo "Uninstalled. Config kept at ~/.config/sprint-souls (delete it manually if you want)."
