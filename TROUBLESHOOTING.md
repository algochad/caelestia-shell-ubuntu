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

## For Next Agent / Next Machine

1. Clone this repo on the target machine
2. Run `./install.sh` (it's fully automated now)
3. If any issue occurs, check this file — all fixes are documented
4. The installer assumes JaKooLit's Hyprland-Dots is already installed
5. After install, **logout/login** for Hyprland startup changes

## Commit History

```
7a368d5 fix(install): patch JaKooLit theme scripts for caelestia compatibility
45cc688 fix(install): mask Waybar/AGS systemd services and remove autostart
f835f41 fix(install): automate Qt 6.11, fonts, and Hyprland bar replacement
a8982d1 fix: Qt 6.11 upgrade, missing dependencies, and fonts
9c4b003 Initial commit: caelestia-shell-ubuntu installer
```
