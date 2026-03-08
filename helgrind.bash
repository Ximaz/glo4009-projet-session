#!/bin/bash

set -e

VALGRIND_VERSION="3.22.0"
INSTALL_DIR="$HOME/valgrind"
BUILD_DIR="$HOME/build_valgrind"

echo "============================="
echo "Helgrind / Valgrind Builder"
echo "============================="

# Detect architecture
ARCH=$(uname -m)
OS=$(uname -s)

echo "<OS détecté: $OS"
echo "Architecture détectée: $ARCH"

# Normalise architecture
case $ARCH in
    x86_64)
        ARCH="x86_64"
        ;;
    aarch64|arm64)
        ARCH="arm64"
        ;;
    *)
        echo "Architecture non supportée: $ARCH"
        exit 1
        ;;
esac

echo "Utilise l'architecture: $ARCH"

# Install dependences si c'est Linux
if [ "$OS" = "Linux" ]; then
    echo "Installation dépendances..."

    if command -v apt >/dev/null; then
        sudo apt update
        sudo apt install -y \
            build-essential \
            automake \
            autoconf \
            libtool \
            pkg-config \
            git
    fi
fi

# Création répertoires
mkdir -p $BUILD_DIR
cd $BUILD_DIR

# Télécharge source
if [ ! -d "valgrind" ]; then
    echo "Clonage dépot Valgrind..."
    git clone https://sourceware.org/git/valgrind.git
fi

cd valgrind

echo "Checking out stable version..."
git checkout VALGRIND_${VALGRIND_VERSION//./_}

echo "Generation build configuration..."
./autogen.sh

echo "Configuration build..."
./configure --prefix=$INSTALL_DIR

echo "Compilation Valgrind..."

CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu)
make -j$CORES

echo "Installation binaires..."
make install

echo "Compilation fini."

echo "Test Helgrind..."

$INSTALL_DIR/bin/valgrind --tool=helgrind --version

echo "Helgrind bien installer dans:"
echo "$INSTALL_DIR/bin"
