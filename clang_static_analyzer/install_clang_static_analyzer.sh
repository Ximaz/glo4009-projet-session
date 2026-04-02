#!/usr/bin/env bash
set -e

echo "=================================="
echo "Clang Static Analyzer Setup"
echo "=================================="

ARCH="$(uname -m)"
OS="$(uname -s)"

echo "OS détecté: $OS"
echo "Architecture détectée: $ARCH"

case "$ARCH" in
    x86_64|amd64)
        ARCH="x86_64"
        ;;
    arm64|aarch64)
        ARCH="arm64"
        ;;
    *)
        echo "Architecture non supportée: $ARCH"
        exit 1
        ;;
esac

echo "Architecture utilisée: $ARCH"

if [[ "$OS" == "Linux" ]]; then
    if command -v apt >/dev/null 2>&1; then
        echo "Installation via apt..."
        sudo apt update
        sudo apt install -y clang llvm clang-tools
    elif command -v dnf >/dev/null 2>&1; then
        echo "Installation via dnf..."
        sudo dnf install -y clang llvm clang-tools-extra
    elif command -v yum >/dev/null 2>&1; then
        echo "Installation via yum..."
        sudo yum install -y clang llvm
    elif command -v pacman >/dev/null 2>&1; then
        echo "Installation via pacman..."
        sudo pacman -S clang llvm llvm-libs --noconfirm
    else
        echo "Gestionnaire de paquets Linux non supporté automatiquement."
        exit 1
    fi
elif [[ "$OS" == "Darwin" ]]; then
    if command -v brew >/dev/null 2>&1; then
        echo "Installation via Homebrew..."
        brew install llvm
        echo "Ajoute ceci à ton shell si nécessaire:"
        echo 'export PATH="/opt/homebrew/opt/llvm/bin:$PATH"'
        echo 'export PATH="/usr/local/opt/llvm/bin:$PATH"'
    else
        echo "Homebrew n'est pas installé."
        exit 1
    fi
else
    echo "OS non supporté: $OS"
    exit 1
fi

echo "Validation des outils..."
if command -v clang >/dev/null 2>&1; then
    clang --version
else
    echo "clang non trouvé dans PATH"
    exit 1
fi

if command -v scan-build >/dev/null 2>&1; then
    scan-build --version || true
else
    echo "scan-build non trouvé dans PATH (optionnel mais recommandé)."
fi

echo "Installation terminée."