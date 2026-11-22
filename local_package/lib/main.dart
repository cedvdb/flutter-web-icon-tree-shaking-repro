import 'package:flutter/widgets.dart';
import 'package:icon_fonts/icon_fonts.dart';

void main() {
  runApp(
    const Directionality(
      textDirection: TextDirection.ltr,
      // The only icon in the app: from the UsedIcons family.
      child: Center(child: Icon(UsedIcons.home)),
    ),
  );
}
