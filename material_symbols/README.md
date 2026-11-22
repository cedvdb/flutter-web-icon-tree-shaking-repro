# material_symbols case

The real-world shape: an app whose only icon is `Symbols.star`, with
`material_symbols_icons` pinned in `pubspec.lock`.

- **Android** shakes all three families (~2–4 KB each) — the package's
  `@pragma('vm:entry-point')` forcing is honoured.
- **Web** shakes only the used family; Rounded (15 MB) and Sharp (8.8 MB) ship
  whole and stay in `FontManifest.json`, so the engine downloads them at startup.

See the [root README](../README.md) for the full output, and run `./check.sh`.
