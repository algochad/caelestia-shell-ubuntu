#!/usr/bin/env python3
"""
Caelestia Shell Info Display
Fastfetch-style terminal header with high-res ASCII art logos.
"""

import os
import re
import shutil
import subprocess


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

    # Trim trailing whitespace, keep leading whitespace for positioning
    lines = [line.rstrip() for line in lines]

    # Drop empty leading/trailing lines
    while lines and not lines[0]:
        lines.pop(0)
    while lines and not lines[-1]:
        lines.pop()

    # Colorize every non-space character
    colored = []
    for line in lines:
        colored.append("".join(
            f"{color}{ch}{'\033[0m'}" if ch != " " else ch
            for ch in line
        ))
    return colored


def visual_width(s):
    """Approximate display width ignoring ANSI SGR codes."""
    return len(re.sub(r'\x1b\[[0-9;]*m', '', s))


def main():
    c_pri = "\033[38;2;180;199;237m"
    c_sec = "\033[38;2;168;171;185m"
    c_bri = "\033[38;2;228;225;230m"
    c_org = "\033[38;2;255;107;53m"      # Ubuntu orange
    c_cya = "\033[38;2;125;211;252m"     # Caelestia cyan
    rst = "\033[0m"

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

    os_name   = run("lsb_release -d 2>/dev/null | cut -f2") or "Ubuntu 26.04 LTS"
    kernel    = run("uname -r")
    uptime    = (run("uptime -p 2>/dev/null | sed 's/up //'")
                 or run(r"uptime | sed 's/.*up \([^,]*\),.*/\1/'"))
    shell_name = os.path.basename(os.environ.get("SHELL", "bash"))

    host_name = run("cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null") or "Unknown"

    disp_raw = run(r"xrandr 2>/dev/null | grep '\*' | head -1 | awk '{print $1}'")
    disp_info = disp_raw or run(
        "xdpyinfo 2>/dev/null | grep 'dimensions:' | head -1 | awk '{print $2}'"
    ) or "1920x1080"

    dpkg_count = run("dpkg -l 2>/dev/null | wc -l") or "0"
    flat_count = run("flatpak list 2>/dev/null | wc -l") or "0"
    snap_count = run("snap list 2>/dev/null | wc -l") or "0"
    pkg_parts = []
    if int(dpkg_count) > 0:
        pkg_parts.append(f"{dpkg_count} (dpkg)")
    if int(flat_count) > 0:
        pkg_parts.append(f"{flat_count} (flatpak)")
    if int(snap_count) > 0:
        pkg_parts.append(f"{snap_count} (snap)")
    pkg_info = ", ".join(pkg_parts) if pkg_parts else "0"

    cpu_model = run(
        "grep 'model name' /proc/cpuinfo 2>/dev/null | head -1 | "
        "cut -d: -f2 | sed 's/^ *//; s/  */ /g; s/(R)//g; s/(TM)//g; "
        "s/ CPU @//g; s/ GHz/ GHz/' | cut -c1-40")
    cpu_cores = run("nproc 2>/dev/null") or "?"
    cpu_max   = run(
        "lscpu 2>/dev/null | grep 'CPU max MHz' | "
        "awk '{printf \"%.2f\", $4/1000}'"
    ) or run(
        "grep 'cpu MHz' /proc/cpuinfo 2>/dev/null | head -1 | "
        "cut -d: -f2 | awk '{printf \"%.2f\", $1/1000}'"
    ) or "?"
    cpu_short = re.sub(r'Intel Core i\d-', 'i', cpu_model)
    cpu_info  = f"{cpu_short} ({cpu_cores}c @ {cpu_max}GHz)"

    gpu_raw = run(r"lspci 2>/dev/null | grep -i 'vga\|3d\|display' | head -1")
    if gpu_raw:
        gpu_clean = re.sub(r'^\S+\s+\S+\s+controller:\s*', '', gpu_raw)
        gpu_clean = re.sub(r'\bCorporation\b', '', gpu_clean)
        m = re.search(r'\[([^\]]+)\]', gpu_clean)
        gpu_name = m.group(1).strip() if m else gpu_clean.strip()
        if 'Intel' in gpu_raw:
            gpu_info = f"Intel {gpu_name}"
        elif 'NVIDIA' in gpu_raw or 'GeForce' in gpu_raw or 'RTX' in gpu_raw:
            gpu_info = f"NVIDIA {gpu_name}"
        elif 'AMD' in gpu_raw or 'Radeon' in gpu_raw:
            gpu_info = f"AMD {gpu_name}"
        else:
            gpu_info = gpu_name
        gpu_info = gpu_info[:55]
    else:
        gpu_info = "Unknown"

    mem_info = run("free -h 2>/dev/null | awk '/^Mem:/{print $3 \"/\" $2}'")
    zram_raw = run("zramctl --noheadings 2>/dev/null | head -1 | awk '{print $4 \"/\" $3}'")
    zram_info = f"zram {zram_raw}" if zram_raw else ""
    swap_raw = run("free -h 2>/dev/null | awk '/^Swap:/{print $3 \"/\" $2}'")
    swap_info = f"swap {swap_raw}" if swap_raw and swap_raw != "0B/0B" else ""
    parts = [p for p in [mem_info, zram_info, swap_info] if p]
    mem_swap = " | ".join(parts)

    disk_info = run(
        "df -h / 2>/dev/null | tail -1 | "
        "awk '{print $3 \"/\" $2 \" (\" $5 \")\"}'")

    arch = run("uname -m") or "x86_64"
    codename = run("lsb_release -cs 2>/dev/null") or ""
    if codename:
        os_full = f"{os_name} ({codename}) [{arch}]"
    else:
        os_full = f"{os_name} [{arch}]"

    # ── High-res ASCII logos ──
    config_dir = os.environ.get(
        "XDG_CONFIG_HOME", os.path.expanduser("~/.config")) + "/caelestia"
    UB = load_logo(f"{config_dir}/ubuntu_ascii.txt", c_org)
    CA = load_logo(f"{config_dir}/caelestia_ascii.txt", c_cya)

    tl, tr, bl, br, hz = "┌", "┐", "└", "┘", "─"
    tee, lst = "├", "└"

    def fmt(icon, key, val, ck=c_sec, cv=c_bri):
        return f" {icon}  {ck}{key}{rst}  {cv}{val}{rst}"

    def border(title, w):
        pad = max(0, w - len(title) - 2)
        return f"{c_sec}{tl}{hz}{title}{hz * pad}{tr}{rst}"

    def bottom(w):
        return f"{c_sec}{bl}{hz * (w - 2)}{br}{rst}"

    hw = [
        fmt("󰌢", "Host",   host_name, c_pri, c_bri),
        fmt("", "CPU",    cpu_info,  c_pri, c_bri),
        fmt("󰢮", "GPU",    gpu_info,  c_pri, c_bri),
        fmt("󰍛", "Memory", mem_swap,  c_pri, c_bri),
        fmt("󰋊", "Disk",   disk_info, c_pri, c_bri),
        fmt("󰹑", "Display", disp_info, c_pri, c_bri),
    ]
    sw = [
        fmt("", "OS",  os_full, c_pri, c_bri),
        f" {c_sec}{tee}{rst} {fmt('', 'Kernel', kernel, c_pri, c_bri)}",
        f" {c_sec}{tee}{rst} {fmt('󰏗', 'Packages', pkg_info, c_pri, c_bri)}",
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
            c_pri, c_bri),
        fmt("󰔎", "Variant",   variant_line,                       c_pri, c_bri),
        fmt("󰖨", "Mode",      mode_line,                          c_pri, c_bri),
        fmt("󰸉", "Wallpaper", wall_display,                       c_pri, c_bri),
        fmt("", "Shell",     "caelestia-shell 2.3.0",            c_pri, c_bri),
        fmt("", "Quickshell", "v0.3.0",                          c_pri, c_bri),
    ]

    # Layout: align both sections so info boxes share the same right column
    term_w = shutil.get_terminal_size((120, 24)).columns
    gap = 2

    logo_w1 = max((visual_width(ln) for ln in UB), default=0)
    logo_w2 = max((visual_width(ln) for ln in CA), default=0)
    logo_col = max(logo_w1, logo_w2)

    # Section 1: Ubuntu logo + Hardware/Software
    info_w1 = max(36, min(46, term_w - logo_col - gap - 2))

    right1 = [border("Hardware", info_w1)] + hw + [bottom(info_w1)] + \
             [border("Software", info_w1)] + sw + [bottom(info_w1)]

    # Section 2: Caelestia logo + Uptime/Caelestia
    info_w2 = max(36, min(46, term_w - logo_col - gap - 2))

    right2 = [border("Uptime / Age / DT", info_w2)] + up + [bottom(info_w2)] + \
             [border("Caelestia", info_w2)] + ca + [bottom(info_w2)]

    def render_section(logo, right_block, logo_w, logo_col, gap):
        L = len(logo)
        I = len(right_block)
        top_pad = 0  # top-align info block with logo (matches PR screenshot)
        print()
        for i in range(max(L, I)):
            if i < I:
                line = right_block[i]
            else:
                line = ""
            logo_line = logo[i] if i < L else " " * logo_w
            pad = " " * (logo_col - visual_width(logo_line))
            print(f"{logo_line}{pad}{' ' * gap}{line}")

    render_section(UB, right1, logo_w1, logo_col, gap)
    render_section(CA, right2, logo_w2, logo_col, gap)
    print()


if __name__ == "__main__":
    main()
