#!/usr/bin/env bash
#
# Caelestia Shell installer for Ubuntu 25.10/26.04
# https://github.com/caelestia-dots/shell
#
# Prerequisites: Hyprland already installed (e.g. via JaKooLit/Ubuntu-Hyprland)
#

set -euo pipefail

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; }
step()  { echo -e "\n${CYAN}${BOLD}── $* ──${NC}"; }

die() { err "$@"; exit 1; }

# ── Sanity checks ────────────────────────────────────────────────────────────
[[ "$(id -u)" -eq 0 ]] && die "Do not run this script as root."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$HOME/caelestia-build"
QT_INSTALL_DIR="$HOME/qt6.11"
QT_VERSION="6.11.2"
QT_ARCH="linux_gcc_64"
QT_PREFIX="$QT_INSTALL_DIR/$QT_VERSION/$QT_ARCH"

# ── Helper ───────────────────────────────────────────────────────────────────
confirm() {
    echo -e "${YELLOW}$1${NC}"
    read -rp "Continue? [Y/n] " ans
    [[ -z "$ans" || "$ans" =~ ^[Yy] ]] && return 0
    return 1
}

# ── Step 0: Install Qt 6.11 ──────────────────────────────────────────────────
step "Step 0/8: Installing Qt 6.11 (required for Caelestia Shell)"

if [[ -d "$QT_PREFIX/bin" ]] && [[ -f "$QT_PREFIX/qml/QtQuick/Controls/Material/DoubleSpinBox.qml" ]]; then
    ok "Qt $QT_VERSION already installed"
else
    info "Downloading Qt $QT_VERSION via aqtinstall..."

    # Install aqtinstall into a temporary venv
    AQT_VENV="$BUILD_DIR/.aqt-venv"
    mkdir -p "$BUILD_DIR"
    python3 -m venv "$AQT_VENV" --system-site-packages 2>/dev/null || python3 -m venv "$AQT_VENV"
    "$AQT_VENV/bin/pip" install -q aqtinstall

    "$AQT_VENV/bin/aqt" install-qt linux desktop "$QT_VERSION" "$QT_ARCH" \
        -O "$QT_INSTALL_DIR" 2>&1 | tail -5

    # Install required Qt modules
    info "Installing Qt modules (shadertools, imageformats)..."
    "$AQT_VENV/bin/aqt" install-qt linux desktop "$QT_VERSION" "$QT_ARCH" \
        -O "$QT_INSTALL_DIR" -m qtshadertools 2>&1 | tail -3
    "$AQT_VENV/bin/aqt" install-qt linux desktop "$QT_VERSION" "$QT_ARCH" \
        -O "$QT_INSTALL_DIR" -m qtimageformats 2>&1 | tail -3

    ok "Qt $QT_VERSION installed to $QT_INSTALL_DIR"
fi

# ── Step 1: APT dependencies ────────────────────────────────────────────────
step "Step 1/8: Installing APT dependencies"

sudo apt update
sudo apt install -y \
    build-essential cmake ninja-build git pkg-config meson \
    qt6-base-dev qt6-declarative-dev qt6-svg-dev qt6-wayland-dev \
    qt6-wayland qt6-shader-baker libqt6svg6 \
    libwayland-dev wayland-protocols libjemalloc-dev \
    libpipewire-0.3-dev libxcb1-dev libdrm-dev \
    python3-pip python3-build python3-hatchling \
    libnotify-bin grim slurp wl-clipboard \
    fish brightnessctl ddcutil lm-sensors swappy \
    papirus-icon-theme \
    libqalculate-dev libaubio-dev libiniparser-dev libfftw3-dev libsensors-dev

ok "APT dependencies installed"

# ── Step 2: Fonts ────────────────────────────────────────────────────────────
step "Step 2/8: Installing Fonts (CascadiaCode, Rubik, Material Symbols Rounded)"

mkdir -p ~/.local/share/fonts
FONT_TMP="$(mktemp -d)"

# CascadiaCode Nerd Font
if fc-list | grep -qi "CaskaydiaCove"; then
    ok "CascadiaCode Nerd Font already installed, skipping"
