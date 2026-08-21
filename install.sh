#!/usr/bin/env bash
#
# Caelestia Shell installer for Ubuntu 25.10/26.04
# https://github.com/caelestia-dots/shell
#
# Prerequisites: Hyprland already installed (e.g. via JaKooLit/Ubuntu-Hyprland)
#
# Can be run locally or via curl:
#   curl -fsSL https://raw.githubusercontent.com/algochad/caelestia-shell-ubuntu/master/install.sh | bash
#

# If this script is being piped (curl | bash), clone the repo and re-run locally
# so that SCRIPT_DIR and config/ files are available.
if [[ -z "${BASH_SOURCE[0]:-}" ]] || [[ ! -f "${BASH_SOURCE[0]}" ]]; then
    REPO_URL="https://github.com/algochad/caelestia-shell-ubuntu.git"
    TMP_DIR="$(mktemp -d)"
    echo "[INFO] Running via curl | bash; cloning repository..."
    if ! git clone --depth 1 "$REPO_URL" "$TMP_DIR"; then
        echo "[ERROR] Failed to clone $REPO_URL" >&2
        exit 1
    fi
    cd "$TMP_DIR"
    exec ./install.sh "$@"
fi

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
QT_PREFIX="$QT_INSTALL_DIR/$QT_VERSION/gcc_64"

# Ensure tools installed to ~/.local/bin are discoverable in this session
export PATH="$HOME/.local/bin:$PATH"

# ── Helper ───────────────────────────────────────────────────────────────────
confirm() {
    echo -e "${YELLOW}$1${NC}"
    read -rp "Continue? [Y/n] " ans
    [[ -z "$ans" || "$ans" =~ ^[Yy] ]] && return 0
    return 1
}

# Append a directory to PATH in ~/.bashrc if not already present
append_bashrc_path() {
    local dir="$1"
    if ! grep -q "^export PATH=.*${dir}" ~/.bashrc 2>/dev/null; then
        echo "export PATH=\"${dir}:\${PATH}\"" >> ~/.bashrc
        ok "Added ${dir} to PATH in ~/.bashrc"
    fi
}

# ── Step 0: Install Qt 6.11 ──────────────────────────────────────────────────
step "Step 0/15: Installing Qt 6.11 (required for Caelestia Shell)"

if [[ -d "$QT_PREFIX/bin" ]] && [[ -f "$QT_PREFIX/qml/QtQuick/Controls/Material/DoubleSpinBox.qml" ]]; then
    ok "Qt $QT_VERSION already installed"
else
    info "Downloading Qt $QT_VERSION via aqtinstall..."

    # Ensure python3 venv support is available before creating one
    if ! python3 -m venv --help &>/dev/null; then
        info "python3-venv missing; installing via apt..."
        # Try version-specific first, fall back to generic
        PY_VENV_PKG="python3-venv"
        PY_MINOR="$(python3 -c 'import sys; print(sys.version_info.minor)' 2>/dev/null)"
        if [[ -n "$PY_MINOR" ]] && apt-cache show "python3.${PY_MINOR}-venv" &>/dev/null; then
            PY_VENV_PKG="python3.${PY_MINOR}-venv"
        fi
        sudo apt update
        sudo apt install -y "$PY_VENV_PKG" || sudo apt install -y python3-venv
    fi

    # Install aqtinstall into a temporary venv
    AQT_VENV="$BUILD_DIR/.aqt-venv"
    mkdir -p "$BUILD_DIR"
    python3 -m venv "$AQT_VENV" --system-site-packages 2>/dev/null || python3 -m venv "$AQT_VENV"
    "$AQT_VENV/bin/pip" install -q aqtinstall

    "$AQT_VENV/bin/aqt" install-qt linux desktop "$QT_VERSION" "$QT_ARCH" \
        -O "$QT_INSTALL_DIR" 2>&1 | tail -5

    # Install required Qt modules
    info "Installing Qt modules (shadertools, imageformats, tasktree)..."
    "$AQT_VENV/bin/aqt" install-qt linux desktop "$QT_VERSION" "$QT_ARCH" \
        -O "$QT_INSTALL_DIR" -m qtshadertools 2>&1 | tail -3
    "$AQT_VENV/bin/aqt" install-qt linux desktop "$QT_VERSION" "$QT_ARCH" \
        -O "$QT_INSTALL_DIR" -m qtimageformats 2>&1 | tail -3
    "$AQT_VENV/bin/aqt" install-qt linux desktop "$QT_VERSION" "$QT_ARCH" \
        -O "$QT_INSTALL_DIR" -m qttasktree 2>&1 | tail -3

    ok "Qt $QT_VERSION installed to $QT_INSTALL_DIR"
