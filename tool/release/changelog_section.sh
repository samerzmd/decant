#!/usr/bin/env bash
# Prints the CHANGELOG.md section for a version, without its heading.
# Fails when the section is missing or empty, so a release can't ship
# without notes.
#
#   tool/release/changelog_section.sh 1.3.0
set -euo pipefail

version="${1:?usage: changelog_section.sh <version>}"
file="${2:-CHANGELOG.md}"

notes="$(awk -v v="$version" '
  /^## \[/ {
    if (found) exit
    if (index($0, "## [" v "]") == 1) { found = 1; next }
  }
  found { print }
' "$file" | sed -e '/./,$!d')"

# Drop trailing blank lines.
notes="$(printf '%s\n' "$notes" | sed -e ':a' -e '/^\n*$/{$d;N;ba' -e '}')"

if [[ -z "${notes//[[:space:]]/}" ]]; then
  echo "error: $file has no notes for version $version." >&2
  echo "Add a '## [$version] — YYYY-MM-DD' section before releasing." >&2
  exit 1
fi
printf '%s\n' "$notes"
