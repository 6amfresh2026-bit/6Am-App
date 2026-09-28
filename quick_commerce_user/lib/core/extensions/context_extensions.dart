import 'package:flutter/material.dart';

extension MediaQueryX on BuildContext {
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;
  EdgeInsets get viewPadding => MediaQuery.viewPaddingOf(this);
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Column count for product grids — keeps tablets from stretching cards.
  int get productGridColumns {
    final w = screenWidth;
    if (w >= 900) return 5;
    if (w >= 640) return 4;
    if (w >= 380) return 3;
    return 2;
  }
}
