import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixelfox_mobile/l10n/locale_controller.dart';
import 'package:pixelfox_mobile/screens/login_screen.dart';
import 'package:pixelfox_mobile/services/auth_service.dart';
import 'package:pixelfox_mobile/services/pixelfox_api_client.dart';
import 'package:pixelfox_mobile/services/storage.dart';
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

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('Sign in with API key'), findsOneWidget);
    expect(find.text('API key'), findsNothing);

    await tester.tap(find.text('Sign in with API key'));
    await tester.pump();
    expect(find.text('API key'), findsOneWidget);
  });
}
