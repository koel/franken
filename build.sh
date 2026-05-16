#!/usr/bin/env bash
# Build a Koel + FrankenPHP standalone bundle for the current host platform.
#
# Output: build/koel-franken-<koel-version>-<platform>/{koel, frankenphp, koel/}
#
# Usage:
#   ./build.sh                 # auto-detect platform, use latest koel + frankenphp releases
#   KOEL_VERSION=v9.2.1 \
#   FRANKENPHP_VERSION=v1.12.2 \
#   PLATFORM=mac-arm64 \
#     ./build.sh

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
BUILD_ROOT="$HERE/build"
mkdir -p "$BUILD_ROOT"

# Inputs (env-overridable).
KOEL_VERSION="${KOEL_VERSION:-$(curl -sSL https://api.github.com/repos/koel/koel/releases/latest | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')}"
FRANKENPHP_VERSION="${FRANKENPHP_VERSION:-$(curl -sSL https://api.github.com/repos/php/frankenphp/releases/latest | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')}"

# Platform detection.
if [[ -z "${PLATFORM:-}" ]]; then
	case "$(uname -s)-$(uname -m)" in
		Darwin-arm64)        PLATFORM=mac-arm64 ;;
		Darwin-x86_64)       PLATFORM=mac-x86_64 ;;
		Linux-x86_64)        PLATFORM=linux-x86_64 ;;
		Linux-aarch64)       PLATFORM=linux-aarch64 ;;
		*) echo "[build] unsupported host $(uname -s)-$(uname -m); pass PLATFORM= explicitly" >&2; exit 2 ;;
	esac
fi

case "$PLATFORM" in
	mac-arm64)        FRANKENPHP_ASSET=frankenphp-mac-arm64 ;;
	mac-x86_64)       FRANKENPHP_ASSET=frankenphp-mac-x86_64 ;;
	linux-x86_64)     FRANKENPHP_ASSET=frankenphp-linux-x86_64 ;;
	linux-aarch64)    FRANKENPHP_ASSET=frankenphp-linux-aarch64 ;;
	*) echo "[build] unknown PLATFORM=$PLATFORM" >&2; exit 2 ;;
esac

BUNDLE_NAME="koel-franken-$KOEL_VERSION-$PLATFORM"
BUNDLE_DIR="$BUILD_ROOT/$BUNDLE_NAME"

echo "[build] koel=$KOEL_VERSION frankenphp=$FRANKENPHP_VERSION platform=$PLATFORM" >&2

rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR"

# Fetch FrankenPHP binary.
echo "[build] fetching FrankenPHP $FRANKENPHP_VERSION ($FRANKENPHP_ASSET)…" >&2
curl -sSL -o "$BUNDLE_DIR/frankenphp" \
	"https://github.com/php/frankenphp/releases/download/$FRANKENPHP_VERSION/$FRANKENPHP_ASSET"
chmod +x "$BUNDLE_DIR/frankenphp"

# Fetch koel release tarball + extract into bundle.
echo "[build] fetching koel $KOEL_VERSION…" >&2
KOEL_TARBALL="$BUILD_ROOT/koel-$KOEL_VERSION.tar.gz"
if [[ ! -f "$KOEL_TARBALL" ]]; then
	curl -sSL -o "$KOEL_TARBALL" \
		"https://github.com/koel/koel/releases/download/$KOEL_VERSION/koel-$KOEL_VERSION.tar.gz"
fi
tar -xzf "$KOEL_TARBALL" -C "$BUNDLE_DIR"

# Drop the launcher in.
cp "$HERE/koel" "$BUNDLE_DIR/koel"
chmod +x "$BUNDLE_DIR/koel"

echo "[build] done — bundle at $BUNDLE_DIR" >&2
echo "$BUNDLE_DIR"
