# Ready-to-paste bug report

Open https://github.com/flutter/flutter/issues/new?template=02_bug.yml and paste each
section below into the field named above it.

---

## TITLE

```
Web: 23 MB of unused icon fonts are shipped and fetched at startup (Android subsets them)
```

## STEPS TO REPRODUCE

```
1. git clone https://github.com/cedvdb/flutter-web-icon-tree-shaking-repro
   cd flutter-web-icon-tree-shaking-repro/material_symbols
2. flutter pub get
3. flutter build web --release --tree-shake-icons
4. ls -l build/web/assets/packages/material_symbols_icons/lib/fonts/
5. cat build/web/assets/FontManifest.json
```

The app draws one icon, `Icon(Symbols.star)`, which uses one of the three icon font
families the package declares.

## EXPECTED RESULTS

```
Only the family the app draws is worth shipping. The other two should be subset to a
few KB — as they are in the Android build of the same project — or left out entirely,
and should not be listed in FontManifest.json.
```

## ACTUAL RESULTS

```
MaterialSymbolsOutlined.ttf   10,643,396 -> 3,760        (the family used)
MaterialSymbolsRounded.ttf    15,073,408 -> 15,073,408   (unchanged)
MaterialSymbolsSharp.ttf       8,841,308 ->  8,841,308   (unchanged)

All three are still listed in build/web/assets/FontManifest.json, and on web the
engine downloads every family in that manifest at startup
(_engine/engine/initialization.dart -> _downloadAssetFonts() ->
loadAssetFonts(fetchFontManifest(...)); the skwasm implementation downloads every
FontAsset of every family). So 23.4 MB of icons the app can never draw is fetched on
first paint, and it is in the bundle besides.

flutter build apk --release of the same project subsets all three families to 2-4 KB.
The difference: the package keeps a reference to each family inside a
@pragma('vm:entry-point') method that the app never calls
(Symbols.forceCompileTimeTreeShaking), so the shaker can see them. Android's
recording honours those references; the web one does not.

That it really is the shaking and not a flag that silently did nothing:
- the same web build does rewrite the used font (10.6 MB -> 3.7 KB) and MaterialIcons;
- the tool prints one "Font asset ... was tree-shaken" line per font it subsets and
  prints none for the other two;
- the two shipped files are byte-identical (sha256) to the package's own files;
- with --no-tree-shake-icons all three ship full and no line is printed;
- Android subsets those same two families from the same package.
```

## CODE SAMPLE

````
```dart
import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

void main() {
  runApp(const Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: Icon(Symbols.star)), // Outlined family only
  ));
}
```

Full project: https://github.com/cedvdb/flutter-web-icon-tree-shaking-repro
It also has a package-free variant (local_package/) that shows the same shipping
behaviour with no third-party code.
````

## SCREENSHOTS OR VIDEO

```
N/A
```

## LOGS

````
```console
$ flutter build web --release --tree-shake-icons
Font asset "MaterialIcons-Regular.otf" was tree-shaken, reducing it from 1645184 to 1004 bytes (99.9% reduction).
Font asset "MaterialSymbolsOutlined.ttf" was tree-shaken, reducing it from 10643396 to 3760 bytes (100.0% reduction).
Built build/web

$ flutter build apk --release
Font asset "MaterialSymbolsSharp.ttf" was tree-shaken, reducing it from 8841308 to 2380 bytes (100.0% reduction).
Font asset "MaterialSymbolsOutlined.ttf" was tree-shaken, reducing it from 10643396 to 3916 bytes (100.0% reduction).
Font asset "MaterialSymbolsRounded.ttf" was tree-shaken, reducing it from 15073408 to 2608 bytes (100.0% reduction).
```
````

## FLUTTER DOCTOR OUTPUT

````
```console
[✓] Flutter (Channel stable, 3.50.1, on macOS 27.0 26A428 darwin-arm64, locale en-US)
    • Flutter version 3.50.1 on channel stable at /Users/cedvdb/tools/flutter
    • Framework revision ae9b586f34 (2026-11-18 17:01:07 -0800)
    • Engine revision 4d35714800
    • Dart version 3.14.0
    • DevTools version 2.61.0
[✓] Android toolchain - develop for Android devices (Android SDK version 36.1.0)
[✓] Xcode - develop for iOS and macOS (Xcode 27.0)
```
````
