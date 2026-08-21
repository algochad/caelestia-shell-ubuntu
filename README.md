# Caelestia Shell Installer for Ubuntu 25.10/26.04 + Hyprland

One-shot installer for [Caelestia Shell](https://github.com/caelestia-dots/shell) on Ubuntu with Hyprland (tested on JaKooLit's Ubuntu-Hyprland).

## Prerequisites

- Ubuntu 25.10 or 26.04 (or newer)
- Hyprland already installed (e.g. via [JaKooLit/Ubuntu-Hyprland](https://github.com/JaKooLit/Ubuntu-Hyprland))
- `git`, `gh` CLI (optional, for pushing your own fork)

## Quick Install

### Local clone

```bash
git clone https://github.com/algochad/caelestia-shell-ubuntu.git
cd caelestia-shell-ubuntu
./install.sh
```

### One-shot curl | bash

```bash
curl -fsSL https://raw.githubusercontent.com/algochad/caelestia-shell-ubuntu/master/install.sh | bash
```

The script uses `sudo` internally for apt/system installs; it will prompt for your password on first use. Do not run it as root (`./install.sh` bails out if run as root).

The script will:
1. Download Qt 6.11.2 via `aqtinstall` (required — Ubuntu ships Qt 6.10 which lacks `DoubleSpinBox`)
2. Install APT dependencies (build tools, Qt dev libs, iniparser, fftw3, sensors, etc.)
3. Install fonts (CascadiaCode Nerd Font, Rubik, Material Symbols Rounded)
4. Build and install quickshell (with Qt 6.11 RUNPATH)
5. Build and install libcava (LukashonakV fork)
6. Build and install caelestia CLI
7. Build and install caelestia shell (with Qt 6.11 RUNPATH)
8. Disable Waybar/AGS systemd autostart and patch JaKooLit scripts
9. Add Qt 6.11 environment to `~/.bashrc`
10. Configure Hyprland to auto-start `caelestia shell -d`
11. Install [mise](https://mise.jdx.dev) (dev tool / env manager)
12. Install [Oh My Bash](https://ohmybash.nntoan.com) (if not already present)
13. Install [Bun](https://bun.sh)
14. Install [Oh My Pi (omp)](https://omp.sh)
15. Install [Docker Engine](https://docker.com) and add your user to the `docker` group
16. Install [lazydocker](https://github.com/jesseduffield/lazydocker)
17. Install [Visual Studio Code](https://code.visualstudio.com)

After install, **logout/login** (or `hyprctl dispatch exit`) for Hyprland to pick up the startup changes.

## Why This Fork Exists

The upstream caelestia installer assumes Arch Linux (`paru`, `yay`, AUR packages). This repo ports it to Ubuntu/Debian with all the fixes we discovered.

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for the full list of issues encountered and their fixes.

## Credits

- Original shell: [caelestia-dots/shell](https://github.com/caelestia-dots/shell)
- Upstream installer: [IshmamDC217/caelestia-shell-ubuntu](https://github.com/IshmamDC217/caelestia-shell-ubuntu)
- Hyprland dots: [JaKooLit/Ubuntu-Hyprland](https://github.com/JaKooLit/Ubuntu-Hyprland)
