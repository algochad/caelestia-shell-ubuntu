#!/usr/bin/env python3
"""
Caelestia Keybinds Cheatsheet
==============================

Prints a human-readable, categorized cheatsheet of:
  - Caelestia shell keybinds (from the caelestia dotfiles)
  - JaKooLit/Ubuntu-Hyprland default keybinds
  - Custom keybinds injected by the caelestia-shell-ubuntu installer

Usage:
  caelestia-keybinds            # print full cheatsheet
  caelestia-keybinds caelestia  # only Caelestia binds
  caelestia-keybinds hypr       # only Hyprland/JaKooLit binds
  caelestia-keybinds custom     # only installer custom binds

Can also be invoked as:
  caelestia keybinds [filter]
"""

import os
import re
import sys
from pathlib import Path

# ── Styling ─────────────────────────────────────────────────────────────────
RESET = "\033[0m"
BOLD = "\033[1m"
CYAN = "\033[0;36m"
BLUE = "\033[0;34m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
DIM = "\033[2m"


# ── Caelestia keybinds ───────────────────────────────────────────────────────
# Derived from caelestia-dots/caelestia hypr/variables.lua and hypr/hyprland/keybinds.lua.
# Each entry: (key, description, category)
CAELESTIA_KEYBINDS: list[tuple[str, str, str]] = [
    # Launcher & Menus
    ("SUPER + SUPER_L", "Open Caelestia launcher", "Launcher & Menus"),
    ("SUPER + N", "Open Caelestia sidebar / nexus", "Launcher & Menus"),
    ("SUPER + K", "Show all Caelestia panels", "Launcher & Menus"),
    ("CTRL + ALT + Delete", "Open Caelestia session menu", "Launcher & Menus"),
    ("CTRL + ALT + C", "Clear notifications", "Launcher & Menus"),

    # Session / Lock
    ("SUPER + L", "Lock screen", "Session & Lock"),
    ("SUPER + ALT + L", "Restore lock (restart shell + lock)", "Session & Lock"),
    ("SUPER + SHIFT + L", "Sleep / suspend-then-hibernate", "Session & Lock"),
    ("CTRL + SUPER + SHIFT + R", "Restart Caelestia shell", "Session & Lock"),
    ("CTRL + SUPER + ALT + R", "Kill + restart Caelestia shell", "Session & Lock"),

    # Workspaces
    ("SUPER + 1..0", "Go to workspace 1..10", "Workspaces"),
    ("CTRL + SUPER + 1..0", "Go to workspace group 1..10", "Workspaces"),
    ("SUPER + ALT + 1..0", "Move window to workspace 1..10", "Workspaces"),
    ("CTRL + SUPER + ALT + 1..0", "Move window to workspace group 1..10", "Workspaces"),
    ("SUPER + mouse_down / Page_Down", "Next workspace", "Workspaces"),
    ("SUPER + mouse_up / Page_Up", "Previous workspace", "Workspaces"),
    ("CTRL + SUPER + Right / Left", "Next / previous workspace", "Workspaces"),
    ("SUPER + ALT + mouse_down / Page_Down", "Move window to next workspace", "Workspaces"),
    ("SUPER + ALT + mouse_up / Page_Up", "Move window to previous workspace", "Workspaces"),
    ("CTRL + SUPER + mouse_down", "Next workspace group", "Workspaces"),
    ("CTRL + SUPER + mouse_up", "Previous workspace group", "Workspaces"),
    ("SUPER + ALT + S", "Move window to special workspace", "Workspaces"),
    ("CTRL + SUPER + SHIFT + Up", "Move window to special workspace (alt)", "Workspaces"),
    ("CTRL + SUPER + SHIFT + Down", "Move window from special workspace", "Workspaces"),

    # Special workspaces
    ("SUPER + S", "Toggle special workspace", "Special Workspaces"),
    ("CTRL + SHIFT + Escape", "Toggle system monitor workspace", "Special Workspaces"),
    ("SUPER + M", "Toggle music workspace", "Special Workspaces"),
    ("SUPER + D", "Toggle communication workspace", "Special Workspaces"),
    ("SUPER + R", "Toggle todo workspace", "Special Workspaces"),

    # Window focus
    ("SUPER + Left/Right/Up/Down", "Focus window in direction", "Window Focus"),
    ("ALT + Tab", "Cycle next window", "Window Focus"),
    ("SHIFT + ALT + Tab", "Cycle previous window", "Window Focus"),
    ("CTRL + ALT + Tab", "Cycle next window group", "Window Focus"),
    ("CTRL + SHIFT + ALT + Tab", "Cycle previous window group", "Window Focus"),

    # Window movement
    ("SUPER + SHIFT + Left/Right/Up/Down", "Move window", "Window Movement"),
    ("SUPER + CTRL + Left/Right/Up/Down", "Swap window", "Window Movement"),

    # Window actions
    ("SUPER + Q", "Close window", "Window Actions"),
    ("SUPER + F", "Fullscreen (borderless)", "Window Actions"),
    ("SUPER + ALT + F", "Bordered fullscreen (maximized)", "Window Actions"),
    ("SUPER + ALT + Space", "Toggle floating", "Window Actions"),
    ("SUPER + P", "Pin window", "Window Actions"),
    ("SUPER + ALT + Backslash", "Picture-in-picture mode", "Window Actions"),
    ("SUPER + C", "Center window", "Window Actions"),
    ("CTRL + SUPER + Backslash", "Center window", "Window Actions"),
    ("CTRL + SUPER + ALT + Backslash", "Normalize & center window", "Window Actions"),
    ("SUPER + U", "Ungroup window", "Window Actions"),
    ("SUPER + Comma", "Toggle group", "Window Actions"),
    ("SUPER + SHIFT + Comma", "Lock active group", "Window Actions"),
    ("SUPER + Minus / Equal", "Decrease / increase window width", "Window Actions"),
    ("SUPER + SHIFT + Minus / Equal", "Decrease / increase window height", "Window Actions"),
    ("SUPER + Z + drag", "Drag window", "Window Actions"),
    ("SUPER + X + drag", "Resize window", "Window Actions"),

    # Apps
    ("SUPER + T", "Open terminal", "Apps"),
    ("SUPER + W", "Open browser", "Apps"),
    ("SUPER + C", "Open editor", "Apps"),
    ("SUPER + E", "Open file explorer", "Apps"),
    ("CTRL + ALT + V", "Open audio settings", "Apps"),

    # Utilities
    ("Print", "Screenshot now", "Utilities"),
    ("SUPER + SHIFT + S", "Screenshot region (freeze)", "Utilities"),
    ("SUPER + SHIFT + ALT + S", "Screenshot region", "Utilities"),
    ("CTRL + ALT + R", "Start screen recording", "Utilities"),
    ("SUPER + ALT + R", "Record with sound", "Utilities"),
    ("SUPER + SHIFT + ALT + R", "Record region", "Utilities"),
    ("SUPER + SHIFT + C", "Color picker", "Utilities"),
    ("SUPER + V", "Clipboard history", "Utilities"),
    ("SUPER + ALT + V", "Delete clipboard entry", "Utilities"),
    ("CTRL + SHIFT + ALT + V", "Paste latest clipboard item", "Utilities"),
    ("SUPER + Period", "Emoji picker", "Utilities"),

    # Media
    ("CTRL + SUPER + Space", "Play / pause", "Media"),
    ("CTRL + SUPER + Equal", "Next track", "Media"),
    ("CTRL + SUPER + Minus", "Previous track", "Media"),
    ("CTRL + SUPER + Backspace", "Stop media", "Media"),
    ("XF86AudioPlay / Pause / Next / Prev", "Media keys", "Media"),

    # Volume / Brightness
    ("SUPER + SHIFT + M", "Mute audio", "Volume & Brightness"),
    ("XF86AudioMute", "Mute audio", "Volume & Brightness"),
    ("XF86AudioMicMute", "Mute mic", "Volume & Brightness"),
    ("XF86AudioRaiseVolume", "Volume up", "Volume & Brightness"),
    ("XF86AudioLowerVolume", "Volume down", "Volume & Brightness"),
    ("XF86MonBrightnessUp/Down", "Brightness up / down", "Volume & Brightness"),
]


