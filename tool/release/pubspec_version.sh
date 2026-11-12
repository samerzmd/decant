#!/usr/bin/env bash
# Prints the app version from pubspec.yaml. With "name" (the default) it is
# the version name, like 1.3.0; with "code" it is the build number, like 2.
set -euo pipefail

part="${1:-name}"
full="$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | tr -d '[:space:]')"
case "$part" in
  name) printf '%s\n' "${full%%+*}" ;;
  code) printf '%s\n' "${full##*+}" ;;
  *) echo "usage: pubspec_version.sh [name|code]" >&2; exit 2 ;;
esac
