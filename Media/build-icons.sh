#!/usr/bin/env bash
# Renders icon.svg into PNG sizes used by CurseForge / addon listings.
# Requires rsvg-convert (preferred) or ImageMagick.

set -euo pipefail
cd "$(dirname "$0")"

SRC="icon.svg"
SIZES=(512 256 128 64 32)

if command -v rsvg-convert >/dev/null; then
  TOOL="rsvg-convert"
elif command -v magick >/dev/null; then
  TOOL="magick"
elif command -v convert >/dev/null; then
  TOOL="convert"
else
  echo "Need one of: rsvg-convert, magick, convert" >&2
  exit 1
fi

for s in "${SIZES[@]}"; do
  OUT="icon-${s}.png"
  case "$TOOL" in
    rsvg-convert) rsvg-convert -w "$s" -h "$s" "$SRC" -o "$OUT" ;;
    magick)       magick -background none -density 600 "$SRC" -resize "${s}x${s}" "$OUT" ;;
    convert)      convert -background none -density 600 "$SRC" -resize "${s}x${s}" "$OUT" ;;
  esac
  echo "wrote $OUT"
done
