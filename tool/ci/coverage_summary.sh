#!/usr/bin/env bash
# Prints a Markdown coverage summary from an lcov file: the total, then every
# file under lib/, least covered first.
#
#   flutter test --coverage
#   tool/ci/coverage_summary.sh coverage/lcov.info
#
# CI appends this to the run's summary page.
set -euo pipefail

lcov="${1:-coverage/lcov.info}"
if [[ ! -f "$lcov" ]]; then
  echo "No coverage file at $lcov (run: flutter test --coverage)" >&2
  exit 1
fi

awk -F'[:,]' '
  # The Firebase options file is a CI placeholder, not app code.
  /^SF:/ { file = $2; skip = (file ~ /firebase_options\.dart$/) }
  /^LF:/ && !skip { found[file] = $2 }
  /^LH:/ && !skip { hit[file] = $2 }
  END {
    for (f in found) { tf += found[f]; th += hit[f] }
    printf "## Test coverage: %.1f%%\n\n", (tf ? 100 * th / tf : 0)
    printf "%d of %d lines in `lib/` are run by tests.\n\n", th, tf
    print "| Coverage | Lines | File |"
    print "|---:|---:|---|"
    for (f in found) {
      pct = found[f] ? 100 * hit[f] / found[f] : 100
      printf "%.1f%%\t%d/%d\t%s\n", pct, hit[f], found[f], f | "sort -n"
    }
    close("sort -n")
  }
' "$lcov" | awk -F'\t' 'NF == 3 { printf "| %s | %s | `%s` |\n", $1, $2, $3; next } { print }'
