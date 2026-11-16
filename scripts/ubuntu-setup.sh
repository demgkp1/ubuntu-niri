#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SKIP_APT=0

usage() {
    cat <<'EOF'
Usage: ubuntu-setup.sh [OPTIONS]

Idempotent Ubuntu 26.04 reproduction script for Clavis Shell + Niri + Fcitx5.

Options:
  --skip-apt    Skip apt update and package installation
  -h, --help    Show this help message and exit
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-apt)
            SKIP_APT=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

log() {
    printf '[ubuntu-setup] %s\n' "$*"
}

warn() {
    printf '[ubuntu-setup] WARNING: %s\n' "$*" >&2
}

BUILD_TMP="$(mktemp -d)"
cleanup() {
    rm -rf "$BUILD_TMP"
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Step 1: APT packages
# ---------------------------------------------------------------------------
if [[ "$SKIP_APT" -eq 0 ]]; then
    log "Step 1: Installing APT dependencies..."
    APT_PACKAGES=(
        # Build & base tools
        cmake
        ninja-build
        pkg-config
        build-essential
        python3
        git
        curl
        jq
        tar
        xz-utils
        # Qt6 & system dev libs
        qt6-base-dev
        qt6-declarative-dev
        qt6-shadertools-dev
        qt6-tools-dev
        qt6-wayland-dev
        qtkeychain-qt6-dev
        libudev-dev
        libpipewire-0.3-dev
        libfftw3-dev
        libiniparser-dev
        libxkbcommon-dev
        libwayland-dev
        libwayland-bin
        wayland-protocols
        libglib2.0-dev
        # Qt6 QML runtime modules
        qml6-module-qt5compat-graphicaleffects
        qml6-module-qt-labs-lottieqt
        qml6-module-qtlocation
        qml6-module-qtpositioning
        # Fcitx5 + CJK font
        fcitx5
        fcitx5-chinese-addons
        fcitx5-frontend-all
        fcitx5-config-qt
        fonts-noto-cjk
    )

    sudo apt update
    sudo apt install -y "${APT_PACKAGES[@]}"

    if apt-cache show quickshell >/dev/null 2>&1; then
        sudo apt install -y quickshell
    else
        warn "'quickshell' package not found in configured APT repositories."
        warn "Please install 'quickshell' manually (e.g. from dux-repo) before running Clavis."
    fi
else
    log "Step 1: Skipping APT installation (--skip-apt)."
fi

# ---------------------------------------------------------------------------
# Step 2: uv & meson
# ---------------------------------------------------------------------------
log "Step 2: Ensuring uv and meson are installed..."
export PATH="$HOME/.local/bin:$PATH"
mkdir -p "$HOME/.local/bin"

if ! command -v uv >/dev/null 2>&1; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi

if uv tool list 2>/dev/null | grep -qE '^meson '; then
    uv tool upgrade meson
else
    uv tool install meson
fi

# ---------------------------------------------------------------------------
# Step 3: User-local native deps in ~/.local
# ---------------------------------------------------------------------------
log "Step 3: Building and installing user-local native dependencies in ~/.local..."
mkdir -p "$HOME/.local/lib" "$HOME/.local/include"

# 3a. libcava
log "Building libcava..."
git clone --depth 1 https://github.com/LukashonakV/cava.git "$BUILD_TMP/cava"
meson setup "$BUILD_TMP/cava/build" "$BUILD_TMP/cava" \
    --prefix="$HOME/.local" \
    --libdir=lib \
    -Dcava_font=false
ninja -C "$BUILD_TMP/cava/build" install

# 3b. M3Shapes
log "Building M3Shapes..."
git clone --depth 1 https://github.com/soramanew/m3shapes.git "$BUILD_TMP/m3shapes"
cmake -S "$BUILD_TMP/m3shapes" -B "$BUILD_TMP/m3shapes/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$HOME/.local"
cmake --build "$BUILD_TMP/m3shapes/build"
cmake --install "$BUILD_TMP/m3shapes/build"

# 3c. key-cli + key-sysmon
KEY_CLI_DIR="${KEY_CLI_DIR:-$HOME/projects/key-cli}"
log "Setting up key-cli + key-sysmon in $KEY_CLI_DIR..."
if [[ ! -d "$KEY_CLI_DIR/.git" ]]; then
    mkdir -p "$(dirname -- "$KEY_CLI_DIR")"
    git clone https://github.com/StatIndet/key-cli.git "$KEY_CLI_DIR"
fi
uv tool install --force "$KEY_CLI_DIR"
cmake -S "$KEY_CLI_DIR" -B "$KEY_CLI_DIR/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$HOME/.local" \
    -DBUILD_TESTING=OFF
cmake --build "$KEY_CLI_DIR/build"
cmake --install "$KEY_CLI_DIR/build"

# 3d. matugen v4.2.0
log "Installing matugen v4.2.0..."
MATUGEN_URL="https://github.com/InioX/matugen/releases/download/v4.2.0/matugen-4.2.0-x86_64.tar.gz"
curl -fsSL "$MATUGEN_URL" -o "$BUILD_TMP/matugen.tar.gz"
mkdir -p "$BUILD_TMP/matugen"
tar -xzf "$BUILD_TMP/matugen.tar.gz" -C "$BUILD_TMP/matugen"
MATUGEN_BIN="$(find "$BUILD_TMP/matugen" -type f -name matugen | head -n 1)"
if [[ -z "$MATUGEN_BIN" ]]; then
    echo "Failed to locate matugen binary in archive." >&2
    exit 1
fi
install -Dm755 "$MATUGEN_BIN" "$HOME/.local/bin/matugen"

# ---------------------------------------------------------------------------
# Step 4: Fonts in ~/.local/share/fonts/
# ---------------------------------------------------------------------------
log "Step 4: Installing fonts into ~/.local/share/fonts/..."
FONTS_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONTS_DIR"

if [[ ! -f "$FONTS_DIR/MaterialSymbolsRounded.ttf" ]]; then
    curl -fsSL \
        "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf" \
        -o "$FONTS_DIR/MaterialSymbolsRounded.ttf"
fi

if [[ ! -f "$FONTS_DIR/MaterialSymbolsOutlined.ttf" ]]; then
    curl -fsSL \
        "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsOutlined%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf" \
        -o "$FONTS_DIR/MaterialSymbolsOutlined.ttf"
fi

if [[ ! -f "$FONTS_DIR/LXGWWenKaiGBScreen.ttf" ]]; then
    curl -fsSL \
        "https://github.com/lxgw/LxgwWenKai-Screen/releases/download/v1.530/LXGWWenKaiGBScreen.ttf" \
        -o "$FONTS_DIR/LXGWWenKaiGBScreen.ttf"
fi

if ! compgen -G "$FONTS_DIR/JetBrainsMono/JetBrainsMono*.ttf" >/dev/null && \
   ! compgen -G "$FONTS_DIR/JetBrainsMono*.ttf" >/dev/null; then
    curl -fsSL \
        "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz" \
        -o "$BUILD_TMP/JetBrainsMono.tar.xz"
    mkdir -p "$FONTS_DIR/JetBrainsMono"
    tar -xJf "$BUILD_TMP/JetBrainsMono.tar.xz" -C "$FONTS_DIR/JetBrainsMono"
fi

if command -v fc-cache >/dev/null 2>&1; then
    fc-cache -fv "$FONTS_DIR"
else
    warn "fc-cache not found; skipping font cache refresh."
fi

# ---------------------------------------------------------------------------
# Step 5: Build Clavis C++ QML modules
# ---------------------------------------------------------------------------
log "Step 5: Building Clavis C++ QML modules..."
PKG_CONFIG_PATH="$HOME/.local/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}" \
    cmake -S "$REPO_DIR" -B "$REPO_DIR/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Debug \
    -DBUILD_TESTING=OFF \
    -DCMAKE_CXX_FLAGS="-I$HOME/.local/include" \
    -DCMAKE_BUILD_RPATH="$HOME/.local/lib"
cmake --build "$REPO_DIR/build"

# ---------------------------------------------------------------------------
# Step 6: Launcher & desktop/IME configs
# ---------------------------------------------------------------------------
log "Step 6: Writing launcher and desktop/IME configurations..."

# 6a. ~/.local/bin/start-clavis.sh
START_SCRIPT="$HOME/.local/bin/start-clavis.sh"
cat > "$START_SCRIPT" <<EOF
#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$REPO_DIR"
export PATH="\$HOME/.local/bin:\$PATH"
export QML_IMPORT_PATH="\$REPO_DIR/build/qml:\$HOME/.local/lib/qt6/qml\${QML_IMPORT_PATH:+:\$QML_IMPORT_PATH}"
export LD_LIBRARY_PATH="\$HOME/.local/lib\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"

cd "\$REPO_DIR"
exec qs -p . "\$@"
EOF
chmod +x "$START_SCRIPT"

# 6b. Fcitx5 profile & config (only if missing)
FCITX5_DIR="$HOME/.config/fcitx5"
mkdir -p "$FCITX5_DIR"

if [[ ! -f "$FCITX5_DIR/profile" ]]; then
    cat > "$FCITX5_DIR/profile" <<'EOF'
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=pinyin

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=pinyin
Layout=

[GroupOrder]
0=Default
EOF
fi

if [[ ! -f "$FCITX5_DIR/config" ]]; then
    cat > "$FCITX5_DIR/config" <<'EOF'
[Hotkey/TriggerKeys]
0=Control+space

[Hotkey/AltTriggerKeys]
0=Shift_L
EOF
fi

# 6c. Google Chrome Wayland IME desktop override
CHROME_SYS_DESKTOP="/usr/share/applications/google-chrome.desktop"
CHROME_USER_DESKTOP="$HOME/.local/share/applications/google-chrome.desktop"
if [[ -f "$CHROME_SYS_DESKTOP" && ! -f "$CHROME_USER_DESKTOP" ]]; then
    mkdir -p "$(dirname -- "$CHROME_USER_DESKTOP")"
    cp "$CHROME_SYS_DESKTOP" "$CHROME_USER_DESKTOP"
    sed -i -E \
        's|^(Exec=[^ ]+)|\1 --ozone-platform=wayland --enable-wayland-ime --wayland-text-input-version=3|' \
        "$CHROME_USER_DESKTOP"
fi

# 6d. Niri config block
NIRI_CONFIG="$HOME/.config/niri/config.kdl"
if [[ -f "$NIRI_CONFIG" ]]; then
    if ! grep -q "BEGIN CLAVIS UBUNTU-NIRI" "$NIRI_CONFIG"; then
        cat >> "$NIRI_CONFIG" <<'EOF'

// BEGIN CLAVIS UBUNTU-NIRI
spawn-at-startup "start-clavis.sh"
spawn-at-startup "fcitx5" "-d"

environment {
    XMODIFIERS "@im=fcitx"
    QT_IM_MODULE "fcitx"
    GTK_IM_MODULE null
}

window-rule {
    opacity 0.92
    blur true
    draw-border-with-background false
}

window-rule {
    match is-active=false
    opacity 0.82
}

binds {
    Mod+Shift+O { toggle-window-rule-opacity; }
}
// END CLAVIS UBUNTU-NIRI
EOF
    fi
    if command -v niri >/dev/null 2>&1; then
        niri validate
    fi
fi

log "Setup complete!"
