#!/usr/bin/env python3
"""
Caelestia Shell Info Display
Fastfetch-style terminal header with Ubuntu ASCII + Caelestia half-block logo.
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


def ansi_fg(r, g, b):
    return f"\033[38;2;{r};{g};{b}m"


def ansi_bg(r, g, b):
    return f"\033[48;2;{r};{g};{b}m"


def render_halfblocks(png_path, target_h=13, target_w=28):
    """Render PNG as terminal half-blocks with 24-bit color."""
    try:
        from PIL import Image
    except ImportError:
        return None

    try:
        img = Image.open(png_path).convert("RGBA")
    except Exception:
        return None

    # Crop to content
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)

    # Scale: each char is 2 pixels tall, so height * 2
    calc_h = target_h * 2
    aspect = img.width / img.height
    calc_w = min(int(calc_h * aspect), target_w * 2)

    img = img.resize((calc_w, calc_h), Image.Resampling.LANCZOS)

    ALPHA = 40
    TERM_BG = (12, 14, 18)
    LOWER = "▄"  # foreground = bottom pixel color

    lines = []
    for row in range(0, calc_h - 1, 2):
        chars = []
        for col in range(calc_w):
            top = img.getpixel((col, row))
            bot = img.getpixel((col, row + 1))
            ta, ba = top[3], bot[3]

            # Both transparent → space
            if ta <= ALPHA and ba <= ALPHA:
                chars.append(" ")
                continue

            # Top transparent, bottom visible → use bottom color as fg
            if ta <= ALPHA:
                r, g, b = bot[:3]
                chars.append(f"{ansi_fg(r, g, b)}▄\033[0m")
                continue

            # Bottom transparent, top visible → use top color as bg
            if ba <= ALPHA:
                r, g, b = top[:3]
                chars.append(f"{ansi_bg(r, g, b)} \033[0m")
                continue

            # Both visible → half-block with fg=bottom, bg=top
            tr, tg, tb = top[:3]
            br, bg_, bb = bot[:3]
            chars.append(
                f"{ansi_fg(br, bg_, bb)}{ansi_bg(tr, tg, tb)}▄\033[0m"
            )

        lines.append("".join(chars))

    # Pad/center to target_w (measured in visible chars)
    result = []
    for line in lines:
        # Strip ANSI to measure visible length
        plain = re.sub(r'\x1b\[[0-9;]*m', '', line)
        vis_len = len(plain)
        if vis_len < target_w:
            pad = (target_w - vis_len) // 2
            result.append(" " * pad + line)
        else:
            result.append(line)
    return result


def get_logo():
    """Get Caelestia logo as terminal half-blocks."""
    svg_bright = "/home/algochad/.config/caelestia/logo_bright.svg"
    png_path = "/tmp/logo_bright_small.png"

    # Ensure bright SVG exists
    if not os.path.exists(svg_bright):
        return None

    # Generate PNG
    try:
        subprocess.run(
            ["convert", "-background", "none", "-resize", "200x200",
             svg_bright, png_path],
            check=True, capture_output=True, timeout=5
        )
    except Exception:
        return None

    # Render as half-blocks
    lines = render_halfblocks(png_path, target_h=13, target_w=28)
    return lines


def main():
    # ── Colors ──
    c_pri = "\033[38;2;180;199;237m"
    c_sec = "\033[38;2;168;171;185m"
    c_bri = "\033[38;2;228;225;230m"
    c_org = "\033[38;2;233;84;32m"      # Ubuntu
    c_cya = "\033[38;2;125;211;252m"   # Caelestia cyan
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

    # ── Host ──
    host_name = run("cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null") or "Unknown"

    # ── Display ──
    disp_raw = run("xrandr 2>/dev/null | grep '\\*' | head -1 | awk '{print $1}'")
    disp_info = disp_raw or run(
        "xdpyinfo 2>/dev/null | grep 'dimensions:' | head -1 | awk '{print $2}'"
    ) or "1920x1080"

    # ── Packages ──
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

    # ── CPU details ──
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

    # ── GPU info ──
    gpu_raw = run("lspci 2>/dev/null | grep -i 'vga\\|3d\\|display' | head -1")
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

    # ── Memory ──
    mem_info = run("free -h 2>/dev/null | awk '/^Mem:/{print $3 \"/\" $2}'")
    zram_raw = run("zramctl --noheadings 2>/dev/null | head -1 | awk '{print $4 \"/\" $3}'")
    zram_info = f"zram {zram_raw}" if zram_raw else ""
    swap_raw = run("free -h 2>/dev/null | awk '/^Swap:/{print $3 \"/\" $2}'")
    swap_info = f"swap {swap_raw}" if swap_raw and swap_raw != "0B/0B" else ""
    parts = [p for p in [mem_info, zram_info, swap_info] if p]
    mem_swap = " | ".join(parts)

    # ── Disk ──
    disk_info = run(
        "df -h / 2>/dev/null | tail -1 | "
        "awk '{print $3 \"/\" $2 \" (\" $5 \")\"}'")

    # ── OS full ──
    arch = run("uname -m") or "x86_64"
    codename = run("lsb_release -cs 2>/dev/null") or ""
    if codename:
        os_full = f"{os_name} ({codename}) [{arch}]"
    else:
        os_full = f"{os_name} [{arch}]"

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

    # ── Caelestia logo: half-block rendering ──
    cae_logo_lines = get_logo()
    if not cae_logo_lines:
        # ASCII fallback
        cae_logo_lines = [
            f"             {c_cya}+{rst}                 ",
            f"          {c_cya}.{rst}    {c_cya}.{rst}            ",
            f"        {c_cya},{rst}        {c_cya},{rst}          ",
            f"       {c_cya}/{rst}  {c_cya}╭──────╮{rst} {c_cya}\\{rst}       ",
            f"      {c_cya}│{rst}  {c_cya}│{rst} {c_bri}◯{rst}    {c_bri}◯{rst} {c_cya}│{rst} {c_cya}│{rst}      ",
            f"       {c_cya}\\{rst} {c_cya}│{rst}      {c_cya}│{rst} {c_cya}/{rst}        ",
            f"        {c_cya}\\{rst}{c_cya}╰──────╯{rst}{c_cya}/{rst}          ",
            f"      {c_cya}──────╯{rst}  {c_cya}╰──────{rst}      ",
            f"         {c_cya}\\{rst}      {c_cya}/{rst}            ",
            f"          {c_cya}\\{rst}    {c_cya}/{rst}             ",
            f"           {c_cya}\\{rst}  {c_cya}/{rst}              ",
            f"            {c_cya}\\{rst}{rst}                ",
            f"          {c_cya}+{rst}   {c_cya}+{rst}              ",
        ]
    cae_logo_width = 28

    def fmt(icon, key, val, ck=c_sec, cv=c_bri):
        return f" {icon}  {ck}{key}{rst}  {cv}{val}{rst}"

    def border(title, w=54):
        return f"{c_sec}{tl}{hz}{title}{hz * (w - len(title) - 2)}{tr}{rst}"

    def bottom(w=54):
        return f"{c_sec}{bl}{hz * (w - 2)}{br}{rst}"

    # ── Build sections ──
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
            c_cya, c_bri),
        fmt("󰔎", "Variant",   variant_line,                       c_cya, c_bri),
        fmt("󰖨", "Mode",      mode_line,                          c_cya, c_bri),
        fmt("󰸉", "Wallpaper", wall_display,                       c_cya, c_bri),
        fmt("", "Shell",     "caelestia-shell 2.3.0",            c_cya, c_bri),
        fmt("", "Quickshell", "v0.3.0",                          c_cya, c_bri),
    ]

    # ── Layout 1: Ubuntu + Hardware + Software ──
    right1 = [border("Hardware")] + hw + [bottom()] + \
             [border("Software")] + sw + [bottom()]
    total1 = max(len(UB), len(right1))

    # ── Layout 2: Caelestia logo + Uptime + Caelestia ──
    right2 = [border("Uptime / Age / DT")] + up + [bottom()] + \
             [border("Caelestia")] + ca + [bottom()]
    total2 = max(len(cae_logo_lines), len(right2))

    # ── Render block 1: Ubuntu ──
    print()
    for i in range(total1):
        logo = f"{c_org}{UB[i]}{rst}" if i < len(UB) else " " * 31
        info = right1[i] if i < len(right1) else ""
        print(f"{logo}  {info}")

    # ── Render block 2: Caelestia ──
    for i in range(total2):
        if i < len(cae_logo_lines):
            logo = cae_logo_lines[i]
        else:
            logo = " " * cae_logo_width
        info = right2[i] if i < len(right2) else ""
        print(f"{logo}  {info}")

    print()


if __name__ == "__main__":
    main()
