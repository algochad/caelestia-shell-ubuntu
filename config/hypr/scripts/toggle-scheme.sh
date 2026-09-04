#!/usr/bin/env bash
# Toggle caelestia colour scheme between dark and light, preserving the scheme name.
mode="$(caelestia scheme get 2>/dev/null | awk '/Mode:/ {print $2}')"
if [[ "$mode" == "dark" ]]; then
    caelestia scheme set -m light
else
    caelestia scheme set -m dark
fi
