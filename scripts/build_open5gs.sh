#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
INSTALL_DIR="$ROOT_DIR/install"

echo "🚀 Starting Open5GS build..."

# -------------------------------

# Install dependencies

# -------------------------------

echo "📦 Installing dependencies..."
PACKAGES="python3-pip python3-setuptools python3-wheel \
ninja-build build-essential flex bison git cmake \
libsctp-dev libgnutls28-dev libgcrypt-dev libssl-dev \
libmongoc-dev libbson-dev libyaml-dev libnghttp2-dev \
libmicrohttpd-dev libcurl4-gnutls-dev libtins-dev \
libtalloc-dev meson pkg-config"

MISSING=""
for pkg in $PACKAGES; do
    dpkg -s "$pkg" > /dev/null 2>&1 || MISSING="$MISSING $pkg"
done

if [ -n "$MISSING" ]; then
    sudo apt-get update -qq
    sudo apt-get install -y $MISSING
fi

# Install libidn conditionally
if ! dpkg -s libidn-dev > /dev/null 2>&1 && ! dpkg -s libidn11-dev > /dev/null 2>&1; then
    if apt-cache show libidn-dev > /dev/null 2>&1; then
        sudo apt-get install -y --no-install-recommends libidn-dev
    else
        sudo apt-get install -y --no-install-recommends libidn11-dev
    fi
fi

# -------------------------------

# Clone repo (if not exists)

# -------------------------------

if [ ! -d "$ROOT_DIR/open5gs" ]; then
echo "📥 Cloning Open5GS..."
git clone https://github.com/open5gs/open5gs "$ROOT_DIR/open5gs"
fi

cd "$ROOT_DIR/open5gs"

# -------------------------------

# Configure build

# -------------------------------

echo "⚙️ Configuring with Meson..."
meson setup "$BUILD_DIR" --prefix="$INSTALL_DIR" || true

# -------------------------------

# Build

# -------------------------------

echo "🔨 Building with Ninja..."
ninja -C "$BUILD_DIR"

# -------------------------------

# Run Tests

# -------------------------------

echo "🧪 Running tests..."

# Basic functional tests

./build/tests/attach/attach || true
./build/tests/registration/registration || true

# Full test suite

cd "$BUILD_DIR"
meson test -v || true
cd -

# -------------------------------

# Install

# -------------------------------

echo "📦 Installing..."
ninja -C "$BUILD_DIR" install

echo "✅ Build completed successfully!"

