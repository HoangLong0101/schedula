import 'package:flutter/widgets.dart';

abstract final class ShellLayout {
  static const navigationHeight = 84.0;
  static const _contentClearance = 28.0;

  static double bottomContentPadding(BuildContext context) =>
      navigationHeight +
      _contentClearance +
      MediaQuery.viewPaddingOf(context).bottom;
}
