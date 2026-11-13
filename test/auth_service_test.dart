import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fotoly_mobile/config/app_brand.dart';
import 'package:fotoly_mobile/services/auth_service.dart';
import 'package:fotoly_mobile/services/pixelfox_api_client.dart';
import 'package:fotoly_mobile/services/storage.dart';
import 'package:http/http.dart' as http;

import 'fake_api_http.dart';

void main() {
  late String profileFixture;
  late String sessionFixture;

  setUpAll(() {
    profileFixture = File(
      'test/fixtures/profile_success.json',
    ).readAsStringSync();
    sessionFixture = File('test/fixtures/auth_session.json').readAsStringSync();
  });

  ApiClientFactory factoryFor(ApiHttp fake) {
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
    final auth = AuthService(
      secureStore: store,
      clientFactory: factoryFor(fake),
    );

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
    final auth = AuthService(
      secureStore: store,
      clientFactory: factoryFor(fake),
    );

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
    final auth = AuthService(
      secureStore: store,
      clientFactory: factoryFor(fake),
    );

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

  test('bootstrap opens offline with the cached profile', () async {
    final secure = MemorySecureStore();
    final prefs = MemoryPrefsStore();
    final online = FakeApiHttp(loginStatus: 200, loginBody: sessionFixture);
    final signedIn = AuthService(
      secureStore: secure,
      prefs: prefs,
      clientFactory: factoryFor(online),
    );
    expect(
      await signedIn.loginWithPassword('pete@example.com', 'secret12'),
      isTrue,
    );
    signedIn.dispose();

    final offline = AuthService(
      secureStore: secure,
      prefs: prefs,
      clientFactory: factoryFor(
        FakeApiHttp(transportError: http.ClientException('offline')),
      ),
    );
    await offline.bootstrap();
    expect(offline.isOffline, isTrue);
    expect(offline.isAuthenticated, isTrue);
    expect(offline.profile?.username, 'pixelpete');
    expect(offline.profile?.storageUsedBytes, isNotNull);
    expect(await secure.read(kAccessTokenStorageKey), 'pxls_testtoken');
    offline.dispose();
  });

  test(
    'bootstrap without a cache still opens a stored session offline',
    () async {
      final secure = MemorySecureStore();
      await secure.write(kAccessTokenStorageKey, 'pxls_testtoken');
      final auth = AuthService(
        secureStore: secure,
        prefs: MemoryPrefsStore(),
        clientFactory: factoryFor(
          FakeApiHttp(transportError: http.ClientException('offline')),
        ),
      );

      await auth.bootstrap();
      expect(auth.isOffline, isTrue);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.profile, isNull);
      expect(await secure.read(kAccessTokenStorageKey), 'pxls_testtoken');
      auth.dispose();
    },
  );

  test(
    'bootstrap shows the login offline banner state without a session',
    () async {
      final auth = AuthService(
        secureStore: MemorySecureStore(),
        clientFactory: factoryFor(
          FakeApiHttp(transportError: http.ClientException('offline')),
        ),
      );

      await auth.bootstrap();
      expect(auth.isOffline, isTrue);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.initialized, isTrue);
      auth.dispose();
    },
  );

  test('bootstrap drops a revoked session instead of the cache', () async {
    final secure = MemorySecureStore();
    final prefs = MemoryPrefsStore();
    await secure.write(kAccessTokenStorageKey, 'pxls_old');
    await prefs.setString(
      AppBrand.current.profileCacheKey,
      jsonEncode({
        'id': 42,
        'username': 'pixelpete',
        'email': 'pete@example.com',
        'status': 'active',
        'plan': 'premium',
      }),
    );
    await prefs.setString(
      AppBrand.current.galleryPageCacheKey(42, 'desc'),
      '{"items":[{"image_uuid":"a"}]}',
    );
    await prefs.setString(
      AppBrand.current.galleryPageCacheKey(42, 'asc'),
      '{"items":[{"image_uuid":"b"}]}',
    );
    final auth = AuthService(
      secureStore: secure,
      prefs: prefs,
      clientFactory: factoryFor(
        FakeApiHttp(profileStatus: 401, profileBody: '{"error":"nope"}'),
      ),
    );

    await auth.bootstrap();
    expect(auth.isAuthenticated, isFalse);
    expect(auth.isOffline, isFalse);
    expect(auth.profile, isNull);
    expect(await secure.read(kAccessTokenStorageKey), isNull);
    expect(await prefs.getString(AppBrand.current.profileCacheKey), isNull);
    expect(
      await prefs.getString(AppBrand.current.galleryPageCacheKey(42, 'desc')),
      isNull,
    );
    expect(
      await prefs.getString(AppBrand.current.galleryPageCacheKey(42, 'asc')),
      isNull,
    );
    auth.dispose();
  });

  test('logout drops the library page cache for that account', () async {
    final secure = MemorySecureStore();
    final prefs = MemoryPrefsStore();
    final auth = AuthService(
      secureStore: secure,
      prefs: prefs,
      clientFactory: factoryFor(
        FakeApiHttp(loginStatus: 200, loginBody: sessionFixture),
      ),
    );
    expect(
      await auth.loginWithPassword('pete@example.com', 'secret12'),
      isTrue,
    );
    await prefs.setString(
      AppBrand.current.galleryPageCacheKey(42, 'desc'),
      '{"items":[{"image_uuid":"a"}]}',
    );
    await prefs.setString(
      AppBrand.current.galleryPageCacheKey(42, 'asc'),
      '{"items":[{"image_uuid":"b"}]}',
    );

    await auth.logout();

    expect(auth.isAuthenticated, isFalse);
    expect(
      await prefs.getString(AppBrand.current.galleryPageCacheKey(42, 'desc')),
      isNull,
    );
    expect(
      await prefs.getString(AppBrand.current.galleryPageCacheKey(42, 'asc')),
      isNull,
    );
    auth.dispose();
  });

  test(
    'a profile that arrives after sign-out does not restore the session',
    () async {
      final secure = MemorySecureStore();
      final prefs = MemoryPrefsStore();
      await secure.write(kAccessTokenStorageKey, 'pxls_old');
      await prefs.setString(
        AppBrand.current.profileCacheKey,
        jsonEncode({
          'id': 42,
          'username': 'pixelpete',
          'email': 'pete@example.com',
          'status': 'active',
          'plan': 'premium',
        }),
      );
      final gate = Completer<http.Response>();
      final auth = AuthService(
        secureStore: secure,
        prefs: prefs,
        clientFactory: factoryFor(_GatedProfileHttp(gate)),
      );

      final pending = auth.bootstrap();
      await Future<void>.delayed(Duration.zero);
      await auth.logout();
      gate.complete(
        http.Response(
          profileFixture,
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await pending;

      expect(auth.isAuthenticated, isFalse);
      expect(auth.profile, isNull);
      expect(await secure.read(kAccessTokenStorageKey), isNull);
      expect(await prefs.getString(AppBrand.current.profileCacheKey), isNull);
      auth.dispose();
    },
  );

  test(
    'a profile slower than the reachability deadline stays offline',
    () async {
      final secure = MemorySecureStore();
      final prefs = MemoryPrefsStore();
      final seeded = AuthService(
        secureStore: secure,
        prefs: prefs,
        clientFactory: factoryFor(
          FakeApiHttp(loginStatus: 200, loginBody: sessionFixture),
        ),
      );
      expect(
        await seeded.loginWithPassword('pete@example.com', 'secret12'),
        isTrue,
      );
      seeded.dispose();

      final gate = Completer<http.Response>();
      final auth = AuthService(
        secureStore: secure,
        prefs: prefs,
        clientFactory: factoryFor(_GatedProfileHttp(gate)),
      );
      final pending = auth.bootstrap();
      await pending;

      expect(auth.isOffline, isTrue);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.profile?.username, 'pixelpete');

      gate.complete(
        http.Response(
          profileFixture.replaceFirst('pixelpete', 'lateuser'),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(auth.isOffline, isTrue);
      expect(auth.profile?.username, 'pixelpete');
      expect(await secure.read(kAccessTokenStorageKey), 'pxls_testtoken');
      auth.dispose();
    },
  );

  test(
    'a rejected profile after the deadline revokes the stored session',
    () async {
      final secure = MemorySecureStore();
      final prefs = MemoryPrefsStore();
      await secure.write(kAccessTokenStorageKey, 'pxls_old');
      final gate = Completer<http.Response>();
      final auth = AuthService(
        secureStore: secure,
        prefs: prefs,
        clientFactory: factoryFor(_GatedProfileHttp(gate)),
      );
      await auth.bootstrap();
      expect(auth.isOffline, isTrue);
      expect(await secure.read(kAccessTokenStorageKey), 'pxls_old');

      gate.complete(
        http.Response(
          '{"error":"nope"}',
          401,
          headers: {'content-type': 'application/json'},
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(auth.isAuthenticated, isFalse);
      expect(auth.isOffline, isFalse);
      expect(auth.profile, isNull);
      expect(await secure.read(kAccessTokenStorageKey), isNull);
      auth.dispose();
    },
  );
}

class _GatedProfileHttp implements ApiHttp {
  _GatedProfileHttp(this._profile);

  final Completer<http.Response> _profile;

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) {
    if (url.path.endsWith('/user/profile')) return _profile.future;
    return Future<http.Response>.value(http.Response('{}', 200));
  }

  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) => Future<http.Response>.value(http.Response('', 204));

  @override
  Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) => Future<http.Response>.error(UnimplementedError());

  @override
  Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) => Future<http.Response>.error(UnimplementedError());

  @override
  Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) => Future<http.Response>.error(UnimplementedError());

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      Future<http.StreamedResponse>.error(UnimplementedError());
}
