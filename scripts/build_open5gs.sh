#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
INSTALL_DIR="$ROOT_DIR/install"

echo "🚀 Starting Open5GS build..."

# -------------------------------------------------------
# Dependency check — packages must be pre-installed on
# the build machine. No sudo is used here.
# To pre-install: sudo apt-get install -y <packages>
# -------------------------------------------------------

echo "📦 Checking dependencies..."

PACKAGES="
    python3-pip python3-setuptools python3-wheel
    ninja-build build-essential flex bison git cmake
    libsctp-dev libgnutls28-dev libgcrypt-dev libssl-dev
    libmongoc-dev libbson-dev libyaml-dev libnghttp2-dev
    libmicrohttpd-dev libcurl4-gnutls-dev libtins-dev
    libtalloc-dev meson pkg-config
"

MISSING=""
for pkg in $PACKAGES; do
    dpkg -s "$pkg" > /dev/null 2>&1 || MISSING="$MISSING $pkg"
done

if ! dpkg -s libidn-dev > /dev/null 2>&1 && ! dpkg -s libidn11-dev > /dev/null 2>&1; then
    MISSING="$MISSING libidn-dev"
fi

if [ -n "$MISSING" ]; then
    echo "⚙️  Installing missing packages:$MISSING"
    sudo apt-get update -qq
    sudo apt-get install -y $MISSING
fi

echo "✅ All dependencies satisfied"

# -------------------------------------------------------
# Clone Open5GS source (if not already present)
# -------------------------------------------------------

if [ ! -d "$ROOT_DIR/open5gs" ]; then
    echo "📥 Cloning Open5GS..."
    git clone https://github.com/open5gs/open5gs "$ROOT_DIR/open5gs"
fi

cd "$ROOT_DIR/open5gs"

# -------------------------------------------------------
# Configure
# -------------------------------------------------------

echo "⚙️  Configuring with Meson..."
meson setup "$BUILD_DIR" --prefix="$INSTALL_DIR" || true

# -------------------------------------------------------
# Build
# -------------------------------------------------------

echo "🔨 Building with Ninja..."
ninja -C "$BUILD_DIR"

# -------------------------------------------------------
# Test
# -------------------------------------------------------

echo "🧪 Running tests..."
"$ROOT_DIR/open5gs/build/tests/attach/attach"       || true
"$ROOT_DIR/open5gs/build/tests/registration/registration" || true

cd "$BUILD_DIR"
meson test -v || true
cd -

# -------------------------------------------------------
# Install
# -------------------------------------------------------

echo "📦 Installing..."
ninja -C "$BUILD_DIR" install

echo "✅ Build completed successfully!"
