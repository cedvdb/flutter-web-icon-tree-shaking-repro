# Web: icon font families referenced only through a `@pragma('vm:entry-point')`
# method are not tree-shaken (Android shakes them)

Two cases, same Flutter version. The second one is the real-world shape.

## `material_symbols/` — the real-world case

`material_symbols_icons` declares three icon font families (Outlined, Rounded,
Sharp) and deliberately force-references one `IconData` from each inside a
method marked `@pragma('vm:entry-point')`, precisely so the icon tree shaker
sees them:

```dart
// package:material_symbols_icons/symbols.dart
@pragma('vm:entry-point')
static void forceCompileTimeTreeShaking() {
  var forceOutlinedTreeShake = const IconData(0xf88a,
      fontFamily: 'MaterialSymbolsOutlined', fontPackage: 'material_symbols_icons');
  var forceRoundedTreeShake  = const IconData(0xf88a,
      fontFamily: 'MaterialSymbolsRounded',  fontPackage: 'material_symbols_icons');
  var forceSharpTreeShake    = const IconData(0xf88a,
      fontFamily: 'MaterialSymbolsSharp',    fontPackage: 'material_symbols_icons');
}
```

The app uses one icon, from the Outlined family, and nothing else.

### Android — the pragma is honoured, all three are subset

```
flutter build apk --release

MaterialSymbolsSharp.ttf     8,841,308 → 2,380 bytes  (100.0% reduction)
MaterialSymbolsOutlined.ttf 10,643,396 → 3,916 bytes  (100.0% reduction)
MaterialSymbolsRounded.ttf  15,073,408 → 2,608 bytes  (100.0% reduction)

$ unzip -l build/app/outputs/flutter-apk/app-release.apk | grep symbols
   3916  assets/flutter_assets/.../MaterialSymbolsOutlined.ttf
   2608  assets/flutter_assets/.../MaterialSymbolsRounded.ttf
   2380  assets/flutter_assets/.../MaterialSymbolsSharp.ttf
```

### Web — only the used family is subset, the other two ship whole

```
flutter build web --release --tree-shake-icons

MaterialIcons-Regular.otf   1,645,184 → 1,004 bytes   (99.9% reduction)
MaterialSymbolsOutlined.ttf 10,643,396 → 3,760 bytes  (100.0% reduction)
                                    ← Rounded and Sharp never mentioned

$ ls -l build/web/assets/packages/material_symbols_icons/lib/fonts/
  MaterialSymbolsOutlined.ttf      3,760
  MaterialSymbolsRounded.ttf  15,073,408
  MaterialSymbolsSharp.ttf     8,841,308

$ python3 -c "import json; [print(f['family']) for f in json.load(open('build/web/assets/FontManifest.json'))]"
MaterialIcons
packages/material_symbols_icons/MaterialSymbolsOutlined
packages/material_symbols_icons/MaterialSymbolsRounded
packages/material_symbols_icons/MaterialSymbolsSharp
```

**23.4 MB of fonts nothing can render**, still listed in `FontManifest.json` —
and on web the engine downloads every family in that manifest at startup:

- `_engine/engine/initialization.dart:352` `_downloadAssetFonts()` calls
  `fontCollection.loadAssetFonts(await fetchFontManifest(...))`;
- `_engine/engine/skwasm/skwasm_impl/font_collection.dart:73` then loops
  `for (final FontFamily family in manifest.families)` and `Future.wait`s one
  `_downloadFontAsset` per `FontAsset`.

### Why this looks like a web bug, not a design question

The shaker only subsets families that appear in the const-`IconData` recording
(`icon_tree_shaker.dart`, `_getIconData`: `familyKeys` → `_parseFontJson(...)` →
loop over `fonts.entries`). Android evidently records the three forced
references; web does not. So the difference is in what the web compile records,
not in what the shaker decides — no "should we drop unused families" policy
change is implied.

## How I checked the two families are really not shaken

Five signals, all from the same clone:

1. **The flag ran in that build.** `MaterialSymbolsOutlined.ttf` is rewritten in
   it (10,643,396 → 3,760), as is `MaterialIcons-Regular.otf`.
2. **The tool logs one line per font it subsets**, and prints none for Rounded
   or Sharp.
3. **The shipped files are untouched.** `sha256` of
   `build/web/assets/packages/material_symbols_icons/lib/fonts/MaterialSymbolsRounded.ttf`
   and `...Sharp.ttf` equals the package's own files in `~/.pub-cache`.
4. **Control.** With `--no-tree-shake-icons` all three ship full and no line is
   printed, so the sizes above come from the shaker, not from a flag that never
   took effect.
5. **Same package, other target.** `flutter build apk --release` subsets the same
   two families to 2,608 and 2,380 bytes, so those files are subsettable — the
   web compile simply never records the pragma'd references.

## Workaround (tested)

Reference **one icon per family from the widget tree**; the shaker records the
family and subsets it to that glyph, and `Offstage` keeps it out of paint, layout,
hit-testing and semantics (`RenderOffstage.visitChildrenForSemantics` returns early).

```dart
Icon(Symbols.star),
Offstage(child: Icon(Symbols.star_rounded)),
Offstage(child: Icon(Symbols.star_sharp)),
```

```
Outlined  10,643,396 →  3,760
Rounded   15,073,408 →  5,192
Sharp      8,841,308 →  3,736
```

What does **not** work on web (both tested):

- calling the package's `Symbols.forceCompileTimeTreeShaking()` — its
  `const IconData`s are dead locals of a method nothing reads, so the web compiler
  drops them before the recording;
- drawing fewer families: every declared family that nothing references still
  ships whole, so using one family leaves the other two at 23.4 MB.

## `local_package/` — the self-contained case

Same symptom with no third-party code: a path package declares two icon font
families, the app references one, the unused one ships at full size on web and
is listed in `FontManifest.json`. The two `.otf` files are copies of the SDK's
own `MaterialIcons-Regular.otf`, so nothing beyond Flutter is redistributed.

```
cd local_package && ./check.sh

FILE   FAMILY                             BYTES
used   packages/icon_fonts/UsedIcons      1060
unused packages/icon_fonts/UnusedIcons    1645184

FontManifest still lists the unused family.
```

It ships whole on Android too — there is no pragma here, so nothing records a
use for the second family on either target:

```
$ flutter build apk --release
Font asset "used.otf" was tree-shaken, reducing it from 1645184 to 1040 bytes
                                    ← unused.otf never mentioned

$ unzip -l build/app/outputs/flutter-apk/app-release.apk | grep otf
  1645184  assets/flutter_assets/packages/icon_fonts/fonts/unused.otf
     1040  assets/flutter_assets/packages/icon_fonts/fonts/used.otf
```

So the base rule is target-independent: a declared icon family with no recorded
uses is copied verbatim and stays in `FontManifest.json`. What differs between
targets is whether a package can force a use — see the pragma case above, where
Android honours the forcing and web does not.

## Run it

```bash
cd material_symbols && flutter pub get
flutter build web --release --tree-shake-icons && ls -l build/web/assets/packages/material_symbols_icons/lib/fonts/
flutter build apk --release && unzip -l build/app/outputs/flutter-apk/app-release.apk | grep symbols
```

Flutter 3.50.1 (stable, ae9b586f34), Dart 3.14.0, macOS.