fi

# Export Qt 6.11 paths so all subsequent builds use it instead of system Qt 6.10
export PATH="$QT_PREFIX/bin:${PATH}"
export LD_LIBRARY_PATH="$QT_PREFIX/lib:$HOME/.local/lib:${LD_LIBRARY_PATH:-}"
export QML_IMPORT_PATH="$QT_PREFIX/qml:/usr/lib/qt6/qml"

# ── Step 1: APT dependencies ────────────────────────────────────────────────
step "Step 1/15: Installing APT dependencies"

sudo apt update
info "Installing APT dependencies (some may conflict on custom systems — continuing anyway)..."
sudo apt install -y --fix-broken --no-install-recommends \
    build-essential cmake ninja-build git pkg-config meson \
    qt6-base-dev qt6-declarative-dev qt6-svg-dev qt6-wayland-dev \
    qt6-wayland qt6-shader-baker libqt6svg6 \
    libwayland-dev wayland-protocols libjemalloc-dev \
    libpipewire-0.3-dev libxcb1-dev libdrm-dev \
    python3-pip python3-build python3-hatchling \
    libnotify-bin grim slurp wl-clipboard \
    fish brightnessctl ddcutil lm-sensors swappy \
    papirus-icon-theme \
    libqalculate-dev libaubio-dev libiniparser-dev libfftw3-dev libsensors-dev \
    libcli11-dev \
|| warn "Some APT packages failed due to version conflicts (common with mesa-git PPAs). Continuing — you may need to resolve these manually."

# ── mesa-git PPA workaround ──────────────────────────────────────────────────
# The mesa-git PPA provides newer runtime libraries but may not provide
# matching -dev packages, causing apt dependency conflicts. We extract missing
# dev packages locally so CMake/pkg-config can find headers and .pc files.

