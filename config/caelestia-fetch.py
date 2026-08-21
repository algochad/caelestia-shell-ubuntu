#!/usr/bin/env python3
"""
Caelestia Shell Info Display
Fastfetch-style terminal header with Ubuntu logo + system info + caelestia details.
Called from ~/.bashrc on interactive shell startup.
"""

import os
import re
import shutil
import subprocess
import sys


def run(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""


def ansi(r, g, b):
    return f"\033[38;2;{r};{g};{b}m"


def main():
    # ── Colors ──
    c_primary = ansi(180, 199, 237)   # scheme primary
    c_secondary = ansi(168, 171, 185)
    c_bright = ansi(228, 225, 230)
    c_orange = ansi(233, 84, 32)      # Ubuntu
    c_cyan = ansi(100, 200, 255)      # Caelestia
    reset = "\033[0m"
    bold = "\033[1m"

    # ── Caelestia scheme info ──
    scheme_raw = run("caelestia scheme get 2>/dev/null")
    # strip ANSI codes
    scheme_clean = re.sub(r'\x1b\[[0-9;]*m', '', scheme_raw)
    scheme_name = re.search(r'Name:\s*(\S+)', scheme_clean)
    scheme_name = scheme_name.group(1) if scheme_name else "dynamic"
    scheme_flavour = re.search(r'Flavour:\s*(\S+)', scheme_clean)
    scheme_flavour = scheme_flavour.group(1) if scheme_flavour else "default"
    mode_line = re.search(r'Mode:\s*(\S+)', scheme_clean)
    mode_line = mode_line.group(1) if mode_line else "dark"
    variant_line = re.search(r'Variant:\s*(\S+)', scheme_clean)
    variant_line = variant_line.group(1) if variant_line else "tonalspot"
    wall_line = run("caelestia wallpaper 2>/dev/null | head -1")
    wall_display = os.path.basename(wall_line) if wall_line else "default"

    # ── System info ──
    os_name = run("lsb_release -d 2>/dev/null | cut -f2") or "Ubuntu 26.04 LTS"
    kernel = run("uname -r")
    uptime = run("uptime -p 2>/dev/null | sed 's/up //'") or run("uptime | sed 's/.*up \\([^,]*\\),.*/\\1/'")
    shell_name = os.path.basename(os.environ.get("SHELL", "bash"))
    wm_name = "Hyprland"
    terminal_name = "kitty"

    cpu_info = run("grep 'model name' /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | sed 's/^ *//; s/  */ /g; s/(R)//g; s/(TM)//g; s/ CPU @//g; s/ GHz/ GHz/' | cut -c1-35")
    mem_info = run("free -h 2>/dev/null | awk '/^Mem:/{print $3 \"/\" $2}'")
    disk_info = run("df -h / 2>/dev/null | tail -1 | awk '{print $3 \"/\" $2 \" (\" $5 \")\"}'")

    # ── Box-drawing helpers ──
    top_l = "┌"; top_r = "┐"; bot_l = "└"; bot_r = "┘"
    horiz = "─"; vert = "│"
    tee_r = "├"; tee_l = "┤"
    branch = "├"; last_branch = "└"

    # ── Ubuntu logo (fastfetch style, using safe chars) ──
    ubuntu_logo = [
        "        ..;,; .,;,.        ",
        "     .,lool: .ooooo,       ",
        "    ;oo;:    .coool.       ",
        "  ....         ''' ,l;     ",
        " :oooo,            'oo.    ",
        " looooc            :oo'    ",
        "  '::'             ,oo:    ",
        "    ,.,       .... co,     ",
        "     lo:;.   :oooo; .      ",
        "      ':ooo; cooooc        ",
        "         '''  ''''         ",
    ]

    # ── Build sections ──
    def fmt(icon, key, val, col_key=c_secondary, col_val=c_bright):
        return f" {icon}  {col_key}{key}{reset}  {col_val}{val}{reset}"

    def border(title, width=48):
        pad = width - len(title) - 2
        return f"{c_secondary}{top_l}{horiz}{title}{horiz * pad}{top_r}{reset}"

    def bottom(width=48):
        return f"{c_secondary}{bot_l}{horiz * (width - 2)}{bot_r}{reset}"

    # Print everything
    print()

    # Hardware section
    hw_title = f"Hardware"
    hw_lines = [
        fmt("", "CPU", cpu_info, c_primary, c_bright),
        fmt("󰍛", "Memory", mem_info, c_primary, c_bright),
        fmt("", "Disk", disk_info, c_primary, c_bright),
    ]

    # Software section
    sw_title = f"Software"
    sw_lines = [
        fmt("", "OS", os_name, c_primary, c_bright),
        f" {c_secondary}{branch}{reset} {fmt('', 'Kernel', kernel, c_primary, c_bright)}",
        f" {c_secondary}{branch}{reset} {fmt('', 'Shell', f'{shell_name} 5.3.9', c_primary, c_bright)}",
        fmt("", "WM", f"{wm_name} 0.53.3 (Wayland)", c_primary, c_bright),
        f" {c_secondary}{branch}{reset} {fmt('', 'DM', 'gdm-password 50.0', c_primary, c_bright)}",
        f" {c_secondary}{last_branch}{reset} {fmt('', 'Terminal', 'kitty 0.45.0', c_primary, c_bright)}",
    ]

    # Uptime section
    up_lines = [
        fmt("", "Uptime", uptime, c_secondary, c_bright),
        fmt("", "OS Age", "114 days", c_secondary, c_bright),
    ]

    # Caelestia section
    cae_lines = [
        fmt("󰏘", "Scheme", f"{scheme_name} ({scheme_flavour})", c_cyan, c_bright),
        fmt("󰔎", "Variant", variant_line, c_cyan, c_bright),
        fmt("󰖨", "Mode", mode_line, c_cyan, c_bright),
        fmt("󰸉", "Wallpaper", wall_display, c_cyan, c_bright),
        fmt("", "Shell", "caelestia-shell 2.3.0", c_cyan, c_bright),
        fmt("", "Quickshell", "v0.3.0", c_cyan, c_bright),
    ]

    # Determine max line count for alignment
    max_lines = max(len(ubuntu_logo), len(hw_lines) + len(sw_lines) + len(up_lines) + len(cae_lines) + 6)

    # Print logo left, sections right
    section_idx = 0
    all_sections = [
        (border(hw_title), hw_lines, bottom()),
        (border(sw_title), sw_lines, bottom()),
        (border("Uptime / Age / DT"), up_lines, bottom()),
        (border("Caelestia"), cae_lines, bottom()),
    ]

    section_data = []
    for header, lines, footer in all_sections:
        section_data.append(header)
        section_data.extend(lines)
        section_data.append(footer)
        section_data.append("")

    for i in range(max(max_lines, len(section_data))):
        logo_part = ubuntu_logo[i] if i < len(ubuntu_logo) else " " * 27
        sec_part = section_data[i] if i < len(section_data) else ""
        print(f"{c_orange}{logo_part}{reset}  {sec_part}")

    print()


if __name__ == "__main__":
    main()
