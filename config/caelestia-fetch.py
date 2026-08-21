#!/usr/bin/env python3
"""
Caelestia Shell Info Display
Fastfetch-style: Ubuntu logo beside Hardware+Software, then Caelestia logo beside Uptime+Caelestia.
"""

import os
import re
import subprocess


def run(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, text=True,
                                       stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""


def ansi(r, g, b):
    return f"\033[38;2;{r};{g};{b}m"


def main():
    # ── Colors ──
    c_pri = ansi(180, 199, 237)
    c_sec = ansi(168, 171, 185)
    c_bri = ansi(228, 225, 230)
    c_org = ansi(233, 84, 32)     # Ubuntu
    c_cya = ansi(100, 200, 255)   # Caelestia
    rst = "\033[0m"

    # ── Caelestia info ──
    raw = run("caelestia scheme get 2>/dev/null")
    clean = re.sub(r'\x1b\[[0-9;]*m', '', raw)

    def pick(pat, default=""):
        m = re.search(pat, clean)
        return m.group(1) if m else default

    scheme_name    = pick(r'Name:\s*(\S+)',     "dynamic")
    scheme_flavour = pick(r'Flavour:\s*(\S+)',  "default")
    mode_line      = pick(r'Mode:\s*(\S+)',     "dark")
    variant_line   = pick(r'Variant:\s*(\S+)', "tonalspot")
    wall_line      = run("caelestia wallpaper 2>/dev/null | head -1")
    wall_display   = os.path.basename(wall_line) if wall_line else "default"

    # ── System info ──
    os_name   = run("lsb_release -d 2>/dev/null | cut -f2") or "Ubuntu 26.04 LTS"
    kernel    = run("uname -r")
    uptime    = (run("uptime -p 2>/dev/null | sed 's/up //'")
                 or run("uptime | sed 's/.*up \\([^,]*\\),.*/\\1/'"))
    shell_name = os.path.basename(os.environ.get("SHELL", "bash"))
    cpu_info  = run(
        "grep 'model name' /proc/cpuinfo 2>/dev/null | head -1 | "
        "cut -d: -f2 | sed 's/^ *//; s/  */ /g; s/(R)//g; s/(TM)//g; "
        "s/ CPU @//g; s/ GHz/ GHz/' | cut -c1-35")
    mem_info  = run("free -h 2>/dev/null | awk '/^Mem:/{print $3 \"/\" $2}'")
    disk_info = run(
        "df -h / 2>/dev/null | tail -1 | "
        "awk '{print $3 \"/\" $2 \" (\" $5 \")\"}'")

    # ── Box-drawing ──
    tl, tr, bl, br, hz = "┌", "┐", "└", "┘", "─"
    tee, lst = "├", "└"

    # ── Ubuntu logo (11 lines) ──
    UB = [
        "         ..,;,  .,;,.         ",
        "       .,lool;  .ooooo,        ",
        "      ;oo;:.    .coool.        ",
        "    ....          ''' ,l;      ",
        "   :oooo,             'oo.     ",
        "   looooc             :oo'     ",
        "    '::'              ,oo:     ",
        "      ,.,        .... co,      ",
        "       lo:;.   .oooo; .        ",
        "        ':ooo;  cooooc         ",
        "           '''  ''''           ",
    ]

    # ── Caelestia diamond (9 lines) ──
    CA = [
        "               .               ",
        "             .:::              ",
        "           .::::::             ",
        "         .::::::::::.          ",
        "       .::::::**::::::.        ",
        "         ::::::::::::          ",
        "           ::::::::            ",
        "             :::::             ",
        "               :               ",
    ]

    def fmt(icon, key, val, ck=c_sec, cv=c_bri):
        return f" {icon}  {ck}{key}{rst}  {cv}{val}{rst}"

    def border(title, w=48):
        return f"{c_sec}{tl}{hz}{title}{hz * (w - len(title) - 2)}{tr}{rst}"

    def bottom(w=48):
        return f"{c_sec}{bl}{hz * (w - 2)}{br}{rst}"

    # ── Build sections ──
    hw = [
        fmt("", "CPU",    cpu_info,  c_pri, c_bri),
        fmt("󰍛", "Memory", mem_info,  c_pri, c_bri),
        fmt("󰋊", "Disk",   disk_info, c_pri, c_bri),
    ]
    sw = [
        fmt("", "OS",  os_name, c_pri, c_bri),
        f" {c_sec}{tee}{rst} {fmt('', 'Kernel', kernel, c_pri, c_bri)}",
        f" {c_sec}{tee}{rst} {fmt('', 'Shell',
                                    f'{shell_name} 5.3.9', c_pri, c_bri)}",
        fmt("", "WM", "Hyprland 0.53.3 (Wayland)", c_pri, c_bri),
        f" {c_sec}{tee}{rst} {fmt('', 'DM',
                                    'gdm-password 50.0', c_pri, c_bri)}",
        f" {c_sec}{lst}{rst} {fmt('', 'Terminal',
                                    'kitty 0.45.0', c_pri, c_bri)}",
    ]
    up = [
        fmt("󱫠", "Uptime", uptime,      c_sec, c_bri),
        fmt("󰔚", "OS Age", "114 days",  c_sec, c_bri),
    ]
    ca = [
        fmt("󰏘", "Scheme",    f"{scheme_name} ({scheme_flavour})",
            c_cya, c_bri),
        fmt("󰔎", "Variant",   variant_line,                       c_cya, c_bri),
        fmt("󰖨", "Mode",      mode_line,                          c_cya, c_bri),
        fmt("󰸉", "Wallpaper", wall_display,                       c_cya, c_bri),
        fmt("", "Shell",     "caelestia-shell 2.3.0",            c_cya, c_bri),
        fmt("", "Quickshell", "v0.3.0",                          c_cya, c_bri),
    ]

    # ── Layout 1: Ubuntu logo + Hardware + Software ──
    right1 = [border("Hardware")] + hw + [bottom()] + [border("Software")] + sw + [bottom()]
    total1 = max(len(UB), len(right1))

    # ── Layout 2: Caelestia logo + Uptime + Caelestia ──
    right2 = [border("Uptime / Age / DT")] + up + [bottom()] + [border("Caelestia")] + ca + [bottom()]
    total2 = max(len(CA), len(right2))

    # ── Render block 1: Ubuntu ──
    print()
    for i in range(total1):
        logo = f"{c_org}{UB[i]}{rst}" if i < len(UB) else " " * 31
        info = right1[i] if i < len(right1) else ""
        print(f"{logo}  {info}")

    # ── Render block 2: Caelestia ──
    for i in range(total2):
        logo = f"{c_cya}{CA[i]}{rst}" if i < len(CA) else " " * 31
        info = right2[i] if i < len(right2) else ""
        print(f"{logo}  {info}")

    print()


if __name__ == "__main__":
    main()