extract_apt_dev_locally() {
    local pkg="$1"
    local pc_name="${2:-$pkg}"
    local so_name="${3:-$pc_name}"

    if pkg-config --exists "$pc_name" 2>/dev/null; then
        return 0
    fi

    info "Extracting $pkg locally (mesa-git PPA workaround)..."
    mkdir -p "$HOME/.local/include" "$HOME/.local/lib" "$HOME/.local/lib/pkgconfig"

    local dl_dir
    dl_dir="$(mktemp -d)"
    cd "$dl_dir"
    apt download "$pkg" 2>/dev/null
    local deb_path
    deb_path="$(find "$dl_dir" -maxdepth 1 -name "${pkg}_*.deb" -print -quit 2>/dev/null)"
    cd - >/dev/null

    if [[ -z "$deb_path" ]] || [[ ! -f "$deb_path" ]]; then
        rm -rf "$dl_dir"
        warn "Could not download $pkg deb. Skipping."
        return 1
    fi

    local extract_dir="/tmp/${pkg}-local"
    rm -rf "$extract_dir"
    dpkg -x "$deb_path" "$extract_dir"
    rm -rf "$dl_dir"

    # Copy headers
    if [[ -d "$extract_dir/usr/include" ]]; then
        cp -r "$extract_dir/usr/include/"* "$HOME/.local/include/" 2>/dev/null || true
    fi

    # Copy library files (.a, .so, .so.*) from the dev package
    if [[ -d "$extract_dir/usr/lib/x86_64-linux-gnu" ]]; then
        find "$extract_dir/usr/lib/x86_64-linux-gnu" -maxdepth 1 \( -name "lib${so_name}.a" -o -name "lib${so_name}.so" -o -name "lib${so_name}.so.*" \) -exec cp {} "$HOME/.local/lib/" \; 2>/dev/null || true
    fi

    # Copy pkg-config files and fix prefix
    if [[ -d "$extract_dir/usr/lib/x86_64-linux-gnu/pkgconfig" ]]; then
        cp "$extract_dir/usr/lib/x86_64-linux-gnu/pkgconfig/"*.pc "$HOME/.local/lib/pkgconfig/" 2>/dev/null || true
        for pc in "$HOME/.local/lib/pkgconfig/"*.pc; do
            [[ -f "$pc" ]] || continue
            sed -i 's|^prefix=/usr$|prefix=/home/algochad/.local|' "$pc"
            sed -i 's|^exec_prefix=/usr$|exec_prefix=/home/algochad/.local|' "$pc"
            sed -i 's|^libdir=${prefix}/lib/x86_64-linux-gnu$|libdir=${prefix}/lib|' "$pc"
        done
    fi

    # Create .so symlink pointing to system runtime library (fallback if not copied above)
    if [[ ! -f "$HOME/.local/lib/lib${so_name}.so" ]]; then
        local sys_so
        sys_so="$(find /usr/lib/x86_64-linux-gnu -maxdepth 1 -name "lib${so_name}.so.*" -print -quit 2>/dev/null)"
        if [[ -n "$sys_so" ]]; then
            ln -sf "$sys_so" "$HOME/.local/lib/lib${so_name}.so"
        fi
    fi

    rm -rf "$extract_dir"
    ok "$pkg extracted to ~/.local"
}

# Packages commonly blocked by mesa-git PPA dependency conflicts
extract_apt_dev_locally "libdrm-dev"       "libdrm"           "drm"
extract_apt_dev_locally "libgbm-dev"       "gbm"              "gbm"
extract_apt_dev_locally "libpipewire-0.3-dev" "libpipewire-0.3"  "pipewire-0.3"
extract_apt_dev_locally "libspa-0.2-dev"   "libspa-0.2"       "spa-0.2"
extract_apt_dev_locally "libjemalloc-dev"  "jemalloc"         "jemalloc"
extract_apt_dev_locally "libpolkit-agent-1-dev" "polkit-agent-1"   "polkit-agent-1"
extract_apt_dev_locally "libpolkit-gobject-1-dev" "polkit-gobject-1" "polkit-gobject-1"
# Additional packages that may fail due to cascading dependency conflicts
extract_apt_dev_locally "libfftw3-dev"     "fftw3"            "fftw3"
extract_apt_dev_locally "libaubio-dev"     "aubio"            "aubio"
extract_apt_dev_locally "libiniparser-dev" "iniparser"        "iniparser"
extract_apt_dev_locally "libsensors-dev"   "sensors"          "sensors"
extract_apt_dev_locally "libqalculate-dev" "libqalculate"     "qalculate"
# libqalculate headers need mpfr.h and gmp.h
extract_apt_dev_locally "libmpfr-dev"      "mpfr"             "mpfr"
extract_apt_dev_locally "libgmp-dev"       "gmp"              "gmp"
# aubio runtime library (not just -dev)
extract_apt_dev_locally "libaubio5"        "aubio"            "aubio"

# Ensure local pkg-config and include paths are visible to all subsequent builds
export PKG_CONFIG_PATH="$HOME/.local/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
export LIBRARY_PATH="$HOME/.local/lib:${LIBRARY_PATH:-}"
export CPLUS_INCLUDE_PATH="$HOME/.local/include:${CPLUS_INCLUDE_PATH:-}"
export C_INCLUDE_PATH="$HOME/.local/include:${C_INCLUDE_PATH:-}"

ok "APT dependencies installed"

