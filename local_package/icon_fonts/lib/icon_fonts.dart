import 'package:flutter/widgets.dart';

/// Referenced by the app, so its family has recorded uses and gets subset.
abstract final class UsedIcons {
  static const IconData home = IconData(
    0xe88a,
    fontFamily: 'UsedIcons',
    fontPackage: 'icon_fonts',
  );
}

/// Never referenced anywhere, so no recorded uses — yet its font still ships.
abstract final class UnusedIcons {
  static const IconData star = IconData(
    0xe838,
    fontFamily: 'UnusedIcons',
    fontPackage: 'icon_fonts',
  );
}
