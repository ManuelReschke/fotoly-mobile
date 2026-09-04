import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixelfox_mobile/services/oauth_browser.dart';

void main() {
  test('openOAuthSession returns the matching callback URI', () async {
    final links = StreamController<Uri>.broadcast();
    addTearDown(links.close);

    final future = openOAuthSession(
      authorizationUrl: Uri.parse('https://pixelfox.cc/api/v1/auth/google/start'),
      callbackUrlScheme: 'pixelfox',
      launchUrl: (url) async {
        expect(url.host, 'pixelfox.cc');
        return true;
      },
      incomingLinks: links.stream,
    );

    await Future<void>.delayed(Duration.zero);
    links.add(Uri.parse('https://example.com/ignore'));
    links.add(Uri.parse('pixelfox://auth/callback?code=abc'));

    final result = await future;
    expect(result.queryParameters['code'], 'abc');
  });

  test('openOAuthSession fails when the browser does not launch', () async {
    expect(
      () => openOAuthSession(
        authorizationUrl: Uri.parse('https://pixelfox.cc/login'),
        callbackUrlScheme: 'pixelfox',
        launchUrl: (_) async => false,
        incomingLinks: const Stream.empty(),
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Could not open the login browser'),
        ),
      ),
    );
  });
}