else
    wget -q --show-progress -O "$FONT_TMP/CascadiaCode.zip" \
        https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/CascadiaCode.zip
    unzip -qo "$FONT_TMP/CascadiaCode.zip" -d "$FONT_TMP/CascadiaCode"
    cp "$FONT_TMP"/CascadiaCode/*.ttf ~/.local/share/fonts/
    ok "CascadiaCode Nerd Font installed"
fi

# Rubik Variable Font
if fc-list | grep -qi "Rubik"; then
    ok "Rubik font already installed, skipping"
else
    wget -q --show-progress -O "$FONT_TMP/Rubik.ttf" \
        "https://github.com/google/fonts/raw/main/ofl/rubik/Rubik%5Bwght%5D.ttf"
    cp "$FONT_TMP/Rubik.ttf" ~/.local/share/fonts/
    ok "Rubik font installed"
fi

# Material Symbols Rounded Variable Font
if fc-list | grep -qi "Material Symbols Rounded"; then
    ok "Material Symbols Rounded font already installed, skipping"
else
    wget -q --show-progress -O "$FONT_TMP/MaterialSymbolsRounded.ttf" \
        "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL,GRAD,opsz,wght%5D.ttf"
    cp "$FONT_TMP/MaterialSymbolsRounded.ttf" ~/.local/share/fonts/
    ok "Material Symbols Rounded font installed"
fi

fc-cache -f
rm -rf "$FONT_TMP"

# ── Step 3: Build Quickshell ────────────────────────────────────────────────
step "Step 3/8: Building Quickshell"

mkdir -p "$BUILD_DIR"

if command -v quickshell &>/dev/null; then
    warn "Quickshell binary found. Rebuilding anyway."
fi

cd "$BUILD_DIR"
if [[ -d quickshell ]]; then
    info "Quickshell source already cloned, pulling latest..."
    cd quickshell && git pull
else
    git clone https://git.outfoxxed.me/quickshell/quickshell.git
    cd quickshell
fi

rm -rf build
cmake -GNinja -B build -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_PREFIX_PATH="$QT_PREFIX" \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_INSTALL_RPATH="$QT_PREFIX/lib;/usr/lib/x86_64-linux-gnu" \
    -DCRASH_REPORTER=OFF \
    -DCRASH_HANDLER=OFF \
    -DINSTALL_QML_PREFIX=lib/qt6/qml

cmake --build build
sudo cmake --install build

ok "Quickshell installed"

# ── Step 4: Build libcava ────────────────────────────────────────────────────
step "Step 4/8: Building libcava (LukashonakV fork)"

cd "$BUILD_DIR"
if [[ -d libcava ]]; then
    info "libcava source already cloned, pulling latest..."
    cd libcava && git pull
else
    git clone https://github.com/LukashonakV/cava.git libcava
    cd libcava
fi

rm -rf build
meson setup build --buildtype=release -Ddefault_library=shared 2>/dev/null \
    || meson setup build --buildtype=release -Ddefault_library=shared
meson compile -C build
sudo meson install -C build

# Library path
if [[ ! -f /etc/ld.so.conf.d/libcava.conf ]]; then
    echo "/usr/local/lib/x86_64-linux-gnu" | sudo tee /etc/ld.so.conf.d/libcava.conf >/dev/null
    sudo ldconfig
    ok "libcava library path configured"
fi

ok "libcava installed"

# ── Step 5: Install Caelestia CLI ────────────────────────────────────────────
step "Step 5/8: Installing Caelestia CLI"

cd "$BUILD_DIR"
if [[ -d caelestia-cli ]]; then
    info "caelestia-cli source already cloned, pulling latest..."
    cd caelestia-cli && git pull
else
    git clone https://github.com/caelestia-dots/cli.git caelestia-cli
    cd caelestia-cli
fi

python3 -m build --wheel
sudo pip3 install dist/*.whl --break-system-packages --force-reinstall

ok "Caelestia CLI installed"

# ── Step 6: Build Caelestia Shell ────────────────────────────────────────────
step "Step 6/8: Building Caelestia Shell"

# Ensure Qt 6.11 is used for build
export PATH="$QT_PREFIX/bin:${PATH}"
export LD_LIBRARY_PATH="$QT_PREFIX/lib:${LD_LIBRARY_PATH:-}"
export QML_IMPORT_PATH="$QT_PREFIX/qml:/usr/lib/qt6/qml"

mkdir -p ~/.config/quickshell

SHELL_DIR="$HOME/.config/quickshell/caelestia"
if [[ -d "$SHELL_DIR" ]]; then
    info "Caelestia Shell source already cloned, pulling latest..."
    cd "$SHELL_DIR" && git pull
else
    git clone https://github.com/caelestia-dots/shell.git "$SHELL_DIR"
    cd "$SHELL_DIR"
fi

rm -rf build
PKG_CONFIG_PATH="/usr/local/lib/x86_64-linux-gnu/pkgconfig:${PKG_CONFIG_PATH:-}" \
cmake -B build -G Ninja \
    -DCMAKE_PREFIX_PATH="$QT_PREFIX" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/ \
    -DCMAKE_INSTALL_RPATH="$QT_PREFIX/lib;/usr/lib/x86_64-linux-gnu:$ORIGIN:$ORIGIN/../lib:$ORIGIN/lib"

cmake --build build
sudo cmake --install build

ok "Caelestia Shell installed"

# ── Step 7: Replace stale /usr/local/bin/quickshell ──────────────────────────
step "Step 7/8: Fixing quickshell binary paths"

# The old /usr/local/bin/quickshell (if installed by caelestia-cli) may be stale
# Copy our rebuilt Qt 6.11 binary there too
if [[ -f /usr/local/bin/quickshell ]]; then
    if ! cmp -s /usr/bin/quickshell /usr/local/bin/quickshell 2>/dev/null; then
        warn "Replacing stale /usr/local/bin/quickshell with rebuilt version..."
        sudo cp /usr/bin/quickshell /usr/local/bin/quickshell
        sudo chmod 755 /usr/local/bin/quickshell
        ok "Updated /usr/local/bin/quickshell"
    else
        ok "/usr/local/bin/quickshell is already correct"
    fi
fi

ok "Quickshell binaries verified"

# ── Step 8: Configuration ──────────────────────────────────────────────────
step "Step 8/8: Setting up configuration"

# Environment variables in bashrc
update_bashrc_var() {
    local var_name="$1"
    local var_value="$2"
    if ! grep -q "^export $var_name=" ~/.bashrc 2>/dev/null; then
        echo "export $var_name=\"$var_value\"" >> ~/.bashrc
        ok "Added $var_name to ~/.bashrc"
    else
        sed -i "/^export $var_name=/c\export $var_name=\"$var_value\"" ~/.bashrc
        ok "Updated $var_name in ~/.bashrc"
    fi
}

update_bashrc_var "PATH" "$QT_PREFIX/bin:\${PATH}"
update_bashrc_var "LD_LIBRARY_PATH" "$QT_PREFIX/lib:\${LD_LIBRARY_PATH:-}"
update_bashrc_var "QML_IMPORT_PATH" "$QT_PREFIX/qml:/usr/lib/qt6/qml"

# Fix qt6ct icon theme if set to a missing theme (e.g. Tokyonight-Dark)
if [[ -f ~/.config/qt6ct/qt6ct.conf ]]; then
    current_icon_theme=$(grep "^icon_theme=" ~/.config/qt6ct/qt6ct.conf 2>/dev/null | cut -d= -f2)
    if [[ -n "$current_icon_theme" ]] && [[ ! -d "/usr/share/icons/$current_icon_theme" ]] && [[ ! -d "$HOME/.icons/$current_icon_theme" ]] && [[ ! -d "$HOME/.local/share/icons/$current_icon_theme" ]]; then
        warn "qt6ct icon theme '$current_icon_theme' not found, switching to Adwaita"
        sed -i 's/^icon_theme=.*/icon_theme=Adwaita/' ~/.config/qt6ct/qt6ct.conf
        ok "Set qt6ct icon_theme to Adwaita"
    else
        ok "qt6ct icon theme '$current_icon_theme' is available"
    fi
