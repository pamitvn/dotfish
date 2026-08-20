#!/bin/sh
# install.sh — the Install shim: one-command bootstrap for a fresh machine.
#
# Detects OS/arch, downloads the matching prebuilt Installer binary from GitHub
# Releases, installs it to a local bin dir (so `dotfish upgrade` works
# later), and runs it. It transfers ONLY the Installer binary — never a
# clone of the Build source (the config payload travels inside the binary).
# See docs/adr/0003.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/anpmts/dotfiles-fish/main/shim/install.sh | sh
#
# Pass Installer arguments after `-s --`, e.g. install every Module:
#   curl -fsSL .../shim/install.sh | sh -s -- --all
#
# Overrides: DOTFILES_REPO=owner/repo  DOTFILES_VERSION=v1.2.3
#            DOTFILES_BIN_DIR=/path    (default ~/.local/bin)
set -eu

REPO="${DOTFILES_REPO:-anpmts/dotfiles-fish}"
BIN="dotfish"
BIN_DIR="${DOTFILES_BIN_DIR:-$HOME/.local/bin}"

os=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$os" in
    linux | darwin) ;;
    *) echo "✗ unsupported OS: $os" >&2; exit 1 ;;
esac

arch=$(uname -m)
case "$arch" in
    x86_64 | amd64) arch=amd64 ;;
    aarch64 | arm64) arch=arm64 ;;
    *) echo "✗ unsupported architecture: $arch" >&2; exit 1 ;;
esac

ver="${DOTFILES_VERSION:-latest}"
if [ "$ver" = latest ]; then
    url="https://github.com/$REPO/releases/latest/download/${BIN}_${os}_${arch}"
else
    url="https://github.com/$REPO/releases/download/${ver}/${BIN}_${os}_${arch}"
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "→ downloading $BIN ($os/$arch)"
if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$tmp/$BIN"
elif command -v wget >/dev/null 2>&1; then
    wget -qO "$tmp/$BIN" "$url"
else
    echo "✗ need curl or wget to download the Installer" >&2
    exit 1
fi

chmod +x "$tmp/$BIN"
mkdir -p "$BIN_DIR"
mv "$tmp/$BIN" "$BIN_DIR/$BIN"
echo "✓ installed $BIN -> $BIN_DIR/$BIN"

# Core puts ~/.local/bin on fish's PATH; warn for other shells / custom dirs.
case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) echo "⚠ $BIN_DIR is not on this shell's PATH — add it to run '$BIN upgrade' later" >&2 ;;
esac

exec "$BIN_DIR/$BIN" "$@"
