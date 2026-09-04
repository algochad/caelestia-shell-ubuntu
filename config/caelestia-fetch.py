#!/usr/bin/env python3
"""
Caelestia Terminal Header
Merged from the official caelestia fastfetch config and our custom display:
smooth rounded boxes, Nerd Font icons, caelestia ASCII logo, full details.
"""

import os
import re
import shutil
import subprocess
import time


def run(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, text=True,
                                       stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""


def load_logo(path, color, default=None):
    """Load an ASCII logo from file and colorize non-space characters."""
    try:
        with open(os.path.expanduser(path), encoding="utf-8") as f:
            lines = f.read().splitlines()
    except Exception:
        lines = (default or "").splitlines()

    lines = [line.rstrip() for line in lines]
    while lines and not lines[0]:
        lines.pop(0)
    while lines and not lines[-1]:
        lines.pop()

    colored = []
    for line in lines:
        colored.append("".join(
            f"{color}{ch}\033[0m" if ch != " " else ch
            for ch in line
        ))
    return colored


def visual_width(s):
    """Display width ignoring ANSI SGR codes."""
    return len(re.sub(r"\x1b\[[0-9;]*m", "", s))


# ── Palette (bright truecolor — readable on any dark theme) ──
C_TITLE = "\033[38;2;125;211;252m"   # caelestia cyan
C_KEY   = "\033[38;2;168;171;185m"   # soft gray
C_VAL   = "\033[38;2;228;225;230m"   # near white
C_LOGO  = "\033[38;2;125;211;252m"   # caelestia cyan
C_ICON  = "\033[38;2;125;211;252m"
RST     = "\033[0m"

# ── Box drawing (smooth/rounded) ──
TL, TR, BL, BR = "╭", "╮", "╰", "╯"
HZ, VT, TJ, LJ = "─", "│", "├", "┤"


def gather():
    """Collect all system info. Returns list of (section, [(icon, key, value), ...])."""

    # OS / kernel
    os_name = run("lsb_release -d 2>/dev/null | cut -f2") or "Ubuntu"
    arch = run("uname -m") or "x86_64"
    kernel = run("uname -r")
    codename = run("lsb_release -cs 2>/dev/null")
    os_full = f"{os_name} ({codename})" if codename else os_name

    uptime = (run("uptime -p 2>/dev/null | sed 's/up //'")
              or run(r"uptime | sed 's/.*up \([^,]*\),.*/\1/'"))

    # OS age from rootfs birth time
    os_age = ""
    birth = run("stat -c %W / 2>/dev/null")
    if birth and birth.isdigit() and int(birth) > 0:
        days = (time.time() - int(birth)) / 86400
        os_age = f"{int(days)} days"

    # Packages
    dpkg = run("dpkg -l 2>/dev/null | wc -l") or "0"
    flat = run("flatpak list 2>/dev/null | wc -l") or "0"
    snap = run("snap list 2>/dev/null | wc -l") or "0"
    parts = []
    if int(dpkg) > 0:
        parts.append(f"{dpkg} (dpkg)")
    if int(flat) > 0:
        parts.append(f"{flat} (flatpak)")
    if int(snap) > 0:
        parts.append(f"{snap} (snap)")
    pkgs = ", ".join(parts) if parts else "0"

    user = os.environ.get("USER", run("echo $USER") or "user")
    host = run("hostnamectl hostname 2>/dev/null") or run("hostname")
    shell_name = os.path.basename(os.environ.get("SHELL", "bash"))
    if shell_name == "bash":
        bash_v = os.environ.get("BASH_VERSION", "").split("(")[0].strip() or "5"
        shell_ver = f"bash {bash_v}"
    else:
        shell_ver = shell_name

    # WM / terminal
    wm_raw = run("hyprctl version 2>/dev/null | head -1")
    m = re.search(r"Hyprland\s+(\S+)", wm_raw)
    wm = f"Hyprland {m.group(1)} (Wayland)" if m else "Hyprland (Wayland)"

    term = "kitty"
    if os.environ.get("KITTY_WINDOW_ID"):
        v = run("kitty --version 2>/dev/null | awk '{print $2}'")
        term = f"kitty {v}" if v else "kitty"
    elif os.environ.get("TERM_PROGRAM"):
        term = os.environ["TERM_PROGRAM"]

    # Hardware
    host_name = (run("cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null")
                 or "Unknown")

    cpu_model = run(
        "grep 'model name' /proc/cpuinfo 2>/dev/null | head -1 | "
        "cut -d: -f2 | sed 's/^ *//; s/  */ /g; s/(R)//g; s/(TM)//g; "
        "s/ CPU @//g' | cut -c1-40")
    cpu_cores = run("nproc 2>/dev/null") or "?"
    cpu_max = (run("lscpu 2>/dev/null | grep 'CPU max MHz' | "
                   "awk '{printf \"%.2f\", $4/1000}'")
               or run("grep 'cpu MHz' /proc/cpuinfo 2>/dev/null | head -1 | "
                      "cut -d: -f2 | awk '{printf \"%.2f\", $1/1000}'")
               or "?")
    cpu_short = re.sub(r"Intel Core i\d-", "i", cpu_model)
    cpu = f"{cpu_short} ({cpu_cores}c @ {cpu_max}GHz)"

    gpu_raw = run(r"lspci 2>/dev/null | grep -i 'vga\|3d\|display' | head -1")
    if gpu_raw:
        gpu_clean = re.sub(r"^\S+\s+\S+\s+controller:\s*", "", gpu_raw)
        gpu_clean = re.sub(r"\bCorporation\b", "", gpu_clean)
        mm = re.search(r"\[([^\]]+)\]", gpu_clean)
        gpu_name = mm.group(1).strip() if mm else gpu_clean.strip()
        if "Intel" in gpu_raw:
            gpu = f"Intel {gpu_name}"
        elif "NVIDIA" in gpu_raw or "GeForce" in gpu_raw or "RTX" in gpu_raw:
            gpu = f"NVIDIA {gpu_name}"
        elif "AMD" in gpu_raw or "Radeon" in gpu_raw:
            gpu = f"AMD {gpu_name}"
        else:
            gpu = gpu_name
    else:
        gpu = "Unknown"

    mem = run("free -h 2>/dev/null | awk '/^Mem:/{print $3\"/\"$2}'")
    zram = run("zramctl --noheadings 2>/dev/null | head -1 | awk '{print $4\"/\"$3}'")
    swap = run("free -h 2>/dev/null | awk '/^Swap:/{print $3\"/\"$2}'")
    memory = mem or "Unknown"
    zs_parts = []
    if zram:
        zs_parts.append(f"zram {zram}")
    if swap and swap != "0B/0B":
        zs_parts.append(f"swap {swap}")
    zram_swap = " · ".join(zs_parts) if zs_parts else ""

    disk = (run("df -h / 2>/dev/null | tail -1 | "
                "awk '{print $3 \" / \" $2 \" (\" $5 \")\"}'")
            or "Unknown")

    disp = (run(r"hyprctl monitors 2>/dev/null | grep -m1 'preferred|availableModes'") or "")
    if not disp:
        disp = (run(r"xrandr 2>/dev/null | grep '\*' | head -1 | awk '{print $1}'")
                or "Unknown")

    # Caelestia
    raw = run("caelestia scheme get 2>/dev/null")
    clean = re.sub(r"\x1b\[[0-9;]*m", "", raw)

    def pick(pat, default=""):
        m = re.search(pat, clean)
        return m.group(1) if m else default

    scheme = pick(r"Name:\s*(\S+)", "dynamic")
    flavour = pick(r"Flavour:\s*(\S+)", "default")
    mode = pick(r"Mode:\s*(\S+)", "dark")
    variant = pick(r"Variant:\s*(\S+)", "tonalspot")
    wall = run("caelestia wallpaper 2>/dev/null | head -1")
    wall = os.path.basename(wall) if wall else "default"

    shell_v = pick_ver = ""
    ver_out = run("caelestia --version 2>/dev/null")
    m = re.search(r"caelestia-shell\s+([\d.]+)", ver_out)
    shell_v = m.group(1) if m else "?"
    m = re.search(r"Quickshell\s+([\d.]+)", ver_out)
    qs_v = m.group(1) if m else "?"

    mode_icon = "\uf185" if mode == "light" else "\uf186"

    return [
        ("System", [
            ("\uf17c", "OS",       os_full),
            ("\uf2db", "Kernel",   kernel),
            ("\uf017", "Uptime",   uptime),
            ("\uf073", "OS Age",   os_age or "Unknown"),
            ("\uf1b2", "Packages", pkgs),
            ("\uf120", "Shell",    shell_ver),
            ("\uf2d2", "WM",       wm),
            ("\uf109", "Terminal", term),
            ("\uf007", "User",     f"{user}@{host}"),
        ]),
        ("Hardware", [
            ("\uf108", "Host",    host_name),
            ("\uf2db", "CPU",     cpu),
            ("\uf022", "GPU",     gpu),
            ("\uf1c0", "Memory",  memory),
            ("\uf233", "Zram/Swap", zram_swap or "none"),
            ("\uf0a0", "Disk",    disk),
            ("\uf26c", "Display", disp or "Unknown"),
        ]),
        ("Caelestia", [
            ("\uf1fc", "Scheme",     f"{scheme} ({flavour})"),
            ("\uf043", "Variant",    variant),
            (mode_icon, "Mode",      mode),
            ("\uf03e", "Wallpaper",  wall),
            ("\uf005", "Shell",      f"caelestia-shell {shell_v}"),
            ("\uf0e7", "Quickshell", f"v{qs_v}"),
        ]),
    ]


def render_box(title, rows, width, key_w):
    """Render one rounded box. Values right-aligned to the same column."""
    inner = width - 2
    # top border: ╭ + ─ + " Title " + ─*pad + ╮ must equal width
    title_part = f" {C_TITLE}{title}{RST} "
    pad = inner - visual_width(title_part) - 1
    top = f"{C_KEY}{TL}{HZ} {C_TITLE}{title}{RST} {HZ * pad}{TR}{RST}"

    lines = [top]
    for icon, key, val in rows:
        left = f"{VT}{RST} {C_ICON}{icon}{RST} {C_KEY}{key:<{key_w}}{RST}  "
        # row = left + value + " │"  →  value field = inner - vw(left)
        avail = inner - visual_width(left)
        v = str(val)
        if visual_width(v) > avail:
            v = v[:max(0, avail - 1)] + "…"
        vpad = avail - visual_width(v)
        lines.append(f"{left}{' ' * vpad}{C_VAL}{v}{RST} {C_KEY}{VT}{RST}")
    lines.append(f"{C_KEY}{BL}{HZ * inner}{BR}{RST}")
    return lines


def main():
    config_dir = os.environ.get(
        "XDG_CONFIG_HOME", os.path.expanduser("~/.config")) + "/caelestia"
    logo = load_logo(f"{config_dir}/caelestia_ascii.txt", C_LOGO)

    sections = gather()
    term_w = shutil.get_terminal_size((120, 24)).columns
    gap = 3
    logo_w = max((visual_width(l) for l in logo), default=0)

    # Box width: fit terminal beside the logo, else stack below
    side_by_side = term_w >= logo_w + 50
    box_w = min(72, term_w - logo_w - gap - 1) if side_by_side else min(72, term_w - 2)

    # Global key column width so every box's value column aligns vertically
    key_w = max(visual_width(k) for _, rows in sections for _, k, _ in rows)

    blocks = []
    for title, rows in sections:
        blocks.append(render_box(title, rows, box_w, key_w))
        blocks.append([""])

    print()
    if side_by_side:
        height = sum(len(b) for b in blocks)
        for i in range(height):
            idx = i
            line = ""
            for b in blocks:
                if idx < len(b):
                    line = b[idx]
                    break
                idx -= len(b)
            logo_line = logo[i] if i < len(logo) else " " * logo_w
            pad = " " * (logo_w - visual_width(logo_line))
            print(f"{logo_line}{pad}{' ' * gap}{line}")
    else:
        for l in logo:
            print(l)
        for b in blocks:
            for l in b:
                print(l)
    print()


if __name__ == "__main__":
    main()
