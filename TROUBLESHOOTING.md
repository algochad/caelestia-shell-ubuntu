# Troubleshooting Guide

Complete record of every issue encountered when installing Caelestia Shell on Ubuntu 26.04 with JaKooLit's Hyprland-Dots.

## Issue 1: Missing APT Dependencies

**Error:**
```
iniparser library is required
fftw3 library is required
Could not find SENSORS_LIBRARY using the following names: sensors
```

**Fix:**
```bash
sudo apt install -y libiniparser-dev libfftw3-dev libsensors-dev
```

Now handled automatically by `install.sh`.

---

## Issue 2: cpptrace C++20 Modules Error

**Error:**
```
The target named "cpptrace__cpptrace@synth_ca524af7951b" has C++ sources
that use modules, but does not include "cxx_std_20" (or newer) among its
`target_compile_features`; found "cxx_std_17".
```

**Fix:** Add `-DCRASH_HANDLER=OFF` to the quickshell CMake build. The crash handler depends on cpptrace which requires C++20, but the system cpptrace only advertises C++17.

```bash
cmake -GNinja -B build \
    -DCRASH_HANDLER=OFF \
    ...
```

Now handled automatically by `install.sh`.

---

## Issue 3: Qt 6.10 vs Qt 6.11 — DoubleSpinBox Missing

**Error:**
```
DoubleSpinBox is not a type
```

**Root Cause:** Ubuntu 26.04 ships Qt 6.10.2. `DoubleSpinBox` was added in Qt 6.11. The caelestia shell uses `DoubleSpinBox` in `StyledSpinBox.qml`.

**Fix:** Download Qt 6.11.2 via `aqtinstall`:

```bash
python3 -m venv /tmp/aqt-env
/tmp/aqt-env/bin/pip install aqtinstall
/tmp/aqt-env/bin/aqt install-qt linux desktop 6.11.2 linux_gcc_64 \
    -O ~/qt6.11
```

Then install required modules:
```bash
/tmp/aqt-env/bin/aqt install-qt linux desktop 6.11.2 linux_gcc_64 \
    -O ~/qt6.11 -m qtshadertools
/tmp/aqt-env/bin/aqt install-qt linux desktop 6.11.2 linux_gcc_64 \
    -O ~/qt6.11 -m qtimageformats
```

Modules needed:
- `qtshadertools` — M3Shapes (Material Design 3 shapes)
- `qtimageformats` — WebP support for wallpapers

Now handled automatically by `install.sh` Step 0.

---

## Issue 4: Symbol Lookup Error at Runtime

**Error:**
```
qs: symbol lookup error: qs: undefined symbol: _ZN23QUntypedPropertyBindingC1EP23QPropertyBindingPrivate, version Qt_6_PRIVATE_API
```

**Root Cause:** The rebuilt quickshell links against Qt 6.11 at compile time, but at runtime the dynamic linker finds Qt 6.10 system libraries first.

**Fix:** Rebuild with Qt 6.11 in the `RUNPATH`:

```bash
QT_DIR="$HOME/qt6.11/6.11.2/gcc_64"
cmake -GNinja -B build \
    -DCMAKE_PREFIX_PATH="$QT_DIR" \
    -DCMAKE_INSTALL_RPATH="$QT_DIR/lib;/usr/lib/x86_64-linux-gnu" \
    ...
```

Then ensure environment variables are set:
```bash
export PATH="$HOME/qt6.11/6.11.2/gcc_64/bin:$PATH"
export LD_LIBRARY_PATH="$HOME/qt6.11/6.11.2/gcc_64/lib:$LD_LIBRARY_PATH"
export QML_IMPORT_PATH="$HOME/qt6.11/6.11.2/gcc_64/qml:/usr/lib/qt6/qml"
```

Now handled automatically by `install.sh` (sets `CMAKE_INSTALL_RPATH` and adds to `~/.bashrc`).

---

## Issue 5: Stale `/usr/local/bin/quickshell` Binary

