#!/usr/bin/env bash
# Builds the repro and reports what the icon tree shaker did.
set -euo pipefail
cd "$(dirname "$0")"
flutter pub get > /dev/null
flutter build web --release --tree-shake-icons 2>&1 | tee build.log

dir=build/web/assets/packages/icon_fonts/fonts
size() { [ -f "$1" ] && wc -c < "$1" | tr -d ' ' || echo absent; }

used=$(size "$dir/used.otf")
unused=$(size "$dir/unused.otf")

printf '\n%-6s %-34s %s\n' "FILE" "FAMILY" "BYTES"
printf '%-6s %-34s %s\n' "used" "packages/icon_fonts/UsedIcons" "$used"
printf '%-6s %-34s %s\n' "unused" "packages/icon_fonts/UnusedIcons" "$unused"

if grep -q 'UnusedIcons' build/web/assets/FontManifest.json; then
  printf '\nFontManifest still lists the unused family.\n'
else
  printf '\nFontManifest no longer lists the unused family.\n'
fi
