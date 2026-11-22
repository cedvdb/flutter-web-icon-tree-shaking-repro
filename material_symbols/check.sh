#!/usr/bin/env bash
# Builds the Material Symbols repro for web and reports which families shipped whole.
set -euo pipefail
cd "$(dirname "$0")"
flutter pub get > /dev/null
flutter build web --release --tree-shake-icons 2>&1 | grep -E 'tree-shaken|Cannot tree shake' || true

dir=build/web/assets/packages/material_symbols_icons/lib/fonts
size() { [ -f "$1" ] && wc -c < "$1" | tr -d ' ' || echo absent; }

printf '\n%-26s %s\n' "FAMILY" "BYTES"
for n in Outlined Rounded Sharp; do
  printf '%-26s %s\n' "MaterialSymbols$n" "$(size "$dir/MaterialSymbols$n.ttf")"
done
printf '\nFontManifest families:\n'
python3 -c "import json; [print(' ', f['family']) for f in json.load(open('build/web/assets/FontManifest.json'))]"