# ── Custom installer keybinds ───────────────────────────────────────────────
# Added by the caelestia-shell-ubuntu installer in UserKeybinds.conf.
CUSTOM_KEYBINDS: list[tuple[str, str, str]] = [
    ("SUPER + SPACE", "Open Caelestia launcher", "Caelestia Custom"),
    ("SUPER + N", "Open Caelestia nexus", "Caelestia Custom"),
    ("SUPER + SHIFT + E", "Toggle session menu", "Caelestia Custom"),
    ("SUPER + L", "Lock screen", "Caelestia Custom"),
]


# ── Hyprland config parsing ──────────────────────────────────────────────────
HYPR_CONF_PATHS = [
    Path.home() / ".config/hypr/configs/Keybinds.conf",
    Path.home() / ".config/hypr/UserConfigs/UserKeybinds.conf",
]


def parse_hypr_keybinds(path: Path) -> list[tuple[str, str, str]]:
    """Parse bindd lines from a Hyprland .conf file.

    bindd = $mainMod, D, App launcher, exec, ...
    bindd = $mainMod SHIFT, E, Quick settings, exec, ...

    Returns list of (key, description, source).
    """
    keybinds: list[tuple[str, str, str]] = []
    if not path.exists():
        return keybinds

    main_mod = "SUPER"
    scripts_dir = ""
    user_scripts = ""
    user_configs = ""

    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            # variable assignments
            m = re.match(r"^\$mainMod\s*=\s*(\S+)", line)
            if m:
                main_mod = m.group(1)
            m = re.match(r"^\$scriptsDir\s*=\s*(\S+)", line)
            if m:
                scripts_dir = os.path.expandvars(m.group(1))
            m = re.match(r"^\$UserScripts\s*=\s*(\S+)", line)
            if m:
                user_scripts = os.path.expandvars(m.group(1))
            m = re.match(r"^\$UserConfigs\s*=\s*(\S+)", line)
            if m:
                user_configs = os.path.expandvars(m.group(1))
            continue

        # Match bindd lines with description
        # bindd = MOD, KEY, DESCRIPTION, ...
        # bindd = MOD MODIFIER, KEY, DESCRIPTION, ...
        m = re.match(
            r"^bindd\s*=\s*([^,]+),\s*([^,]+),\s*([^,]+)(?:,\s*(.+))?\s*$",
            line,
            re.IGNORECASE,
        )
        if m:
            mod_part = m.group(1).strip()
            key = m.group(2).strip()
            desc = m.group(3).strip()

            # Normalize $mainMod
            mod_part = mod_part.replace("$mainMod", main_mod)
            mod_part = mod_part.replace("$scriptsDir/", "")
            mod_part = mod_part.replace("$UserScripts/", "")
            mod_part = mod_part.replace("$UserConfigs/", "")

            # Build key combo
            mods = [p.strip() for p in mod_part.split()]
            combo = " + ".join([*mods, key]) if mods else key
            keybinds.append((combo, desc, str(path)))

    return keybinds


