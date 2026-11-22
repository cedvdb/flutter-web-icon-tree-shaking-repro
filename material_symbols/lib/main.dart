import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

void main() {
  runApp(
    // One icon, from the Outlined family. Nothing references the Rounded or
    // Sharp families, whose fonts the package still declares (and force-
    // references from Symbols.forceCompileTimeTreeShaking).
    const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: Icon(Symbols.star)),
    ),
  );
}
