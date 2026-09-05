# Caelestia Shell for Ubuntu 25.10 / 26.04 + Hyprland

One-shot, idempotent installer for [caelestia-dots/shell](https://github.com/caelestia-dots/shell) on Ubuntu with Hyprland (tested on [JaKooLit/Ubuntu-Hyprland](https://github.com/JaKooLit/Ubuntu-Hyprland)). Ports the Arch installer to Ubuntu, builds Qt 6.11 locally, patches the shell, and wires everything into Hyprland + your terminal.

## Prerequisites

- Ubuntu 25.10 or 26.04 (or newer). 26.04 LTS is `$XDG_RUNTIME_DIR=/run/user/1000`, Hyprland 0.53.x.
- Hyprland already installed (e.g. via JaKooLit/Ubuntu-Hyprland). The installer bails out if run as root.
- `git` on `PATH`. `gh` CLI is optional.

## Quick install

### Local clone (recommended)

```bash
git clone https://github.com/algochad/caelestia-shell-ubuntu.git
cd caelestia-shell-ubuntu
./install.sh
```

### One-shot `curl | bash`

```bash
curl -fsSL https://raw.githubusercontent.com/algochad/caelestia-shell-ubuntu/master/install.sh | bash
```

The script clones itself to a temp dir when piped, then re-execs locally so `config/` and `patches/` are available. It uses `sudo` internally (apt, `cmake --install`, font cache, docker group) and will prompt for your password once. **Do not `sudo ./install.sh`.**

After install: **logout/login** (or `hyprctl dispatch exit`, or reboot) so Hyprland picks up `ENVariables.conf` / `Startup_Apps.conf` / keybinds. In the current shell, `exec bash` or `source ~/.bashrc` is enough for the terminal side.

## What the installer does (Steps 0–15)

| Step | What | Notes |
|------|------|-------|
| 0 | Qt 6.11.2 via `aqtinstall` into `~/qt6.11` | Ubuntu ships Qt 6.10 which lacks `DoubleSpinBox`/`M3Shapes` wiring. Modules `qtshadertools` (M3Shapes), `qtimageformats` (WebP), `qtmultimedia` (video walls). Idempotent. |
| 1 | APT deps + `mesa-git` PPA workaround | `build-essential cmake ninja git pkg-config meson`, Qt6 dev, `wayland-protocols libjemalloc libpipewire libdrm`, `python3-build hatchling libnotify grim slurp wl-clipboard brightnessctl ddcutil lm-sensors`, `wlsunset` (night-light fallback), plus local extraction of `-dev` debs that the PPA shadows. |
| 2 | Fonts | CascadiaCode Nerd Font, Rubik Variable, Material Symbols Rounded → `~/.local/share/fonts` + `fc-cache -f`. |
| 3 | Build `quickshell` (`qs`) | `cmake -GNinja -DCMAKE_INSTALL_RPATH="$QT_PREFIX/lib:…"`, binary to `~/.local/bin/qs` (`~/.local/bin` precedes `/usr/local/bin`). Retry with `-j1` on Ninja OOM. Uses hard `cp` (not symlink) so `caelestia shell -d` sees it via `PATH`. |
| 4 | Build `libcava` | LukashonakV fork, `meson install` + `/etc/ld.so.conf.d/libcava.conf` → `ldconfig`. |
| 5 | Build `caelestia` CLI | `python3 -m build --wheel` + `pip install --force-reinstall`, `dart-sass` to `~/.local/opt`, `caelestia keybinds` cheatsheet subcommand via `config/caelestia-cli-patches/` + `config/patch-caelestia-cli.py`, cleans stale `dist/` wheels after keybinds patch. |
| 6 | Build `caelestia` shell | Clones to `~/.config/quickshell/caelestia`, applies `patches/*.diff` (`git apply --check` idempotent), `cmake -DCMAKE_INSTALL_RPATH=…:$ORIGIN:$ORIGIN/lib`. |
| 7 | Fix `qs` binary path | Ensures `~/.local/bin/qs` wins; reports `qs --version`. |
| 8 | Configuration | See below. |
| 9 | `mise` | `https://mise.run` → `~/.local/bin/mise`, activates in `~/.bashrc`. |
| 10 | Oh My Bash | Unattended install if `~/.oh-my-bash` absent. |
| 11 | Bun | `https://bun.sh/install` → `~/.bun/bin/bun`. |
| 12 | `omp` | `https://omp.sh/install`. |
| 13 | Docker Engine | Adds `download.docker.com` apt source, installs `docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin`, `systemctl enable --now docker`, `usermod -aG docker $USER`. |
| 14 | `lazydocker` | `jesseduffield/lazydocker` script → `~/.local/bin`. |
| 15 | VS Code | Microsoft apt source → `apt install code`. Then auto-starts `caelestia shell -d` if not already running (with injected Hyprland env — see Night Light). |

Re-running the installer is safe — every step checks for existing installs/patches before doing work.

## Step 8 in detail — configuration

`install.sh` Step 8 is the distro-integration layer:

- **ENVariables** — writes `QT 6.11` `QML_IMPORT_PATH`/`LD_LIBRARY_PATH` into `~/.config/hypr/UserConfigs/ENVariables.conf` (including the arch-specific `/usr/lib/x86_64-linux-gnu/qt6/qml` for `M3Shapes`). Without this, Hyprland launches `caelestia shell -d` with no Qt 6.11 on the import path → `M3Shapes is not installed` / `ImageAnalyser is not a type` → black screen with only a mouse.
- **Shell config** — copies `config/shell.json` → `~/.config/caelestia/shell.json` (dynamic scheme, wallpaper dir, keybinds, etc.), enables `smartScheme`.
- **Kitty** — installs `config/caelestia/kitty-colors.py` as a `caelestia` `theme`+`wallpaper` `postHook` (writes `~/.config/kitty/caelestia.conf` + `~/.cache/caelestia/palette.json` on every scheme change) and swaps `~/.config/kitty/kitty.conf` from JaKooLit `wallust` include to `caelestia.conf`.
- **Terminal header** — installs `config/caelestia-fetch.py` + `config/caelestia_ascii.txt` → `~/.config/caelestia/`, replaces the upstream hardcoded 256-color fastfetch palette with the live `palette.json`; `~/.bashrc` hook runs `caelestia-fetch.py` (falls back to `~/.config/fastfetch/caelestia.jsonc`).
- **Wallpapers** — `~/Pictures/wallpapers` (lowercase, matches `CAELESTIA_WALLPAPERS_DIR`), `~/.face` avatar.
- **Hyprland autostart** — comments out Waybar/AGS/`qs -c overview` in `~/.config/hypr/configs/Startup_Apps.conf`, adds `exec-once = caelestia shell -d` to `~/.config/hypr/UserConfigs/Startup_Apps.conf`, injects startup env wrapper so the shell inherits `HYPRLAND_INSTANCE_SIGNATURE` (see Night Light). Disables/masks `waybar.service`/`ags.service`.
- **Theme scripts** — patches `~/.config/hypr/scripts/Refresh.sh` (`restart_waybar` → `restart_caelestia`), `DarkLight.sh`, `ToggleWaybarTime.sh`, `WaybarStartup.sh`, `WaybarLayout.sh`, `HyprLayoutModule.sh` to restart `qs`/`caelestia` instead of Waybar.
- **Keybinds** — appends to `~/.config/hypr/UserConfigs/UserKeybinds.conf`: `Super+Space` launcher (`drawers toggle launcher`), `Super+N` nexus, `Super+Shift+E` session, `Super+L` lock, `Super+/` keybinds cheatsheet; `Super+W` random wallpaper, `Super+Shift+W` dark/light toggle (`~/.config/hypr/scripts/toggle-scheme.sh`).

## Features

### Wallpaper

Patches in `patches/wallpaper-features.diff` (1552 lines) and `patches/wallpaper-wheel-scroll.diff`:

- **Video wallpapers** — `mp4`/`webm`/`mov`/`avi`/`mkv` + `gif` via `QtMultimedia` `Video`/`AnimatedImage` wrappers in `modules/background/Wallpaper.qml`, with shared `ready` + `Anim on opacity` logic.
- **Thumbnail pipeline** — `scripts/thumbgen.py` → `~/.cache/caelestia/wallpaper-thumbs/` (replaces the old C++ image cacher), used by the launcher `WallpaperItem`.
- **Launcher integration** — `FileSystemEntry` → `QtObject` model, `wallpaperEnabled` guards, category filters.

### Terminal — follows the shell theme live

- **Kitty** (`config/caelestia/kitty-colors.py`): `foreground`/`background`/`cursor`/`selection_background`/`color0-15` from `SCHEME_COLOURS` (`term0-15`, `onSurface`, `surface`, `secondary`). Also dumps `~/.cache/caelestia/palette.json` for other consumers.
- **Fetch header** (`config/caelestia-fetch.py`): reads `palette.json` (fast path) → `caelestia scheme get` fallback → hardcoded `125;211;252` last resort. Rounds `C_TITLE`/`C_LOGO` (`primary`), `C_ICON` (`secondary`), `C_KEY` (`onSurfaceVariant`), `C_VAL` (`onSurface`).
- Enable: `install.sh` registers both as `cli.json` `postHook`s and generates the first theme immediately.

### Night Light — Warm display filter

Adds a **Night Light** section to the Nexus → **Wallpaper & style** page (`patches/z-nightlight.diff`):

- **Service** `services/NightLight.qml` — singleton with `enabled`/`temperature` (`1000–6500 K`), `available`, `backend` (`hyprsunset` preferred, `wlsunset` fallback). Persists to `~/.local/state/caelestia/nightlight.json` via `FileView` + debounced save. IPC at `caelestia shell nightlight {status,enable,disable,toggle,setTemp}`.
- **Hyprsunset backend (preferred)** — `~/.local/bin/hyprsunset` built locally (needs `libhyprutils-dev`/`libhyprlang-dev`/`hyprland-protocols` extracted to `~/.local`). A **lazy daemon** (`nightlight-hyprsunset` wrapper injects `HYPRLAND_INSTANCE_SIGNATURE`/`WAYLAND_DISPLAY`/`XDG_RUNTIME_DIR`/`LD_LIBRARY_PATH`, cleans stale `.hyprsunset.sock`) — only runs while `enabled`. Slider uses `execDetached` (`hyprctl hyprsunset temperature/identity` via `~/.local/bin/nightlight-hyprctl`) for both on/off/temp — **realtime**, no debounce, no Process queue. Stale `wlsunset` is killed when switching to `hyprsunset`.
- **Wlsunset fallback** — `wlsunset` daemon with `T=t+1 / t` 1-minute window for always-on warm. Used when `hyprsunset` is absent; apt-installed by `install.sh` Step 1.
- **Boot safety** — disabled on disk when fixing black-screen regressions; stale `hyprsunset`/`wlsunset`/`qs`/`quickshell` pids and `.hyprsunset.sock` are killed/removed before restart; `Startup_Apps.conf` wrapper re-exports Hyprland env so `qs` sees `HYPRLAND_INSTANCE_SIGNATURE` even outside `ENVariables`.

**Using it:**

```bash
# Toggle
caelestia shell nightlight enable
caelestia shell nightlight disable
caelestia shell nightlight toggle

# Temperature (1000–6500)
caelestia shell nightlight setTemp 2800
caelestia shell nightlight status   # → {"enabled":true,"temperature":2800,...}
```

In the shell: **Super+N → Wallpaper & style → Night light** toggle + **Colour temperature** slider. The toggle is disabled until a backend is detected (shows `hyprsunset`/`wlsunset` or `Install hyprsunset or wlsunset package`). The slider is disabled while night light is off.

**Why hyprsunset?** `hyprctl hyprsunset temperature/identity` is a CTM update via `hyprland-ctm-control-v1` — fire-and-forget and realtime. `gammastep`/`wlsunset` restart is ~600 ms and can wedge on a stale socket.

### Keybinds cheatsheet

`config/caelestia-keybinds.py` + `config/caelestia-cli-patches/keybinds.py` add a `caelestia keybinds` subcommand (also installed as `/usr/local/bin/caelestia-keybinds`). Parses `hyprland.conf` variable expansion, Hyprland `Keybinds.conf`, and caelestia's own keybind registrants. Bound as `Super+/`.

```bash
caelestia keybinds              # all
caelestia keybinds caelestia    # only caelestia
caelestia keybinds hypr         # only Hyprland
caelestia keybinds custom       # installer customs
```

### Previous experiments

- **Starship prompt** — a `starship.toml` prompt with live M3 palette was prototyped and then reverted (two commits, both reverted). It worked but wasn't kept — the kitty/fetch path covers the terminal surface well enough. History remains in `git log` for reference.

## Patches

Applied on top of the upstream shell (`~/.config/quickshell/caelestia` git clone) via `git apply --check` + `git apply`:

| Patch | What |
|-------|------|
| `patches/wallpaper-features.diff` | Video/gif support, thumbgen pipeline, wallpaper browsing, recent list |
| `patches/wallpaper-wheel-scroll.diff` | Mouse wheel on wallpaper row |
| `patches/z-nightlight.diff` | Night-light service + settings page (applied last so it can depend on the wallpaper page) |

Patches are idempotent — `install.sh` skips any that already apply cleanly.

## Keybinds

Installed into `~/.config/hypr/UserConfigs/UserKeybinds.conf`:

| Bind | Action |
|------|--------|
| `Super+Space` | Toggle launcher (`caelestia shell drawers toggle launcher`) |
| `Super+N` | Nexus / settings |
| `Super+Shift+E` | Session menu |
| `Super+L` | Lock screen |
| `Super+/` | Keybinds cheatsheet (`caelestia keybinds`) |
| `Super+W` | Random wallpaper (`caelestia wallpaper -r`) |
| `Super+Shift+W` | Dark/light scheme toggle |

JaKooLit's `togglefloating` on `Super+Space` is unbound to free the launcher chord. Existing `drawers.toggle` entries are migrated to `drawers toggle` (Hyprland IPC is space-separated).

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for 20+ boot/build/runtime issues and their fixes, including the `ENVariables` `M3Shapes`/`ImageAnalyser` boot loop, stale `hyprsunset` socket, night-light `available: false`, and Ninja OOM fallback.

## Why this fork

Upstream assumes Arch (`paru`/`yay`/AUR). This repo makes the same shell work on Ubuntu 26.04’s Qt 6.10 base by building Qt 6.11 locally and fixing every place the Arch assumptions leak — plus the feature patches above — so re-running `./install.sh` on any Hyprland-Ubuntu box converges.

## Credits

- Shell: [caelestia-dots/shell](https://github.com/caelestia-dots/shell)
- Upstream Ubuntu installer skeleton: [IshmamDC217/caelestia-shell-ubuntu](https://github.com/IshmamDC217/caelestia-shell-ubuntu)
- Hyprland dots base: [JaKooLit/Ubuntu-Hyprland](https://github.com/JaKooLit/Ubuntu-Hyprland)