# ── Step 2: Fonts ────────────────────────────────────────────────────────────
step "Step 2/15: Installing Fonts (CascadiaCode, Rubik, Material Symbols Rounded)"

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
step "Step 3/15: Building Quickshell"

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
    -DQt6_DIR="$QT_PREFIX/lib/cmake/Qt6" \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_INSTALL_RPATH="$QT_PREFIX/lib;/usr/lib/x86_64-linux-gnu" \
    -DCRASH_REPORTER=OFF \
    -DCRASH_HANDLER=OFF \
    -DINSTALL_QML_PREFIX=lib/qt6/qml

cmake --build build
sudo cmake --install build

ok "Quickshell installed"

# ── Step 4: Build libcava ────────────────────────────────────────────────────
step "Step 4/15: Building libcava (LukashonakV fork)"

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
step "Step 5/15: Installing Caelestia CLI"

cd "$BUILD_DIR"
if [[ -d caelestia-cli ]]; then
    info "caelestia-cli source already cloned, pulling latest..."
    cd caelestia-cli && git pull
else
    git clone https://github.com/caelestia-dots/cli.git caelestia-cli
    cd caelestia-cli
fi

# Ensure python build tools are available (apt may have failed to install them)
if ! python3 -c "import build" 2>/dev/null; then
    info "python3-build not available via apt, installing via pip..."
    pip3 install --break-system-packages build hatchling 2>&1 | tail -3
fi

