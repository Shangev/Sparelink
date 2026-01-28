#!/usr/bin/env bash
set -euo pipefail

# Vercel build script for Flutter Web.
# Installs Flutter SDK and builds to build/web.

# Flutter 3.22.x ships with Dart >= 3.4 which is required by recent firebase_*_web packages.
FLUTTER_VERSION="3.22.3"
# Use a versioned directory so upgrades don't accidentally reuse an older cached SDK.
FLUTTER_DIR="$HOME/flutter-$FLUTTER_VERSION"

if [ ! -d "$FLUTTER_DIR" ]; then
  echo "Installing Flutter SDK $FLUTTER_VERSION..."
  mkdir -p "$HOME"
  curl -L "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    | tar -xJ -C "$HOME"
  # The archive extracts to $HOME/flutter, move it into our versioned directory.
  if [ -d "$HOME/flutter" ] && [ "$HOME/flutter" != "$FLUTTER_DIR" ]; then
    rm -rf "$FLUTTER_DIR"
    mv "$HOME/flutter" "$FLUTTER_DIR"
  fi
else
  echo "Flutter SDK already present."
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

# Make builds non-interactive/CI friendly
export CI=1
export FLUTTER_SUPPRESS_ANALYTICS=true
export DART_SUPPRESS_ANALYTICS=true

# Ensure pub cache is writable and consistent
export PUB_CACHE="${PUB_CACHE:-$HOME/.pub-cache}"
mkdir -p "$PUB_CACHE"

# Mark directories as safe for git.
# Vercel sometimes executes builds with different users/ownership which can trip
# git's "dubious ownership" protection (used by Flutter internally).
if command -v git >/dev/null 2>&1; then
  git config --global --add safe.directory "$FLUTTER_DIR" || true
  git config --global --add safe.directory "$PWD" || true
fi

flutter --version

# Ensure dependencies
flutter pub get

# Build web
flutter build web --release

echo "Build complete: build/web"