fi

# Copy config files from this repo
if [[ -f "$SCRIPT_DIR/config/shell.json" ]]; then
    mkdir -p ~/.config/caelestia
    cp -f "$SCRIPT_DIR/config/shell.json" ~/.config/caelestia/shell.json
    ok "Copied shell.json to ~/.config/caelestia/"
fi

if [[ -f "$SCRIPT_DIR/config/quickshell/qml_color.json" ]]; then
    cp -f "$SCRIPT_DIR/config/quickshell/qml_color.json" ~/.config/quickshell/qml_color.json
    ok "Copied qml_color.json to ~/.config/quickshell/"
fi

# Wallpaper directory
mkdir -p ~/Pictures/Wallpapers
ok "Created ~/Pictures/Wallpapers/"

# Hyprland configuration: disable Waybar/AGS, start caelestia
if [[ -f ~/.config/hypr/configs/Startup_Apps.conf ]]; then
    info "Configuring Hyprland startup..."

    # Comment out old bar/waybar entries in the vendor config
    sed -i 's/^exec-once = .*[Ww]aybar.*$/# Disabled by caelestia installer: using caelestia shell/' ~/.config/hypr/configs/Startup_Apps.conf 2>/dev/null || true
    sed -i 's/^exec-once = .*ags.*$/# Disabled by caelestia installer: using caelestia shell/' ~/.config/hypr/configs/Startup_Apps.conf 2>/dev/null || true
    sed -i 's/^exec-once = qs -c overview.*$/# Disabled by caelestia installer: using caelestia shell/' ~/.config/hypr/configs/Startup_Apps.conf 2>/dev/null || true

    # Add caelestia to user startup config if not present
    USER_STARTUP="$HOME/.config/hypr/UserConfigs/Startup_Apps.conf"
    mkdir -p "$(dirname "$USER_STARTUP")"
    touch "$USER_STARTUP"

    if ! grep -q "caelestia shell" "$USER_STARTUP" 2>/dev/null; then
        echo "" >> "$USER_STARTUP"
        echo "# Caelestia Shell (installed by caelestia-shell-ubuntu)" >> "$USER_STARTUP"
        echo "exec-once = caelestia shell -d" >> "$USER_STARTUP"
        ok "Added caelestia shell to Hyprland startup"
    else
        ok "caelestia shell already in Hyprland startup"
    fi
