#!/usr/bin/env bash
# ==================================================
#  Caelestia (Ubuntu port) — Game Mode
#  Replaces JaKooLit GameMode.sh: no swaync icon,
#  no swww/awww/wallust/Refresh pipeline (the shell
#  owns wallpaper and notifications). Disable simply
#  reloads the Hyprland config to restore everything.
# ==================================================

icon="$HOME/.config/caelestia/logo.png"

# Are animations currently enabled?
state=$(hyprctl getoption animations:enabled | awk 'NR==1{print $2}')

if [[ "$state" == "1" || "$state" == "true" ]]; then
    # ENABLE Game Mode (disable animations/decorations/gaps)
    hyprctl keyword animations:enabled 0 >/dev/null 2>&1
    hyprctl keyword decoration:shadow:enabled 0 >/dev/null 2>&1
    hyprctl keyword decoration:blur:enabled 0 >/dev/null 2>&1
    hyprctl keyword general:gaps_in 0 >/dev/null 2>&1
    hyprctl keyword general:gaps_out 0 >/dev/null 2>&1
    hyprctl keyword general:border_size 1 >/dev/null 2>&1
    hyprctl keyword decoration:rounding 0 >/dev/null 2>&1
    hyprctl keyword 'windowrule opacity 1 override 1 override 1 override, ^(.*)$' >/dev/null 2>&1
    notify-send -e -u low -i "$icon" "Gamemode:" "enabled"
else
    # DISABLE Game Mode: full config reload restores animations, decorations,
    # gaps, borders and clears the windowrule override.
    hyprctl reload >/dev/null 2>&1
    notify-send -e -u normal -i "$icon" "Gamemode:" "disabled"
fi
exit 0