python3 -m build --wheel
sudo pip3 install dist/*.whl --break-system-packages --force-reinstall

ok "Caelestia CLI installed"

# ── Step 6: Build Caelestia Shell ────────────────────────────────────────────
step "Step 6/15: Building Caelestia Shell"

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
    -DCMAKE_PREFIX_PATH="$HOME/.local;$QT_PREFIX" \
    -DQt6_DIR="$QT_PREFIX/lib/cmake/Qt6" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/ \
    -DCMAKE_INSTALL_RPATH="$QT_PREFIX/lib;/usr/lib/x86_64-linux-gnu:\$ORIGIN:\$ORIGIN/../lib:\$ORIGIN/lib"

cmake --build build
sudo cmake --install build

ok "Caelestia Shell installed"

# ── Step 7: Replace stale /usr/local/bin/quickshell ──────────────────────────
step "Step 7/15: Fixing quickshell binary paths"

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
step "Step 8/15: Setting up configuration"

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
update_bashrc_var "LD_LIBRARY_PATH" "$QT_PREFIX/lib:$HOME/.local/lib:\${LD_LIBRARY_PATH:-}"
update_bashrc_var "QML_IMPORT_PATH" "$QT_PREFIX/qml:/usr/lib/qt6/qml"

# ── Caelestia Shell terminal info display (fastfetch-style via Python) ──
if [[ -f "$SCRIPT_DIR/config/caelestia-fetch.py" ]]; then
    # Copy Python script + ASCII logo art to caelestia config dir
    if [[ ! -d "$HOME/.config/caelestia" ]]; then
        mkdir -p "$HOME/.config/caelestia"
    fi
    cp "$SCRIPT_DIR/config/caelestia-fetch.py" "$HOME/.config/caelestia/caelestia-fetch.py"
    cp "$SCRIPT_DIR/config/ubuntu_ascii.txt" "$HOME/.config/caelestia/ubuntu_ascii.txt"
    cp "$SCRIPT_DIR/config/caelestia_ascii.txt" "$HOME/.config/caelestia/caelestia_ascii.txt"
    ok "Installed caelestia-fetch.py and ASCII logo files"

    # Update bashrc to use the Python script
    # Remove old caelestia-info.sh references first
    if grep -q "caelestia-info.sh" ~/.bashrc 2>/dev/null; then
        sed -i '/caelestia-info.sh/d' ~/.bashrc
        sed -i '/# ── Caelestia Shell Info Display ──/d' ~/.bashrc
        ok "Removed old caelestia-info.sh from ~/.bashrc"
    fi

    # Add new Python-based display
    if ! grep -q "caelestia-fetch.py" ~/.bashrc 2>/dev/null; then
        echo "" >> ~/.bashrc
        echo "# ── Caelestia Shell Info Display ──" >> ~/.bashrc
        echo "if command -v caelestia &> /dev/null && [[ -f ~/.config/caelestia/caelestia-fetch.py ]]; then" >> ~/.bashrc
        echo "    python3 ~/.config/caelestia/caelestia-fetch.py" >> ~/.bashrc
        echo "fi" >> ~/.bashrc
        ok "Added caelestia terminal info display to ~/.bashrc"
    else
        ok "caelestia terminal info display already in ~/.bashrc"
    fi
fi

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

# ── FIX: Ensure smartScheme is disabled (prevents wallpaper from overriding manual dark/light mode) ──
USER_SHELL_JSON="$HOME/.config/caelestia/shell.json"
if [[ -f "$USER_SHELL_JSON" ]]; then
    if grep -q '"smartScheme": true' "$USER_SHELL_JSON" 2>/dev/null; then
        sed -i 's/"smartScheme": true/"smartScheme": false/' "$USER_SHELL_JSON"
        ok "Disabled smartScheme in shell.json (prevents wallpaper from overriding dark/light mode)"
    else
        ok "smartScheme already disabled or not present"
    fi
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
        # Prefer inserting before the standard QT Variables marker
        if grep -q '^### QT Variables ###' "$USER_ENVVARS" 2>/dev/null; then
            sed -i '/^### QT Variables ###/i \\
### Qt 6.11 (caelestia shell) ###\\
env = QML_IMPORT_PATH,'"$QT_PREFIX"'/qml:/usr/lib/qt6/qml\\
env = LD_LIBRARY_PATH,'"$QT_PREFIX"'/lib:'"$HOME"'/.local/lib:${LD_LIBRARY_PATH}\\
' "$USER_ENVVARS"
        else
            # Fallback: append to end of file
            echo "" >> "$USER_ENVVARS"
            echo "### Qt 6.11 (caelestia shell) ###" >> "$USER_ENVVARS"
            echo "env = QML_IMPORT_PATH,$QT_PREFIX/qml:/usr/lib/qt6/qml" >> "$USER_ENVVARS"
            echo "env = LD_LIBRARY_PATH,$QT_PREFIX/lib:\${LD_LIBRARY_PATH}" >> "$USER_ENVVARS"
        fi
        ok "Added Qt 6.11 env vars to Hyprland ENVariables.conf"
    else
        ok "Qt 6.11 env vars already in Hyprland ENVariables.conf"
    fi
fi

# Add caelestia keybinds to Hyprland user keybinds config
USER_KEYBINDS="$HOME/.config/hypr/UserConfigs/UserKeybinds.conf"
if [[ -f "$USER_KEYBINDS" ]]; then
    KEYBINDS_CHANGED=false

    # ── FIX: Correct old broken IPC syntax (drawers.toggle → drawers toggle) ──
    if grep -q "drawers\.toggle" "$USER_KEYBINDS" 2>/dev/null; then
        sed -i 's/drawers\.toggle/drawers toggle/g' "$USER_KEYBINDS"
        ok "Fixed IPC syntax in UserKeybinds.conf (drawers.toggle → drawers toggle)"
        KEYBINDS_CHANGED=true
    fi

    # Add caelestia keybinds block if not present at all
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

# Toggle nexus (caelestia settings)
bindd = SUPER, N, Open caelestia nexus, exec, caelestia shell nexus open

# Toggle session menu
bindd = SUPER SHIFT, E, Toggle session menu, exec, caelestia shell drawers toggle session

# Lock screen
bindd = SUPER, L, Lock screen, exec, caelestia shell lock lock
EOF
        ok "Added caelestia keybinds to UserKeybinds.conf"
        KEYBINDS_CHANGED=true
    else
        ok "Caelestia keybinds already in UserKeybinds.conf"
    fi

    # ── FIX: Add nexus keybind if missing ──
    if ! grep -q "caelestia nexus" "$USER_KEYBINDS" 2>/dev/null; then
        info "Adding nexus keybind to UserKeybinds.conf..."
        # Insert nexus keybind after the launcher keybind
        sed -i '/bindd = SUPER, SPACE, Open caelestia launcher/a \
# Toggle nexus (caelestia settings)\nbindd = SUPER, N, Open caelestia nexus, exec, caelestia shell nexus open' "$USER_KEYBINDS"
        ok "Added nexus keybind (Super+N) to UserKeybinds.conf"
        KEYBINDS_CHANGED=true
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
    if [[ -f "$SCRIPTS_DIR/ToggleWaybarTime.sh" ]] && ! grep -q "Caelestia replaces waybar" "$SCRIPTS_DIR/ToggleWaybarTime.sh" 2>/dev/null; then
        sed -i 's/restart_waybar() {.*/restart_waybar() {\n  # Caelestia replaces waybar; no restart needed.\n  :\n}/; /pkill.*waybar/d; /pgrep.*waybar/d; /systemctl.*waybar/d; /waybar >/d; /}#/d' "$SCRIPTS_DIR/ToggleWaybarTime.sh" 2>/dev/null || true
        ok "Patched ToggleWaybarTime.sh"
    else
        ok "ToggleWaybarTime.sh already patched"
    fi

    # WaybarStartup.sh: start caelestia instead
    if [[ -f "$SCRIPTS_DIR/WaybarStartup.sh" ]] && grep -q "waybar" "$SCRIPTS_DIR/WaybarStartup.sh"; then
        sed -i 's/waybar/caelestia shell -d/g' "$SCRIPTS_DIR/WaybarStartup.sh"
        ok "Patched WaybarStartup.sh"
    fi

    # WaybarLayout.sh: disable waybar restarts and add caelestia fallback
    if [[ -f "$SCRIPTS_DIR/WaybarLayout.sh" ]] && ! grep -q "Disabled: using caelestia instead" "$SCRIPTS_DIR/WaybarLayout.sh" 2>/dev/null; then
        sed -i 's/restart_waybar.*/# Disabled: using caelestia instead (waybar restart removed)/' "$SCRIPTS_DIR/WaybarLayout.sh"
        sed -i 's/waybar-msg.*reload/# Disabled: using caelestia instead/' "$SCRIPTS_DIR/WaybarLayout.sh"
        sed -i 's/pkill.*-SIGUSR2.*waybar/# Disabled: using caelestia instead/' "$SCRIPTS_DIR/WaybarLayout.sh"
        ok "Patched WaybarLayout.sh"
    else
        ok "WaybarLayout.sh already patched"
    fi

    # HyprLayoutModule.sh: disable refresh_waybar
    if [[ -f "$SCRIPTS_DIR/HyprLayoutModule.sh" ]] && ! grep -q "Disabled: using caelestia instead" "$SCRIPTS_DIR/HyprLayoutModule.sh" 2>/dev/null; then
        sed -i 's/pkill -RTMIN+8 waybar/# Disabled: using caelestia instead/' "$SCRIPTS_DIR/HyprLayoutModule.sh"
        ok "Patched HyprLayoutModule.sh"
    else
        ok "HyprLayoutModule.sh already patched"
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

# ── Step 9: Install mise ─────────────────────────────────────────────────────
step "Step 9/15: Installing mise"

if command -v mise &>/dev/null; then
    ok "mise already installed ($(mise --version 2>/dev/null || echo unknown))"
else
    info "Installing mise via official installer..."
    curl https://mise.run | MISE_QUIET=1 sh
    if [[ -x "$HOME/.local/bin/mise" ]]; then
        ok "mise installed to ~/.local/bin/mise"
    else
        warn "mise installer ran but binary not found at ~/.local/bin/mise"
    fi
fi

# Ensure mise is activated in ~/.bashrc
if [[ -f "$HOME/.local/bin/mise" ]] && ! grep -q 'mise activate bash' ~/.bashrc 2>/dev/null; then
    echo "" >> ~/.bashrc
    echo "# ── Mise activation ──" >> ~/.bashrc
    echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
    ok "Added mise activation to ~/.bashrc"
fi

# ── Step 10: Install Oh My Bash ─────────────────────────────────────────────
step "Step 10/15: Installing Oh My Bash"

if [[ -d "$HOME/.oh-my-bash" ]]; then
    ok "Oh My Bash already installed"
else
    info "Installing Oh My Bash..."
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" -- --unattended || warn "Oh My Bash installer exited non-zero; continuing"
    if [[ -d "$HOME/.oh-my-bash" ]]; then
        ok "Oh My Bash installed"
    else
        warn "Oh My Bash install may have failed"
    fi
fi

# ── Step 11: Install Bun ──────────────────────────────────────────────────────
step "Step 11/15: Installing Bun"

if command -v bun &>/dev/null; then
    ok "Bun already installed ($(bun --version 2>/dev/null || echo unknown))"
else
    info "Installing Bun via official installer..."
    curl -fsSL https://bun.sh/install | bash
    if [[ -x "$HOME/.bun/bin/bun" ]]; then
        ok "Bun installed to ~/.bun/bin/bun"
    else
        warn "Bun install may have failed"
    fi
fi
append_bashrc_path "$HOME/.bun/bin"

# ── Step 12: Install Oh My Pi (omp) ───────────────────────────────────────────
step "Step 12/15: Installing Oh My Pi (omp)"

if command -v omp &>/dev/null; then
    ok "omp already installed ($(omp --version 2>/dev/null || echo unknown))"
else
    info "Installing omp via official installer..."
    curl -fsSL https://omp.sh/install | sh
    if command -v omp &>/dev/null; then
        ok "omp installed"
    else
        warn "omp install may have failed; you may need to open a new shell"
    fi
fi

# ── Step 13: Install Docker Engine ────────────────────────────────────────────
step "Step 13/15: Installing Docker Engine"

if command -v docker &>/dev/null; then
    ok "Docker already installed ($(docker --version 2>/dev/null || echo unknown))"
else
    info "Adding Docker apt repository..."
    sudo apt install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
    sudo apt update
    info "Installing Docker Engine packages..."
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl enable --now docker
    sudo usermod -aG docker "$(whoami)"
    ok "Docker Engine installed and user added to docker group"
fi

# ── Step 14: Install lazydocker ─────────────────────────────────────────────
step "Step 14/15: Installing lazydocker"

if command -v lazydocker &>/dev/null; then
    ok "lazydocker already installed ($(lazydocker --version 2>/dev/null | head -1 || echo unknown))"
else
    info "Installing lazydocker via official install script..."
    mkdir -p "$HOME/.local/bin"
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh)"
    if command -v lazydocker &>/dev/null; then
        ok "lazydocker installed"
    else
        warn "lazydocker installed to ~/.local/bin but not on PATH yet; open a new shell"
    fi