fi

# Add Qt 6.11 environment variables to Hyprland config so caelestia starts with correct paths
USER_ENVVARS="$HOME/.config/hypr/UserConfigs/ENVariables.conf"
if [[ -f "$USER_ENVVARS" ]]; then
    if ! grep -q "QML_IMPORT_PATH.*qt6.11" "$USER_ENVVARS" 2>/dev/null; then
        info "Adding Qt 6.11 env vars to Hyprland ENVariables.conf..."
        sed -i '/^### QT Variables ###/i \\
### Qt 6.11 (caelestia shell) ###\\
env = QML_IMPORT_PATH,'"$QT_PREFIX"'/qml:/usr/lib/qt6/qml\\
env = LD_LIBRARY_PATH,'"$QT_PREFIX"'/lib:${LD_LIBRARY_PATH}\\
' "$USER_ENVVARS"
        ok "Added Qt 6.11 env vars to Hyprland ENVariables.conf"
    else
        ok "Qt 6.11 env vars already in Hyprland ENVariables.conf"
    fi
fi

# Add caelestia keybinds to Hyprland user keybinds config
USER_KEYBINDS="$HOME/.config/hypr/UserConfigs/UserKeybinds.conf"
if [[ -f "$USER_KEYBINDS" ]]; then
    if ! grep -q "caelestia.*launcher" "$USER_KEYBINDS" 2>/dev/null; then
        info "Adding caelestia keybinds to UserKeybinds.conf..."
        cat >> "$USER_KEYBINDS" << 'EOF'

##############
# Caelestia  #
##############

# Unbind JaKooLit's togglefloating on Super+Space (rebound to caelestia launcher)
unbind = $mainMod, SPACE

# Toggle launcher on Super+Space via IPC
bindd = SUPER, SPACE, Open caelestia launcher, exec, caelestia shell drawers toggle launcher

# Toggle session menu
bindd = SUPER SHIFT, E, Toggle session menu, exec, caelestia shell drawers toggle session

# Lock screen
bindd = SUPER, L, Lock screen, exec, caelestia shell lock lock
EOF
        ok "Added caelestia keybinds to UserKeybinds.conf"
    else
        ok "Caelestia keybinds already in UserKeybinds.conf"
    fi
fi

# Disable Waybar systemd autostart (JaKooLit/Hyprland-Dots enables it globally)
WAYBAR_LINK="/etc/systemd/user/graphical-session.target.wants/waybar.service"
if [[ -L "$WAYBAR_LINK" ]]; then
    warn "Removing Waybar systemd autostart..."
    sudo rm -f "$WAYBAR_LINK"
    ok "Removed Waybar from systemd autostart"
fi

# Mask waybar and ags in user scope to prevent any accidental start
systemctl --user mask waybar.service 2>/dev/null || true
systemctl --user mask ags.service 2>/dev/null || true
systemctl --user stop waybar.service 2>/dev/null || true
systemctl --user stop ags.service 2>/dev/null || true
ok "Waybar and AGS masked in systemd"

