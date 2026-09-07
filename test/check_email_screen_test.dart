import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoly_mobile/l10n/locale_controller.dart';
import 'package:fotoly_mobile/screens/check_email_screen.dart';
import 'package:fotoly_mobile/services/storage.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('shows email and pops on back to login', (tester) async {
    final locale = LocaleController(prefs: MemoryPrefsStore());
    await locale.setLocale(AppLocale.en);

    await tester.pumpWidget(
      ChangeNotifierProvider<LocaleController>.value(
        value: locale,
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CheckEmailScreen(
                      email: 'pete@example.com',
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Check your email'), findsOneWidget);
    expect(find.textContaining('pete@example.com'), findsWidgets);
    await tester.tap(find.text('Back to login'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(find.text('Check your email'), findsNothing);
  });
}
