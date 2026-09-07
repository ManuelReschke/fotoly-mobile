import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoly_mobile/l10n/locale_controller.dart';
import 'package:fotoly_mobile/screens/register_screen.dart';
import 'package:fotoly_mobile/services/auth_service.dart';
import 'package:fotoly_mobile/services/pixelfox_api_client.dart';
import 'package:fotoly_mobile/services/storage.dart';
import 'package:provider/provider.dart';

import 'fake_api_http.dart';

void main() {
  AuthService authWith(FakeApiHttp fake) {
    return AuthService(
      secureStore: MemorySecureStore(),
      clientFactory: ({apiKey, accessToken}) => PixelfoxApiClient(
        apiKey: apiKey,
        accessToken: accessToken,
        httpClient: fake,
      ),
    );
  }

  Future<void> pumpRegister(WidgetTester tester, AuthService auth) async {
    final locale = LocaleController(prefs: MemoryPrefsStore());
    await locale.setLocale(AppLocale.en);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LocaleController>.value(value: locale),
          ChangeNotifierProvider<AuthService>.value(value: auth),
        ],
        child: const MaterialApp(home: RegisterScreen()),
      ),
    );
  }

  testWidgets('password mismatch does not POST', (tester) async {
    final fake = FakeApiHttp(
      registerStatus: 201,
      registerBody: '{"email":"a@b.c"}',
    );
    await pumpRegister(tester, authWith(fake));

    await tester.enterText(find.byType(TextField).at(0), 'pete');
    await tester.enterText(find.byType(TextField).at(1), 'pete@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'secret12');
    await tester.enterText(find.byType(TextField).at(3), 'other');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pump();

    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(fake.sent, isEmpty);
  });

  testWidgets('success replaces with check-email screen', (tester) async {
    final fake = FakeApiHttp(
      registerStatus: 201,
      registerBody:
          '{"email":"pete@example.com","message":"Registration successful. Please check your inbox for the activation link."}',
    );
    await pumpRegister(tester, authWith(fake));

    await tester.enterText(find.byType(TextField).at(0), 'pete');
    await tester.enterText(find.byType(TextField).at(1), 'pete@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'secret12');
    await tester.enterText(find.byType(TextField).at(3), 'secret12');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Check your email'), findsOneWidget);
    expect(find.textContaining('pete@example.com'), findsWidgets);
    expect(find.text('Create account'), findsNothing);
  });

  testWidgets('409 shows error inline and snackbar', (tester) async {
    final fake = FakeApiHttp(
      registerStatus: 409,
      registerBody:
          '{"error":"conflict","message":"Email is already registered"}',
    );
    await pumpRegister(tester, authWith(fake));

    await tester.enterText(find.byType(TextField).at(0), 'pete');
    await tester.enterText(find.byType(TextField).at(1), 'pete@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'secret12');
    await tester.enterText(find.byType(TextField).at(3), 'secret12');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Email is already registered'), findsWidgets);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Create account'), findsOneWidget);
    expect(find.text('Check your email'), findsNothing);
  });
}
