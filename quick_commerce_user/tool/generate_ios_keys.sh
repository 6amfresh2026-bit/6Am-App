#!/usr/bin/env bash
# Generates ios/Flutter/Keys.xcconfig from config/keys.env.
#
# Xcode cannot read a .env file, but xcconfig syntax is `KEY = VALUE`, so this
# translates one into the other. Run it after changing config/keys.env; the
# Xcode build also runs it via a pre-action so a stale file cannot ship.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/config/keys.env"
OUT="$ROOT/ios/Flutter/Keys.xcconfig"

if [ ! -f "$SRC" ]; then
  echo "error: $SRC not found. Copy config/keys.example.env to config/keys.env." >&2
  exit 1
fi

{
  echo "// GENERATED FILE — do not edit."
  echo "// Source: config/keys.env — run tool/generate_ios_keys.sh to regenerate."
  # Skip comments and blank lines; pad `=` into ` = ` for xcconfig.
  grep -vE '^\s*(#|$)' "$SRC" | sed -E 's/^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/\1 = \2/'
} > "$OUT"

echo "wrote $OUT"