def collect_hypr_keybinds() -> list[tuple[str, str, str]]:
    """Collect keybinds from all Hyprland config files."""
    all_binds: list[tuple[str, str, str]] = []
    for path in HYPR_CONF_PATHS:
        all_binds.extend(parse_hypr_keybinds(path))
    return all_binds


# ── Output formatting ────────────────────────────────────────────────────────
def print_header(title: str) -> None:
    width = max(50, len(title) + 8)
    bar = "═" * width
    pad = " " * ((width - len(title)) // 2)
    print(f"{CYAN}{bar}{RESET}")
    print(f"{CYAN}{pad}{BOLD}{title}{RESET}{CYAN}{pad}{RESET}")
    print(f"{CYAN}{bar}{RESET}")


def print_section(name: str) -> None:
    print(f"\n{BOLD}{name}{RESET}")
    print(f"{DIM}{'─' * 60}{RESET}")


def print_keybind(key: str, desc: str) -> None:
    # Pad key to consistent width
    key_width = 28
    key_fmt = f"{GREEN}{key:<{key_width}}{RESET}"
    # Wrap description if too long
    max_desc = 70 - key_width
    if len(desc) <= max_desc:
        print(f"  {key_fmt} {desc}")
    else:
        words = desc.split()
        lines = [[]]
        for w in words:
            if sum(len(x) + 1 for x in lines[-1]) + len(w) > max_desc:
                lines.append([])
            lines[-1].append(w)
        for i, line in enumerate(lines):
            prefix = f"  {key_fmt} " if i == 0 else f"  {' ' * key_width}  "
            print(f"{prefix}{' '.join(line)}")


def print_cheatsheet(
    caelestia_binds: list[tuple[str, str, str]],
    custom_binds: list[tuple[str, str, str]],
    hypr_binds: list[tuple[str, str, str]],
) -> None:
    print_header("Caelestia Keybinds Cheatsheet")

    # Caelestia binds grouped by category
    categories: dict[str, list[tuple[str, str]]] = {}
    for key, desc, cat in caelestia_binds:
        categories.setdefault(cat, []).append((key, desc))
    for cat in sorted(categories):
        if categories[cat]:
            print_section(cat)
            for key, desc in categories[cat]:
                print_keybind(key, desc)

    # Custom installer binds
    if custom_binds:
        print_section("Caelestia Custom (Installer Added)")
        for key, desc, _ in custom_binds:
            print_keybind(key, desc)

    # Hyprland / JaKooLit binds grouped by source file
    if hypr_binds:
        print_section("JaKooLit / Hyprland Defaults")
        seen: set[str] = set()
        for key, desc, source in hypr_binds:
            # Avoid duplicate combos with same description
            sig = f"{key}|{desc}"
            if sig in seen:
                continue
            seen.add(sig)
            print_keybind(key, desc)

    print(f"\n{DIM}Tip: Run `caelestia keybinds [caelestia|hypr|custom]` to filter.{RESET}\n")


# ── Entry point ──────────────────────────────────────────────────────────────
def main(argv: list[str]) -> int:
    filt = argv[1].lower() if len(argv) > 1 else "all"

    caelestia_binds = CAELESTIA_KEYBINDS if filt in ("all", "caelestia") else []
    custom_binds = CUSTOM_KEYBINDS if filt in ("all", "custom") else []
    hypr_binds = collect_hypr_keybinds() if filt in ("all", "hypr") else []

    print_cheatsheet(caelestia_binds, custom_binds, hypr_binds)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv))
    except BrokenPipeError:
        # Gracefully handle piped output (e.g. `caelestia keybinds | head`)
        sys.stderr.close()
        sys.exit(0)
