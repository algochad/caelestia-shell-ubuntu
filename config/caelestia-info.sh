#!/usr/bin/env bash
#
# Caelestia Shell Info Display
# Fastfetch-style terminal header with Ubuntu ASCII art + system info.
# Source this from ~/.bashrc or your shell rc file.
#
# Usage: source /path/to/caelestia-info.sh
#

if command -v caelestia &> /dev/null; then
    caelestia_info() {
        local scheme_raw scheme_name scheme_flavour mode_line variant_line wall_line
        local reset="\e[0m"
        local bold="\e[1m"
        local dim="\e[38;2;138;141;153m"

        # Strip ANSI color codes from caelestia output for reliable parsing
        scheme_raw=$(caelestia scheme get 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')
        scheme_name=$(echo "$scheme_raw" | awk '/^    Name:/{print $2}')
        scheme_flavour=$(echo "$scheme_raw" | awk '/^    Flavour:/{print $2}')
        mode_line=$(echo "$scheme_raw" | awk '/^    Mode:/{print $2}')
        variant_line=$(echo "$scheme_raw" | awk '/^    Variant:/{print $2}')
        wall_line=$(caelestia wallpaper 2>/dev/null | head -1)

        # Gather system info
        local os_name kernel uptime_info shell_name wm_name terminal_name cpu_info mem_info disk_info
        os_name=$(lsb_release -d 2>/dev/null | cut -f2 | sed 's/Ubuntu/󰣇/' || cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '"' | sed 's/Ubuntu/󰣇/')
        kernel=$(uname -r)
        uptime_info=$(uptime -p 2>/dev/null | sed 's/up //' || uptime | sed 's/.*up \([^,]*\),.*/\1/')
        shell_name=$(basename "$SHELL")
        wm_name="Hyprland"
        terminal_name="kitty"
        cpu_info=$(grep 'model name' /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | sed 's/^ *//' | sed 's/  */ /g' | sed 's/(R)//g; s/(TM)//g; s/ CPU @//g; s/ GHz/ GHz/' | cut -c1-35)
        mem_info=$(free -h 2>/dev/null | awk '/^Mem:/{print $3 "/" $2}')
        disk_info=$(df -h / 2>/dev/null | tail -1 | awk '{print $3 "/" $2 " (" $5 ")"}')

        # Color from current scheme primary (b4c7ed → rgb(180,199,237))
        local c1="\e[38;2;180;199;237m"   # primary
        local c2="\e[38;2;168;171;185m"   # secondary/muted
        local c3="\e[38;2;228;225;230m"   # onSurface (bright)

        if [[ -n "$scheme_name" ]]; then
            local wall_display
            wall_display=$(basename "$wall_line" 2>/dev/null || echo "default")

            # Ubuntu ASCII art (colored)
            local logo_color="\e[38;2;233;84;32m"  # Ubuntu orange

            echo ""
            # Two-column layout: logo left, info right
            printf "%-14s ${c1}󰣇${reset}  ${c2}OS${reset}         ${c3}%s${reset}\n" "${logo_color}         _  ${reset}" "${os_name}"
            printf "%-14s ${c1}${reset}  ${c2}Kernel${reset}     ${c3}%s${reset}\n" "${logo_color}     ---(_) ${reset}" "${kernel}"
            printf "%-14s ${c1}󰔚${reset}  ${c2}Uptime${reset}     ${c3}%s${reset}\n" "${logo_color} _/  ---  \ ${reset}" "${uptime_info}"
            printf "%-14s ${c1}${reset}  ${c2}Shell${reset}      ${c3}%s${reset}\n" "${logo_color}(_) |   |   ${reset}" "${shell_name}"
            printf "%-14s ${c1}${reset}  ${c2}WM${reset}         ${c3}%s${reset}\n" "${logo_color}  \  --- _/ ${reset}" "${wm_name}"
            printf "%-14s ${c1}${reset}  ${c2}Terminal${reset}   ${c3}%s${reset}\n" "${logo_color}     ---(_) ${reset}" "${terminal_name}"
            printf "%-14s ${c1}${reset}  ${c2}CPU${reset}        ${c3}%s${reset}\n" "${logo_color}       |    ${reset}" "${cpu_info}"
            printf "%-14s ${c1}󰍛${reset}  ${c2}Memory${reset}     ${c3}%s${reset}\n" "${logo_color}            ${reset}" "${mem_info}"
            printf "%-14s ${c1}${reset}  ${c2}Disk${reset}       ${c3}%s${reset}\n" "" "${disk_info}"

            echo ""
            # ── Caelestia section ──
            echo -e "${c2}───────────────────────────────────────────${reset}"
            printf "     ${c1}󰏘${reset}  ${c2}Scheme${reset}    ${c3}%s${reset} ${c2}(%s)${reset}\n" "${scheme_name}" "${scheme_flavour}"
            printf "     ${c1}󰔎${reset}  ${c2}Variant${reset}   ${c3}%s${reset}\n" "${variant_line}"
            printf "     ${c1}󰖨${reset}  ${c2}Mode${reset}      ${c3}%s${reset}\n" "${mode_line}"
            printf "     ${c1}󰸉${reset}  ${c2}Wallpaper${reset} ${c3}%s${reset}\n" "${wall_display}"
            printf "     ${c1}${reset}  ${c2}Shell${reset}     ${c3}%s${reset}\n" "caelestia-shell 2.3.0"
            printf "     ${c1}${reset}  ${c2}Quickshell${reset} ${c3}%s${reset}\n" "v0.3.0"
            echo -e "${c2}───────────────────────────────────────────${reset}"
            echo ""
        fi
    }
    caelestia_info
fi
