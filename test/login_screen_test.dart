import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoly_mobile/l10n/locale_controller.dart';
import 'package:fotoly_mobile/screens/login_screen.dart';
import 'package:fotoly_mobile/services/auth_service.dart';
import 'package:fotoly_mobile/services/pixelfox_api_client.dart';
import 'package:fotoly_mobile/services/storage.dart';
import 'package:provider/provider.dart';

import 'fake_api_http.dart';

void main() {
  testWidgets('login screen shows email, password and advanced API key', (
    tester,
  ) async {
    final locale = LocaleController(prefs: MemoryPrefsStore());
    await locale.setLocale(AppLocale.en);
    final auth = AuthService(
      secureStore: MemorySecureStore(),
      clientFactory: ({apiKey, accessToken}) => PixelfoxApiClient(
        apiKey: apiKey,
        accessToken: accessToken,
        httpClient: FakeApiHttp(
          providersBody: '{"providers":[{"id":"google","name":"Google"}]}',
        ),
      ),
    );
    await auth.loadProviders();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LocaleController>.value(value: locale),
          ChangeNotifierProvider<AuthService>.value(value: auth),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    expect(find.text('FOTOLY.EU'), findsOneWidget);
    expect(find.text('PIXELFOX.CC'), findsNothing);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('No account yet? Register'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('Sign in with API key'), findsOneWidget);
    expect(find.text('API key'), findsNothing);

    final advancedApiKey = find.text('Sign in with API key');
    await tester.ensureVisible(advancedApiKey);
    await tester.pumpAndSettle();
    await tester.tap(advancedApiKey);
    await tester.pump();
    expect(find.text('API key'), findsOneWidget);
  });

  testWidgets('register link opens register screen', (tester) async {
    final locale = LocaleController(prefs: MemoryPrefsStore());
    await locale.setLocale(AppLocale.en);
    final auth = AuthService(
      secureStore: MemorySecureStore(),
      clientFactory: ({apiKey, accessToken}) => PixelfoxApiClient(
        apiKey: apiKey,
        accessToken: accessToken,
        httpClient: FakeApiHttp(),
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LocaleController>.value(value: locale),
          ChangeNotifierProvider<AuthService>.value(value: auth),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.tap(find.text('No account yet? Register'));
    await tester.pumpAndSettle();
    expect(find.text('Create account'), findsWidgets);
    expect(find.text('Username'), findsOneWidget);
  });
}
