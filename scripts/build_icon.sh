#!/usr/bin/env bash
# Rebuild the monochrome Waybar mark from the favicon served by the official
# OpenAI Codex documentation page.
set -euo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
ASSET_DIR="$PROJECT_DIR/assets"
SOURCE_URL=https://developers.openai.com/favicon.png
SOURCE="$ASSET_DIR/codex-official-favicon.png"
OUTPUT="$ASSET_DIR/codex-mark-white.png"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

command -v curl >/dev/null || { printf 'curl is required.\n' >&2; exit 1; }
command -v magick >/dev/null || { printf 'ImageMagick (magick) is required.\n' >&2; exit 1; }

mkdir -p "$ASSET_DIR"
curl -LfsS "$SOURCE_URL" -o "$SOURCE"

# The official favicon is a white knot on #0080F7. Composite transparency onto
# that blue, measure each pixel's difference from blue as an alpha mask, then
# force the visible channels to white. Trim and place the 14px mark on a 16px
# transparent canvas for Waybar.
magick "$SOURCE" \
    -background '#0080F7' -alpha background -alpha remove -alpha off \
    "$TEMP_DIR/flat.png"
magick "$TEMP_DIR/flat.png" \
    \( +clone -fill '#0080F7' -colorize 100 \) \
    -compose difference -composite -colorspace gray -auto-level \
    "$TEMP_DIR/mask.png"
magick "$TEMP_DIR/mask.png" \
    -alpha copy -channel RGB -fill white -colorize 100 \
    -trim +repage -resize '14x14' -gravity center -background none -extent 16x16 \
    -strip -define png:exclude-chunks=date,time \
    "$OUTPUT"

printf 'Built %s from %s\n' "$OUTPUT" "$SOURCE_URL"