**Error:** After building and installing, the old `/usr/local/bin/quickshell` (from original install or caelestia-cli) still runs instead of the rebuilt Qt 6.11 version.

**Fix:** Replace the stale binary:

```bash
sudo cp /usr/bin/quickshell /usr/local/bin/quickshell
sudo chmod 755 /usr/local/bin/quickshell
```

Now handled automatically by `install.sh` Step 7.

---

## Issue 6: WebP Wallpaper Not Decoding

**Error:**
```
Failed to decode source: wallpaper.webp
```

**Root Cause:** The downloaded Qt 6.11 base doesn't include the `qtimageformats` module, which provides the WebP image format plugin.

**Fix:** Install the `qtimageformats` module:

```bash
aqt install-qt linux desktop 6.11.2 linux_gcc_64 \
    -O ~/qt6.11 -m qtimageformats
```

Now handled automatically by `install.sh` Step 0.

---

## Issue 7: Missing Fonts

**Symptom:** UI looks ugly — icons missing, wrong font family, text looks off.

**Root Cause:** Three fonts are required but not installed by default:
1. **CascadiaCode Nerd Font** — for terminal and UI icons
2. **Rubik** — for the shell's sans-serif text
3. **Material Symbols Rounded** — for Material Design icons

**Fix:**
```bash
# CascadiaCode Nerd Font
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/CascadiaCode.zip
# Rubik Variable Font
wget "https://github.com/google/fonts/raw/main/ofl/rubik/Rubik%5Bwght%5D.ttf"
# Material Symbols Rounded Variable Font
wget "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL,GRAD,opsz,wght%5D.ttf"
```

Now handled automatically by `install.sh` Step 2.

---

## Issue 8: Waybar Keeps Coming Back

**Symptom:** After killing Waybar, it restarts on:
- Hyprland reload
- Wallpaper change
- Theme change (dark/light toggle)
- Systemd graphical-session target activation

**Root Causes:**
1. **Systemd autostart** — JaKooLit enables Waybar via `graphical-session.target.wants/waybar.service`
2. **Theme scripts restart Waybar** — `Refresh.sh`, `DarkLight.sh`, `ThemeChanger.sh`, `ToggleWaybarTime.sh`, `WallustSwww.sh`, `RefreshNoWaybar.sh` all call `restart_waybar()` or `pkill waybar`

**Fix 1 — Disable systemd autostart:**
```bash
sudo rm -f /etc/systemd/user/graphical-session.target.wants/waybar.service
systemctl --user mask waybar.service
systemctl --user stop waybar.service
```

**Fix 2 — Patch theme scripts:**

| Script | Change |
|--------|--------|
| `Refresh.sh` | `restart_waybar()` → `restart_caelestia()` |
| `DarkLight.sh` | `killall waybar` → `killall qs quickshell` |
| `ToggleWaybarTime.sh` | `restart_waybar()` → no-op |
| `WaybarStartup.sh` | `waybar` → `caelestia shell -d` |
| `WaybarLayout.sh` | `pkill waybar` → `pkill qs quickshell` |
| `HyprLayoutModule.sh` | `pkill -RTMIN+8 waybar` → disabled |
| `ThemeChanger.sh` | `waybar-msg cmd reload` → removed |
| `WallustSwww.sh` | `ensure_wallust_waybar_style()` → no-op |
| `RefreshNoWaybar.sh` | `ags -q && ags &` → `caelestia shell -d` |

Now handled automatically by `install.sh` Step 8.

---

## Issue 9: Caelestia Shell Not Auto-Starting with Hyprland

**Fix:** The installer adds `exec-once = caelestia shell -d` to `~/.config/hypr/UserConfigs/Startup_Apps.conf` and comments out Waybar/AGS entries in `~/.config/hypr/configs/Startup_Apps.conf`.

After install, **logout/login** is required for Hyprland to read the new startup config.

---

## Issue 10: Old Repo Ownership