fi
append_bashrc_path "$HOME/.local/bin"

# ── Step 15: Install VS Code ──────────────────────────────────────────────────
step "Step 15/15: Installing Visual Studio Code"

if command -v code &>/dev/null; then
    ok "VS Code already installed ($(code --version 2>/dev/null | head -1 || echo unknown))"
else
    info "Adding Microsoft apt repository for VS Code..."
    sudo apt install -y wget gpg
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /usr/share/keyrings/microsoft.gpg
    sudo tee /etc/apt/sources.list.d/vscode.sources >/dev/null <<EOF
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64,arm64,armhf
Signed-By: /usr/share/keyrings/microsoft.gpg
EOF
    sudo apt update
    info "Installing VS Code..."
    sudo apt install -y code
    if command -v code &>/dev/null; then
        ok "VS Code installed"
    else
        warn "VS Code install may have failed"
    fi
fi

# ── Done ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  Caelestia Shell + dev environment installation complete!${NC}"
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
echo ""

# ── Auto-start Caelestia Shell ─────────────────────────────────────────────
if command -v caelestia &>/dev/null; then
    if pgrep -x "caelestia" >/dev/null 2>&1 || pgrep -f "caelestia shell" >/dev/null 2>&1; then
        info "Caelestia shell is already running"
    else
        info "Starting Caelestia shell..."
        nohup caelestia shell -d >/dev/null 2>&1 &
        disown
        ok "Caelestia shell started"
    fi
fi
