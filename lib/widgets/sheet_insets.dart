import 'package:flutter/widgets.dart';

/// Bottom space a sheet must keep clear.
///
/// Uses the keyboard while it is open, otherwise the system navigation bar.
/// The larger of the two avoids stacking both gaps.
double sheetBottomInset(BuildContext context) {
  final media = MediaQuery.of(context);
  final keyboard = media.viewInsets.bottom;
  final systemNav = media.viewPadding.bottom;
  return keyboard > systemNav ? keyboard : systemNav;
}
