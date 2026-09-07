import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fotoly_mobile/config/app_brand.dart';
import 'package:fotoly_mobile/services/auth_service.dart';
import 'package:fotoly_mobile/services/pixelfox_api_client.dart';
import 'package:fotoly_mobile/services/storage.dart';

import 'fake_api_http.dart';

void main() {
  late String profileFixture;
  late String sessionFixture;

  setUpAll(() {
    profileFixture = File(
      'test/fixtures/profile_success.json',
    ).readAsStringSync();
    sessionFixture = File(
      'test/fixtures/auth_session.json',
    ).readAsStringSync();
  });

  ApiClientFactory factoryFor(FakeApiHttp fake) {
    return ({apiKey, accessToken}) => PixelfoxApiClient(
      apiKey: apiKey,
      accessToken: accessToken,
      httpClient: fake,
    );
  }

  test('loginWithApiKey persists key after successful profile', () async {
    final store = MemorySecureStore();
    final fake = FakeApiHttp(profileStatus: 200, profileBody: profileFixture);

    final auth = AuthService(
      secureStore: store,
      clientFactory: ({apiKey, accessToken}) => PixelfoxApiClient(
        apiKey: apiKey,
        accessToken: accessToken,
        httpClient: fake,
      ),
    );

    final ok = await auth.loginWithApiKey('  my-api-key  ');
    expect(ok, isTrue);
    expect(auth.isAuthenticated, isTrue);
    expect(auth.profile?.username, 'pixelpete');
    expect(auth.apiKey, 'my-api-key');
    expect(await store.read(kApiKeyStorageKey), 'my-api-key');
  });

  test('loginWithApiKey rejects invalid key and does not persist', () async {
    final store = MemorySecureStore();
    final fake = FakeApiHttp(
      profileStatus: 401,
      profileBody: '{"error":"nope"}',
    );

    final auth = AuthService(
      secureStore: store,
      clientFactory: ({apiKey, accessToken}) => PixelfoxApiClient(
        apiKey: apiKey,
        accessToken: accessToken,
        httpClient: fake,
      ),
    );

    final ok = await auth.loginWithApiKey('bad');
    expect(ok, isFalse);
    expect(auth.isAuthenticated, isFalse);
    expect(auth.error, contains('Invalid API key'));
    expect(await store.read(kApiKeyStorageKey), isNull);
  });

  test('bootstrap restores stored key via profile validation', () async {
    final store = MemorySecureStore();
    await store.write(kApiKeyStorageKey, 'stored-key');
    final fake = FakeApiHttp(profileStatus: 200, profileBody: profileFixture);

    final auth = AuthService(
      secureStore: store,
      clientFactory: ({apiKey, accessToken}) => PixelfoxApiClient(
        apiKey: apiKey,
        accessToken: accessToken,
        httpClient: fake,
      ),
    );

    await auth.bootstrap();
    expect(auth.isAuthenticated, isTrue);
    expect(auth.profile?.id, 42);
  });

  test('loginWithPassword stores app session token', () async {
    final store = MemorySecureStore();
    final fake = FakeApiHttp(loginStatus: 200, loginBody: sessionFixture);
    final auth = AuthService(secureStore: store, clientFactory: factoryFor(fake));

    final ok = await auth.loginWithPassword('pete@example.com', 'secret12');
    expect(ok, isTrue);
    expect(auth.isAuthenticated, isTrue);
    expect(auth.accessToken, 'pxls_testtoken');
    expect(auth.apiKey, isNull);
    expect(await store.read(kAccessTokenStorageKey), 'pxls_testtoken');
    expect(await store.read(kApiKeyStorageKey), isNull);
  });

  test('loginWithProvider exchanges callback code', () async {
    final store = MemorySecureStore();
    final fake = FakeApiHttp(tokenStatus: 200, tokenBody: sessionFixture);
    final auth = AuthService(
      secureStore: store,
      clientFactory: factoryFor(fake),
      openAuthSession: (url, scheme) async {
        expect(url.path, contains('/auth/google/start'));
        expect(
          url.queryParameters['redirect_uri'],
          AppBrand.current.appRedirectUri,
        );
        expect(scheme, AppBrand.current.callbackUrlScheme);
        return Uri.parse('${AppBrand.current.appRedirectUri}?code=abc');
      },
    );

    final ok = await auth.loginWithProvider('google');
    expect(ok, isTrue);
    expect(auth.accessToken, 'pxls_testtoken');
    expect(auth.profile?.username, 'pixelpete');
  });

  test('register succeeds without persisting a session', () async {
    final store = MemorySecureStore();
    final fake = FakeApiHttp(
      registerStatus: 201,
      registerBody:
          '{"email":"pete@example.com","message":"Registration successful. Please check your inbox for the activation link."}',
    );
    final auth = AuthService(secureStore: store, clientFactory: factoryFor(fake));

    final ok = await auth.register(
      username: 'pete',
      email: 'pete@example.com',
      password: 'secret12',
    );

    expect(ok, isTrue);
    expect(auth.isAuthenticated, isFalse);
    expect(auth.accessToken, isNull);
    expect(auth.apiKey, isNull);
    expect(await store.read(kAccessTokenStorageKey), isNull);
    expect(auth.error, isNull);
  });

  test('register sets error on 409 and does not persist', () async {
    final store = MemorySecureStore();
    final fake = FakeApiHttp(
      registerStatus: 409,
      registerBody:
          '{"error":"conflict","message":"Email is already registered"}',
    );
    final auth = AuthService(secureStore: store, clientFactory: factoryFor(fake));

    final ok = await auth.register(
      username: 'pete',
      email: 'pete@example.com',
      password: 'secret12',
    );

    expect(ok, isFalse);
    expect(auth.error, 'Email is already registered');
    expect(auth.isAuthenticated, isFalse);
    expect(await store.read(kAccessTokenStorageKey), isNull);
  });
}
