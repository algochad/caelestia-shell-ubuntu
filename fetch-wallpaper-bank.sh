#!/usr/bin/env bash
# ==================================================
#  Caelestia Shell Ubuntu — optional wallpaper pack
# ==================================================
# Downloads the JaKooLit "Wallpaper-Bank" image collection
# (https://github.com/JaKooLit/Wallpaper-Bank) into the Caelestia wallpaper
# directory as a convenience. ONLY image files are copied — no scripts,
# configs, README, branding or dotfiles — and the clone is removed afterwards.
#
# The upstream repo carries no explicit licence, so the pack is fetched from
# the original source at install/update time instead of being vendored.
#
# Usage:
#   ./fetch-wallpaper-bank.sh [target-dir]
#   WALLPAPER_BANK=1 ./install.sh        (runs this as an installer step)
#
# Default target: $HOME/Pictures/wallpapers (CAELESTIA_WALLPAPERS_DIR)

set -euo pipefail

BANK_REPO="https://github.com/JaKooLit/Wallpaper-Bank.git"
BANK_BRANCH="main"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-wallpaper-bank"
TARGET_DIR="${1:-$HOME/Pictures/wallpapers}"
EXTENSIONS='\.(png|jpe?g|webp)$'

mkdir -p "$TARGET_DIR"

if [[ ! -d "$CACHE_DIR/.git" ]]; then
    rm -rf "$CACHE_DIR"
    echo "[INFO] Cloning Wallpaper-Bank (≈1 GB) — this can take a while..."
    git clone --depth 1 --single-branch --branch "$BANK_BRANCH" "$BANK_REPO" "$CACHE_DIR"
fi

added=0
skipped=0
# Copy images only, preserving subdirectories; never overwrite existing files.
while IFS= read -r -d '' src; do
    rel="${src#"$CACHE_DIR"/}"
    dst="$TARGET_DIR/$rel"
    mkdir -p "$(dirname "$dst")"
    if [[ -e "$dst" ]]; then
        skipped=$((skipped + 1))
    else
        cp -f "$src" "$dst"
        added=$((added + 1))
    fi
done < <(find "$CACHE_DIR/wallpapers" -type f -regextype posix-extended -iregex ".*$EXTENSIONS" -print0)

rm -rf "$CACHE_DIR"
echo "[OK] Wallpaper-Bank: $added added, $skipped already present in $TARGET_DIR"
