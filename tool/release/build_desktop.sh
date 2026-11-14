#!/usr/bin/env bash
# Builds the desktop app for this runner's OS and packages it into dist/:
#   macos   -> decant-<version>-macos.zip     (Decant.app, unsigned)
#   linux   -> decant-<version>-linux-x64.tar.gz
#   windows -> decant-<version>-windows-x64.zip
# The desktop app is the plain offline game (no Firebase, ads or sign-in),
# so it needs no secrets; lib/firebase_options.dart may be the CI stub.
set -euo pipefail

platform="${1:?usage: build_desktop.sh macos|linux|windows}"
name="$(tool/release/pubspec_version.sh name)"
base="decant-$name"
mkdir -p dist

case "$platform" in
  macos)
    flutter build macos --release
    ditto -c -k --sequesterRsrc --keepParent \
      build/macos/Build/Products/Release/Decant.app "dist/$base-macos.zip"
    ;;
  linux)
    flutter build linux --release
    tar -czf "dist/$base-linux-x64.tar.gz" \
      -C build/linux/x64/release bundle --transform "s/^bundle/decant/"
    ;;
  windows)
    flutter build windows --release
    (cd build/windows/x64/runner/Release && 7z a -tzip -bso0 \
      "../../../../../dist/$base-windows-x64.zip" .)
    ;;
  *)
    echo "unknown platform: $platform" >&2
    exit 2
    ;;
esac
ls -l dist