# Patch JaKooLit theme/wallpaper scripts to restart caelestia instead of waybar
if [[ -d ~/.config/hypr/scripts ]]; then
    info "Patching JaKooLit Hyprland scripts for caelestia compatibility..."

    SCRIPTS_DIR="$HOME/.config/hypr/scripts"

    # Refresh.sh: replace restart_waybar with restart_caelestia
    if [[ -f "$SCRIPTS_DIR/Refresh.sh" ]] && grep -q "restart_waybar" "$SCRIPTS_DIR/Refresh.sh"; then
        sed -i '/# Restart waybar once/,/^restart_waybar$/c\
# Restart caelestia shell (replaces waybar)\
restart_caelestia() {\
  pkill -x qs >/dev/null 2>&1 || true\
  pkill -x quickshell >/dev/null 2>&1 || true\
  sleep 0.2\
  if pgrep -x qs >/dev/null 2>&1 || pgrep -x quickshell >/dev/null 2>&1; then\
    pkill -9 -x qs >/dev/null 2>&1 || true\
    pkill -9 -x quickshell >/dev/null 2>&1 || true\
  fi\
  sleep 0.2\
  caelestia shell -d >/dev/null 2>&1 &\
}\
\
restart_caelestia' "$SCRIPTS_DIR/Refresh.sh"
        ok "Patched Refresh.sh"
    fi

    # DarkLight.sh: replace waybar kill with qs/quickshell
    if [[ -f "$SCRIPTS_DIR/DarkLight.sh" ]] && grep -q "killall.*waybar" "$SCRIPTS_DIR/DarkLight.sh"; then
        sed -i 's/for pid1 in waybar rofi swaync ags swaybg/for pid1 in qs quickshell rofi swaync ags swaybg/' "$SCRIPTS_DIR/DarkLight.sh"
        ok "Patched DarkLight.sh"
    fi

    # ToggleWaybarTime.sh: make restart_waybar a no-op
    if [[ -f "$SCRIPTS_DIR/ToggleWaybarTime.sh" ]]; then
        sed -i 's/restart_waybar() {.*/restart_waybar() {\n  # Caelestia replaces waybar; no restart needed.\n  :\n}/; /pkill.*waybar/d; /pgrep.*waybar/d; /systemctl.*waybar/d; /waybar \u003e/d; /}#/d' "$SCRIPTS_DIR/ToggleWaybarTime.sh" 2>/dev/null || true
        ok "Patched ToggleWaybarTime.sh"
    fi

    # WaybarStartup.sh: start caelestia instead
    if [[ -f "$SCRIPTS_DIR/WaybarStartup.sh" ]] && grep -q "waybar" "$SCRIPTS_DIR/WaybarStartup.sh"; then
        sed -i 's/waybar/caelestia shell -d/g' "$SCRIPTS_DIR/WaybarStartup.sh"
        ok "Patched WaybarStartup.sh"
    fi

    # WaybarLayout.sh: disable waybar restarts
    if [[ -f "$SCRIPTS_DIR/WaybarLayout.sh" ]]; then
        sed -i 's/restart_waybar.*/# Disabled: using caelestia instead (waybar restart removed)/' "$SCRIPTS_DIR/WaybarLayout.sh"
        sed -i 's/waybar-msg.*reload/# Disabled: using caelestia instead/' "$SCRIPTS_DIR/WaybarLayout.sh"
        sed -i 's/pkill.*-SIGUSR2.*waybar/# Disabled: using caelestia instead/' "$SCRIPTS_DIR/WaybarLayout.sh"
        ok "Patched WaybarLayout.sh"
    fi

    # HyprLayoutModule.sh: disable refresh_waybar
    if [[ -f "$SCRIPTS_DIR/HyprLayoutModule.sh" ]]; then
        sed -i 's/pkill -RTMIN+8 waybar/# Disabled: using caelestia instead/' "$SCRIPTS_DIR/HyprLayoutModule.sh"
        ok "Patched HyprLayoutModule.sh"
    fi

    ok "JaKooLit scripts patched for caelestia"
fi

# Hyprland environment variable for QML_IMPORT_PATH
if [[ -f ~/.config/hypr/hyprland.conf ]]; then
    if ! grep -q 'QML_IMPORT_PATH' ~/.config/hypr/hyprland.conf 2>/dev/null; then
        warn "Add this line to ~/.config/hypr/hyprland.conf:"
        echo "  env = QML_IMPORT_PATH,$QT_PREFIX/qml:/usr/lib/qt6/qml"
    else
        ok "QML_IMPORT_PATH already set in hyprland.conf"
    fi
fi

ok "Configuration complete"

# ── Done ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  Caelestia Shell installation complete!${NC}"
echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "To start the shell manually:"
echo -e "  ${CYAN}caelestia shell -d${NC}"
echo ""
echo -e "To auto-start with Hyprland:"
echo -e "  ${CYAN}exec-once = caelestia shell -d${NC}"
echo ""
echo -e "Add wallpapers to ${BOLD}~/Pictures/Wallpapers/${NC}"
echo -e "Edit shell config at ${BOLD}~/.config/caelestia/shell.json${NC}"
echo ""
echo -e "${YELLOW}NOTE: Open a new terminal or run 'source ~/.bashrc' to load environment.${NC}"
echo -e "${YELLOW}NOTE: Logout/login or restart Hyprland for startup changes to take effect.${NC}"
