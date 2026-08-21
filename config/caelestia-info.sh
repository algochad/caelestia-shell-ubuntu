#!/usr/bin/env bash
#
# Caelestia Shell Info Display
# Fastfetch-style terminal header with Ubuntu + Caelestia ASCII art.
# Source this from ~/.bashrc or your shell rc file.
#
# Usage: source /path/to/caelestia-info.sh
#

caelestia_info() {
    local scheme_raw scheme_name scheme_flavour mode_line variant_line wall_line

    # Strip ANSI color codes from caelestia output for reliable parsing
    scheme_raw=$(caelestia scheme get 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')
    scheme_name=$(echo "$scheme_raw" | awk '/^    Name:/{print $2}')
    scheme_flavour=$(echo "$scheme_raw" | awk '/^    Flavour:/{print $2}')
    mode_line=$(echo "$scheme_raw" | awk '/^    Mode:/{print $2}')
    variant_line=$(echo "$scheme_raw" | awk '/^    Variant:/{print $2}')
    wall_line=$(caelestia wallpaper 2>/dev/null | head -1)

    # Gather system info
    local os_name kernel uptime_info shell_name wm_name terminal_name cpu_info mem_info disk_info
    os_name=$(lsb_release -d 2>/dev/null | cut -f2 | sed 's/Ubuntu//' || echo "Unknown")
    kernel=$(uname -r)
    uptime_info=$(uptime -p 2>/dev/null | sed 's/up //' || uptime | sed 's/.*up \([^,]*\),.*/\1/')
    shell_name=$(basename "$SHELL")
    wm_name="Hyprland"
    terminal_name="kitty"
    cpu_info=$(grep 'model name' /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | sed 's/^ *//' | sed 's/  */ /g' | sed 's/(R)//g; s/(TM)//g; s/ CPU @//g; s/ GHz/ GHz/' | cut -c1-35)
    mem_info=$(free -h 2>/dev/null | awk '/^Mem:/{print $3 "/" $2}')
    disk_info=$(df -h / 2>/dev/null | tail -1 | awk '{print $3 "/" $2 " (" $5 ")"}')

    if [[ -n "$scheme_name" ]]; then
        local wall_display
        wall_display=$(basename "$wall_line" 2>/dev/null || echo "default")

        # ANSI RGB colors via printf (actual escape bytes, no \e parsing issues)
        local C1 C2 C3 OG CY RS
        C1=$(printf '\033[38;2;180;199;237m')   # primary
        C2=$(printf '\033[38;2;168;171;185m')   # secondary
        C3=$(printf '\033[38;2;228;225;230m')   # bright
        OG=$(printf '\033[38;2;233;84;32m')     # Ubuntu orange
        CY=$(printf '\033[38;2;100;200;255m')   # Caelestia cyan
        RS=$(printf '\033[0m')

        # ── Ubuntu logo (high-res circle of friends) ──
        local U01="${OG}           .-/+oooo+/-.           ${RS}"
        local U02="${OG}       .+oooooooooooooooo+.       ${RS}"
        local U03="${OG}     +ooooo${RS}  ${OG}oooo${RS}  ${OG}ooooo+     ${RS}"
        local U04="${OG}   +oooo${RS}    ${OG}oooo${RS}    ${OG}oooo+   ${RS}"
        local U05="${OG}  +ooo${RS}      ${OG}oooo${RS}      ${OG}ooo+  ${RS}"
        local U06="${OG} +ooo${RS}   ${OG}oooooooooooo${RS}   ${OG}ooo+ ${RS}"
        local U07="${OG} +ooo${RS}   ${OG}oooooooooooo${RS}   ${OG}ooo+ ${RS}"
        local U08="${OG} +ooo${RS}   ${OG}oooooooooooo${RS}   ${OG}ooo+ ${RS}"
        local U09="${OG}  +ooo${RS}      ${OG}oooo${RS}      ${OG}ooo+  ${RS}"
        local U10="${OG}   +oooo${RS}    ${OG}oooo${RS}    ${OG}oooo+   ${RS}"
        local U11="${OG}     +ooooo${RS}  ${OG}oooo${RS}  ${OG}ooooo+     ${RS}"
        local U12="${OG}       .+oooooooooooooooo+.       ${RS}"
        local U13="${OG}           .-/+oooo+/-.           ${RS}"

        # ── Caelestia celestial logo (high-res starburst) ──
        local C01="${CY}                .  .                ${RS}"
        local C02="${CY}           .          .           ${RS}"
        local C03="${CY}      .    \   |   /    .      ${RS}"
        local C04="${CY}        .   \  |  /   .        ${RS}"
        local C05="${CY}    .      -- ${RS}o${CY} --      .    ${RS}"
        local C06="${CY}        .   /  |  \   .        ${RS}"
        local C07="${CY}      .    /   |   \    .      ${RS}"
        local C08="${CY}           .          .           ${RS}"
        local C09="${CY}                .  .                ${RS}"

        echo ""
        # ── System info section with Ubuntu logo ──
        printf "%s  %b󰣇  %bOS%b         %b%s%b\n" "$U01" "$C1" "$RS" "$C2" "$RS" "$C3" "$os_name" "$RS"
        printf "%s  %b  %bKernel%b     %b%s%b\n" "$U02" "$C1" "$RS" "$C2" "$RS" "$C3" "$kernel" "$RS"
        printf "%s  %b󰔚  %bUptime%b     %b%s%b\n" "$U03" "$C1" "$RS" "$C2" "$RS" "$C3" "$uptime_info" "$RS"
        printf "%s  %b  %bShell%b      %b%s%b\n" "$U04" "$C1" "$RS" "$C2" "$RS" "$C3" "$shell_name" "$RS"
        printf "%s  %b  %bWM%b         %b%s%b\n" "$U05" "$C1" "$RS" "$C2" "$RS" "$C3" "$wm_name" "$RS"
        printf "%s  %b  %bTerminal%b   %b%s%b\n" "$U06" "$C1" "$RS" "$C2" "$RS" "$C3" "$terminal_name" "$RS"
        printf "%s  %b  %bCPU%b        %b%s%b\n" "$U07" "$C1" "$RS" "$C2" "$RS" "$C3" "$cpu_info" "$RS"
        printf "%s  %b󰍛  %bMemory%b     %b%s%b\n" "$U08" "$C1" "$RS" "$C2" "$RS" "$C3" "$mem_info" "$RS"
        printf "%s  %b  %bDisk%b       %b%s%b\n" "$U09" "$C1" "$RS" "$C2" "$RS" "$C3" "$disk_info" "$RS"
        printf "%s\n" "$U10"
        printf "%s\n" "$U11"
        printf "%s\n" "$U12"
        printf "%b────────────────────────────────────────────%b\n" "$C2" "$RS"

        echo ""
        # ── Caelestia section with its logo ──
        printf "%s  %b󰏘  %bScheme%b    %b%s %s%b\n" "$C01" "$C1" "$RS" "$C2" "$RS" "$C3" "$scheme_name" "${C2}(${scheme_flavour})${RS}" "$RS"
        printf "%s  %b󰔎  %bVariant%b   %b%s%b\n" "$C02" "$C1" "$RS" "$C2" "$RS" "$C3" "$variant_line" "$RS"
        printf "%s  %b󰖨  %bMode%b      %b%s%b\n" "$C03" "$C1" "$RS" "$C2" "$RS" "$C3" "$mode_line" "$RS"
        printf "%s  %b󰸉  %bWallpaper%b %b%s%b\n" "$C04" "$C1" "$RS" "$C2" "$RS" "$C3" "$wall_display" "$RS"
        printf "%s  %b  %bShell%b     %b%s%b\n" "$C05" "$C1" "$RS" "$C2" "$RS" "$C3" "caelestia-shell 2.3.0" "$RS"
        printf "%s  %b  %bQuickshell%b %b%s%b\n" "$C06" "$C1" "$RS" "$C2" "$RS" "$C3" "v0.3.0" "$RS"
        printf "%s  %b󰩶  %bDisplay%b   %b%s%b\n" "$C07" "$C1" "$RS" "$C2" "$RS" "$C3" "fastfetch-style" "$RS"
        printf "%s\n" "$C08"
        printf "%s\n" "$C09"
        printf "%b────────────────────────────────────────────%b\n" "$C2" "$RS"
        echo ""
    fi
}

if command -v caelestia &> /dev/null; then
    caelestia_info
fi
