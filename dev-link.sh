#!/usr/bin/env bash
# Symlink this addon into your TBC Classic AddOns folder for live dev.
# Usage: ./dev-link.sh /path/to/World\ of\ Warcraft/_classic_/Interface/AddOns
# Run again after renaming the addon.

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <WoW AddOns directory>" >&2
  echo "Example: $0 '/mnt/c/Program Files (x86)/World of Warcraft/_classic_/Interface/AddOns'" >&2
  exit 1
fi

ADDONS_DIR="$1"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
ADDON_NAME="$(basename "$SRC_DIR")"
TARGET="$ADDONS_DIR/$ADDON_NAME"

if [[ ! -d "$ADDONS_DIR" ]]; then
  echo "Error: '$ADDONS_DIR' does not exist." >&2
  exit 1
fi

if [[ -L "$TARGET" ]]; then
  rm "$TARGET"
elif [[ -e "$TARGET" ]]; then
  echo "Error: '$TARGET' exists and is not a symlink. Refusing to overwrite." >&2
  exit 1
fi

ln -s "$SRC_DIR" "$TARGET"
echo "Linked: $TARGET -> $SRC_DIR"
echo "In-game: /reload   (or relog) to pick up changes."
