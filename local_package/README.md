# Unused icon font family is neither tree-shaken nor dropped

A package declares two icon font families. The app references exactly one of
them, with a `const IconData`, and builds for web in release mode with
`--tree-shake-icons`.

## Expected

- `packages/icon_fonts/UsedIcons` is subset to the one glyph the app uses.
- `packages/icon_fonts/UnusedIcons` is **not** in the bundle and **not** in
  `FontManifest.json`, because nothing can render it (see "Why dropping is safe").

## Actual (Flutter 3.50.1 / Dart 3.14.0)

```
$ flutter build web --release --tree-shake-icons
Font asset "used.otf" was tree-shaken, reducing it from 1645184 to 1060 bytes (99.9% reduction).
```

`unused.otf` is never mentioned, yet it ships in full:

```
build/web/assets/packages/icon_fonts/fonts/
   used.otf        1,060 bytes     <- subset
   unused.otf  1,645,184 bytes     <- untouched
```

```json
[
  {"family": "MaterialIcons", "fonts": [{"asset": "fonts/MaterialIcons-Regular.otf"}]},
  {"family": "packages/icon_fonts/UsedIcons",   "fonts": [{"asset": "packages/icon_fonts/fonts/used.otf"}]},
  {"family": "packages/icon_fonts/UnusedIcons", "fonts": [{"asset": "packages/icon_fonts/fonts/unused.otf"}]}
]
```

## Why it also costs a download

On web the engine loads every family in `FontManifest` at startup, whether or
not anything uses it:

- `flutter_web_sdk/lib/_engine/engine/initialization.dart:352` `_downloadAssetFonts()`
  calls `fontCollection.loadAssetFonts(await fetchFontManifest(...))`;
- `_engine/engine/skwasm/skwasm_impl/font_collection.dart:73` then iterates
  `for (final FontFamily family in manifest.families)` and downloads every
  `FontAsset` with `Future.wait(fontFutures)`.

So the unused family is a full download on first paint, on every target's
bundle size (APK/IPA included).

## Why dropping is safe for icon families

The shaker already fails the build when any `IconData` is non-constant
(`icon_tree_shaker.dart`, "This application cannot tree shake icons fonts. It
has non-constant instances of IconData."). Given a successful build, no
`IconData` can be created at runtime, so a family with **zero** recorded uses
cannot be rendered through an `Icon` widget.

(A family can still be used as a *text* font by name, which is why a blanket
"drop every family with no recorded uses" is not obviously safe - see the issue
for the options. This repro only claims the icon case.)

## Run it

```bash
flutter pub get
flutter build web --release --tree-shake-icons
ls -l build/web/assets/packages/icon_fonts/fonts/
cat build/web/assets/FontManifest.json
```

The two `.otf` files are copies of the Flutter SDK's own
`MaterialIcons-Regular.otf` (`bin/cache/artifacts/material_fonts`), so this
repro redistributes nothing beyond what ships with Flutter.
