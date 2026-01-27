#!/usr/bin/env bash
set -euo pipefail

# Vercel build script for Flutter Web.
# Installs Flutter SDK (cached in /tmp across steps) and builds to build/web.

FLUTTER_VERSION="3.19.6"  # stable-ish; adjust if needed
FLUTTER_DIR="$HOME/flutter"

if [ ! -d "$FLUTTER_DIR" ]; then
  echo "Installing Flutter SDK $FLUTTER_VERSION..."
  mkdir -p "$HOME"
  curl -L "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    | tar -xJ -C "$HOME"
else
  echo "Flutter SDK already present."
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

# Mark Flutter SDK directory as safe for git (Vercel often runs as root and
# Flutter uses git internally to report version information).
if command -v git >/dev/null 2>&1; then
  git config --global --add safe.directory "$FLUTTER_DIR" || true
fi

flutter --version

# Build from the Flutter project directory
cd sparelink-flutter

# Ensure dependencies
flutter pub get

# Build web
flutter build web --release

echo "Build complete: build/web"