**Fix:** The original repo was cloned from upstream. We removed `.git` and re-initialized with our own commits so this fork tracks our fixes independently.

```bash
rm -rf .git
git init
git add -A
git commit -m "Initial commit"
```

---

## Issue 11: Caelestia Not Auto-Starting After Logout/Reboot

**Symptom:** `exec-once = caelestia shell -d` is in `UserConfigs/Startup_Apps.conf`, but after logout/login or reboot, the shell doesn't start. Must run manually.

**Root Cause:** Hyprland doesn't inherit `QML_IMPORT_PATH` and `LD_LIBRARY_PATH` from `~/.bashrc`. When `caelestia shell -d` runs at Hyprland startup, it can't find the Qt 6.11 libraries or Caelestia QML modules, so it silently fails.

**Fix:** Add Qt 6.11 environment variables to Hyprland config:

```bash
# In ~/.config/hypr/UserConfigs/ENVariables.conf, add:
env = QML_IMPORT_PATH,/home/$USER/qt6.11/6.11.2/gcc_64/qml:/usr/lib/qt6/qml
env = LD_LIBRARY_PATH,/home/$USER/qt6.11/6.11.2/gcc_64/lib:${LD_LIBRARY_PATH}
```

Now handled automatically by `install.sh`.

---

## Environment Variables

After install, these are added to `~/.bashrc`:

```bash
export PATH="/home/$USER/qt6.11/6.11.2/gcc_64/bin:${PATH}"
export LD_LIBRARY_PATH="/home/$USER/qt6.11/6.11.2/gcc_64/lib:${LD_LIBRARY_PATH}"
export QML_IMPORT_PATH="/home/$USER/qt6.11/6.11.2/gcc_64/qml:/usr/lib/qt6/qml"
```

And to `~/.config/hypr/hyprland.conf`:
```
env = QML_IMPORT_PATH,/home/$USER/qt6.11/6.11.2/gcc_64/qml:/usr/lib/qt6/qml
```

---

## Issue 12: Super+Space Launcher Stops Working

**Symptom:** The caelestia launcher keybind (`Super+Space`) stops opening the launcher, even though the bind appears in Hyprland.

**Root Cause:** The caelestia IPC message format is space-separated, not dot-separated. A previous installer patch incorrectly changed:
```
caelestia shell drawers toggle launcher
```
to:
```
caelestia shell drawers.toggle launcher
```
The dotted form is **not** a valid IPC target/function separator, so Hyprland dispatches the exec but caelestia rejects the message.

**Fix:** Use the space-separated IPC form in `~/.config/hypr/UserConfigs/UserKeybinds.conf`:
```
bindd = SUPER, SPACE, Open caelestia launcher, exec, caelestia shell drawers toggle launcher
```

`install.sh` now adds the correct form and migrates any existing `drawers.toggle` entries back to `drawers toggle`.

---

## Issue 13: Terminal fetch/kitty not following the theme

**Symptom:** After changing wallpaper/scheme, kitty colors and the terminal header stay on the old palette until you restart.

**Root Cause:** JaKooLit's kitty template bakes a stale `wallust` palette into `~/.config/kitty/kitty.conf`; our hook was `theme` only so wallpaper-only changes didn't fire.

**Fix:** Register the same `postHook` (`config/caelestia/kitty-colors.py`) for both `theme` and `wallpaper` in `cli.json`, and swap `kitty.conf`'s `include ./kitty-themes/01-Wallust.conf` → `include caelestia.conf` (idempotent `sed`). The hook writes `~/.config/kitty/caelestia.conf` (`foreground`/`background`/`cursor`/`color0-15` from `term0-15`) and dumps `~/.cache/caelestia/palette.json`; `config/caelestia-fetch.py` reads that JSON with a `caelestia scheme get` fallback.

---

## Issue 14: Starship prompt experiment (reverted)

