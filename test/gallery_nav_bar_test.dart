import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoly_mobile/l10n/locale_controller.dart';
import 'package:fotoly_mobile/services/storage.dart';
import 'package:fotoly_mobile/widgets/gallery_nav_bar.dart';
import 'package:provider/provider.dart';

Future<void> pumpL10n(
  WidgetTester tester,
  Widget child, {
  AppLocale locale = AppLocale.en,
}) async {
  final controller = LocaleController(prefs: MemoryPrefsStore());
  await controller.setLocale(locale);
  await tester.pumpWidget(
    ChangeNotifierProvider<LocaleController>.value(
      value: controller,
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
}

void main() {
  testWidgets('nav destinations are localized', (tester) async {
    await pumpL10n(tester, GalleryNavBar(index: 0, onChanged: (_) {}));
    expect(find.text('Backup'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
  });
}
