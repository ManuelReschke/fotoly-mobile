import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'app_strings.dart';
import 'locale_controller.dart';

/// Shortcut: `context.l10n` → current [AppStrings].
extension L10nContext on BuildContext {
  AppStrings get l10n => watch<LocaleController>().strings;

  AppStrings get l10nRead => read<LocaleController>().strings;

  LocaleController get localeController => read<LocaleController>();
}