**What we tried:** Installed `starship` to `~/.local/bin`, added a `config/caelestia/starship.template.toml` rendered by the same `postHook` into `~/.config/starship.toml`, wired `starship init bash` + a `right_prompt` cursor-jump hack into `~/.bashrc`, and neutralized OMB's `PROMPT_COMMAND` rebuild.

**Why reverted:** Worked, but added latency/complexity for little gain — the fetch header + kitty theme already carry the palette. Two commits add it, two more revert it; history is still in `git log` if you want to resurrect it.

---

## Issue 15: Waybar/dotfile build tools missing after clone

**Error:** `caelestia wallpaper -p` or the shell build fails with `sass: command not found` or `build: No module named 'build'`.

**Fix:** `install.sh` ensures `python3-build`/`hatchling` (apt, or `pip --break-system-packages` fallback) and installs `dart-sass` to `~/.local/opt/dart-sass` → `~/.local/bin/sass` (needed because `apply_discord()` shells out to `sass` on every scheme change).

---

## Issue 16: Night light toggle stays disabled — `available: false`

**Symptom:** Nexus shows `Install wlsunset package` grayed out even though `~/.local/bin/hyprsunset` / `wlsunset` exists. `caelestia shell nightlight status` → `{"available":false}`.

**Root Cause:** Hyprland launches `caelestia shell -d` with a minimal `PATH` (`/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:...`) that has no `~/.local/bin`. `NightLight.qml`'s `availProc` (`command -v hyprsunset`) therefore sees no backend and latches `available = false` forever.

**Fix:** Probe with absolute paths first:

```js
if [ -x /home/algochad/.local/bin/hyprsunset ]; then echo hyprsunset
elif [ -x /home/algochad/.local/bin/wlsunset ]; then echo wlsunset
else command -v hyprsunset ...
```

and wrap every `hyprsunset`/`wlsunset` invocation with `PATH="$HOME/.local/bin:$PATH"` (+ `LD_LIBRARY_PATH` for `hyprsunset`). The service also prefers `hyprsunset` (kills stale `wlsunset` when switching).

---

## Issue 17: Night light colour shift not visible

**Symptom:** `caelestia shell nightlight enable` returns `enabled`, `status` shows `enabled: true`, but the screen stays neutral — even `hyprctl hyprsunset temperature 2800` from the terminal says `Couldn't connect to .../.hyprsunset.sock (3)`.

**Root Cause (two bugs stacked):**

1. `hyprsunset` was launched with no `HYPRLAND_INSTANCE_SIGNATURE` — Hyprland 0.53's `hyprland-ctm-control-v1` daemon binds to `/run/user/1000/hypr/<SIGNATURE>/.hyprsunset.sock`. The Hyprland-launched `qs` had `HYPRLAND_INSTANCE_SIGNATURE=` (empty) because `Startup_Apps.conf` didn't export it; the daemon bound to the wrong path, and every subsequent `hyprctl hyprsunset …` looked in the right path and got `ENOENT`.
2. A stale `.hyprsunset.sock` left by a crashed previous daemon blocks the next bind — `hyprsunset` exits immediately, `qs` retries forever.

**Fix:** Every place `hyprsunset` is spawned or `hyprctl hyprsunset` is called now injects the signature:

```bash
HYPRLAND_INSTANCE_SIGNATURE=$(ls /run/user/1000/hypr 2>/dev/null | head -n1)
export HYPRLAND_INSTANCE_SIGNATURE; export WAYLAND_DISPLAY=wayland-1; export XDG_RUNTIME_DIR=/run/user/1000
exec /home/algochad/.local/bin/hyprsunset --identity   # or hyprctl hyprsunset temperature …
```

The `hyprDaemon` cleans the stale socket before `exec`. Two thin wrappers in `~/.local/bin/` (`nightlight-hyprsunset` + `nightlight-hyprctl`) now centralize this; the service's `hyprDaemon` and `execDetached` calls invoke the wrappers so neither the Settings toggle nor the terminal needs per-call boilerplate.

---

## Issue 18: Night light slider not “live”

**Symptom:** Dragging the **Colour temperature** slider only tints the screen on mouse release — the drag itself looks dead.

**Fix:** The page's `SliderRow` fires `onMoved(v)` at ~60 Hz. The service maps `v` (0–1) → `1000–6500 K` instantly via `execDetached` (`hyprctl hyprsunset temperature …`) — fire-and-forget, no `Process` queue, so both the toggle and the drag are realtime. Previous drafts debounced the slider; now `onTemperatureChanged` → `_apply()` unconditionally (same path as `onEnabledChanged`), and `setTemperature` clamps to `minTemp`/`maxTemp` before assigning.

---

## Issue 19: Black screen on Hyprland boot (only mouse visible)

**Symptom:** After a reboot or after `pkill -x qs; caelestia shell -d`, Hyprland shows a black desktop with only a cursor. `caelestia shell -d` from a GNOME session fails with `M3Shapes is not installed` or `ImageAnalyser is not a type`.

**Root Causes (stacked):**

1. `ENVariables.conf`'s `QML_IMPORT_PATH` was `…/qt6.11/…/qml:/usr/lib/qt6/qml`, but the system `M3Shapes` plugin lives in `/usr/lib/x86_64-linux-gnu/qt6/qml` (`/usr/lib/qt6/qml` is a legacy path, empty on Ubuntu 26.04's multi-arch Qt).
2. A `Startup_Apps.conf` wrapper I added (`sh -c 'SIG=$(ls /run/user/…); exec caelestia shell -d'`) ran before `/run/user/1000/hypr/<SIG>` existed on cold boot → empty `HYPRLAND_INSTANCE_SIGNATURE` → `hyprsunset` bound nowhere → `hyprDaemon` flap.
3. `hyprDaemon` always ran even when `enabled == false`, leaving a stale `.hyprsunset.sock` that makes the next daemon exit with `Address already in use`.

**Fix:**

- `ENVariables` now includes the arch path: `:/usr/lib/x86_64-linux-gnu/qt6/qml`. `install.sh` patches existing installs (`sed 's|/usr/lib/qt6/qml$|…/x86_64…|'`).
- `Startup_Apps.conf` reverted to plain `exec-once = caelestia shell -d` — the signature is injected inside the service/wrappers, not at startup time.
- `hyprDaemon` is **lazy** (`running: available && backend == "hyprsunset" && enabled && loaded`) — no daemon while disabled, no stale socket.
- On disk `~/.local/state/caelestia/nightlight.json` is forced to `{"enabled":false,…}` when fixing a wedged boot so the lazy rule actually prevents the daemon.

---

## Issue 20: `ETXTBSY` / stale wheel on rebuild

**Symptom:** `cmake --build` fails with `Text file busy` or `ninja: subcommands failed`, or the running `qs` keeps the old binary mmap'd.

**Fix:** `install.sh` `pkill -x qs`/`pkill -x quickshell` + `rm -f /run/user/1000/hypr/*/.hyprsunset.sock` before `cmake --build`, plus a watch loop that retries `cp` on `ETXTBSY`. Also runs `qs --version` after install to confirm the user-local `~/.local/bin/qs` wins.

---

## Issue 21: Hyprland signature lost after compositor restart

**Symptom:** `ps aux | grep qs` shows `qs` from a previous Hyprland instance; `hyprctl hyprsunset temperature …` and the service both report `Couldn't connect …/.hyprsunset.sock`.

**Fix:** The `nightlight-hypr*` wrappers don't trust `qs`'s inherited `HYPRLAND_INSTANCE_SIGNATURE` — they re-derive it from `ls /run/user/1000/hypr | head -n1` on every exec, and `hyprDaemon` re-cleans the stale socket before each `exec`. A plain `pkill -x qs; rm -f …/.hyprsunset.sock; killall Hyprland || reboot` fixes a wedged session; normal disable/enable in Settings heals it without a reboot.

---
