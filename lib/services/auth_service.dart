import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../config/app_brand.dart';
import '../models/user_profile.dart';
import 'auth_errors.dart';
import 'network_failure.dart';
import 'pixelfox_api_client.dart';
import 'storage.dart';

String get kApiKeyStorageKey => AppBrand.current.apiKeyStorageKey;
String get kAccessTokenStorageKey => AppBrand.current.accessTokenStorageKey;

typedef ApiClientFactory =
    PixelfoxApiClient Function({String? apiKey, String? accessToken});

typedef OpenAuthSession =
    Future<Uri> Function(Uri authorizationUrl, String callbackUrlScheme);

enum _Reachability { online, offline }

/// Manages API-key and app-session auth.
class AuthService extends ChangeNotifier {
  AuthService({
    required this._secureStore,
    this._prefs,
    ApiClientFactory? clientFactory,
    this._openAuthSession,
  }) : _clientFactory =
           clientFactory ??
           (({apiKey, accessToken}) =>
               PixelfoxApiClient(apiKey: apiKey, accessToken: accessToken));

  final SecureStore _secureStore;
  final PrefsStore? _prefs;
  final ApiClientFactory _clientFactory;
  final OpenAuthSession? _openAuthSession;

  UserProfile? _profile;
  String? _apiKey;
  String? _accessToken;
  String? _error;
  bool _loading = false;
  bool _initialized = false;
  bool _offline = false;
  bool _retrying = false;
  Timer? _retryTimer;

  /// Identity of the sign-in, refresh, or sign-out that owns auth state.
  /// A late profile response from an older attempt must not write over it.
  int _attempt = 0;

  /// Attempt that turned the loading flag on, so a finished call cannot
  /// clear a newer call's spinner.
  int _loadingOwner = 0;
  List<AuthProviderInfo> _providers = const [];

  UserProfile? get profile => _profile;
  String? get apiKey => _apiKey;
  String? get accessToken => _accessToken;
  String? get error => _error;
  bool get loading => _loading;
  bool get isOffline => _offline;
  bool get hasCredential =>
      (_accessToken != null && _accessToken!.trim().isNotEmpty) ||
      (_apiKey != null && _apiKey!.trim().isNotEmpty);

  /// A stored session stays signed in while offline, even before a profile
  /// snapshot exists. A revoked session is cleared on HTTP 401/403.
  bool get isAuthenticated => hasCredential && (_profile != null || _offline);
  bool get initialized => _initialized;
  List<AuthProviderInfo> get providers => _providers;

  PixelfoxApiClient? get client {
    if (_accessToken != null) {
      return _clientFactory(accessToken: _accessToken);
    }
    if (_apiKey != null) {
      return _clientFactory(apiKey: _apiKey);
    }
    return null;
  }

  PixelfoxApiClient get _guestClient => _clientFactory();

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<void> bootstrap() async {
    final attempt = ++_attempt;
    _setLoading(attempt, true);
    _error = null;
    notifyListeners();
    try {
      final cached = await _readProfileCache();
      if (attempt != _attempt) return;
      final session = (await _secureStore.read(kAccessTokenStorageKey))?.trim();
      final storedKey = (await _secureStore.read(kApiKeyStorageKey))?.trim();
      if (attempt != _attempt) return;
      final token = (session != null && session.isNotEmpty) ? session : null;
      final apiKey = token == null && storedKey != null && storedKey.isNotEmpty
          ? storedKey
          : null;

      if (token == null && apiKey == null) {
        _clearLocalAuth();
        final reachability = await _tryLoadProviders();
        if (attempt != _attempt) return;
        _setOffline(reachability == _Reachability.offline);
        return;
      }

      try {
        final profile = await _fetchProfile(
          attempt: attempt,
          apiKey: apiKey,
          accessToken: token,
        );
        if (attempt != _attempt) return;
        await _commitProfile(
          attempt,
          profile,
          apiKey: apiKey,
          accessToken: token,
        );
        if (attempt != _attempt) return;
        _setOffline(false);
        unawaited(loadProviders());
      } on PixelfoxApiException catch (e) {
        if (attempt != _attempt) return;
        if (_isAuthRejection(e)) {
          _error = e.message;
          await _rejectStoredSession(userId: cached?.id);
        } else {
          _error = e.message;
          _clearLocalAuth();
          _setOffline(false);
        }
      } catch (e) {
        if (attempt != _attempt) return;
        if (isTransportFailure(e)) {
          _accessToken = token;
          _apiKey = apiKey;
          _profile = cached;
          _error = null;
          _setOffline(true);
        } else {
          _error = AuthErrorCodes.loginFailed;
          _clearLocalAuth();
          _setOffline(false);
        }
      }
    } finally {
      _setLoading(attempt, false);
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> loadProviders() async {
    await _tryLoadProviders();
  }

  Future<_Reachability> _tryLoadProviders() async {
    final client = _guestClient;
    try {
      _providers = await _deadline(client, client.listAuthProviders());
      return _Reachability.online;
    } catch (e) {
      _providers = const [];
      if (isTransportFailure(e)) return _Reachability.offline;
      return _Reachability.online;
    }
  }

  Future<bool> loginWithPassword(String email, String password) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || password.isEmpty) {
      _error = AuthErrorCodes.credentialsRequired;
      notifyListeners();
      return false;
    }
    final attempt = ++_attempt;
    _setLoading(attempt, true);
    _error = null;
    notifyListeners();
    final client = _guestClient;
    try {
      final session = await _deadline(
        client,
        client.loginWithPassword(email: trimmedEmail, password: password),
      );
      if (attempt != _attempt) return false;
      await _persistSession(session);
      if (attempt != _attempt) return false;
      _setOffline(false);
      return true;
    } on PixelfoxApiException catch (e) {
      if (attempt != _attempt) return false;
      _error = e.message;
      _clearLocalAuth();
      return false;
    } catch (e) {
      if (attempt != _attempt) return false;
      _error = AuthErrorCodes.loginFailed;
      if (isTransportFailure(e)) _setOffline(true);
      _clearLocalAuth();
      return false;
    } finally {
      _setLoading(attempt, false);
      notifyListeners();
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final trimmedName = username.trim();
    final trimmedEmail = email.trim();
    if (trimmedName.isEmpty || trimmedEmail.isEmpty || password.isEmpty) {
      _error = AuthErrorCodes.registerFieldsRequired;
      notifyListeners();
      return false;
    }
    final attempt = ++_attempt;
    _setLoading(attempt, true);
    _error = null;
    notifyListeners();
    final client = _guestClient;
    try {
      await _deadline(
        client,
        client.register(
          username: trimmedName,
          email: trimmedEmail,
          password: password,
        ),
      );
      if (attempt != _attempt) return false;
      _setOffline(false);
      return true;
    } on PixelfoxApiException catch (e) {
      if (attempt != _attempt) return false;
      _error = e.message;
      return false;
    } catch (e) {
      if (attempt != _attempt) return false;
      _error = AuthErrorCodes.registerFailed;
      if (isTransportFailure(e)) _setOffline(true);
      return false;
    } finally {
      _setLoading(attempt, false);
      notifyListeners();
    }
  }

  Future<bool> loginWithProvider(String providerId) async {
    final opener = _openAuthSession;
    if (opener == null) {
      _error = AuthErrorCodes.socialUnavailable;
      notifyListeners();
      return false;
    }
    final attempt = ++_attempt;
    _setLoading(attempt, true);
    _error = null;
    notifyListeners();
    final client = _guestClient;
    try {
      final result = await opener(
        client.oauthStartUri(providerId),
        ApiConfig.callbackUrlScheme,
      );
      if (attempt != _attempt) return false;
      final code = result.queryParameters['code']?.trim() ?? '';
      if (code.isEmpty) {
        _error = AuthErrorCodes.socialCancelled;
        return false;
      }
      final session = await _deadline(client, client.exchangeAuthCode(code));
      if (attempt != _attempt) return false;
      await _persistSession(session);
      if (attempt != _attempt) return false;
      _setOffline(false);
      return true;
    } on PixelfoxApiException catch (e) {
      if (attempt != _attempt) return false;
      _error = e.message;
      _clearLocalAuth();
      return false;
    } on StateError catch (e) {
      if (attempt != _attempt) return false;
      _error = e.message;
      _clearLocalAuth();
      return false;
    } catch (e) {
      if (attempt != _attempt) return false;
      _error = AuthErrorCodes.socialFailed;
      if (isTransportFailure(e)) _setOffline(true);
      _clearLocalAuth();
      return false;
    } finally {
      _setLoading(attempt, false);
      notifyListeners();
    }
  }

  /// Login with a new API key — requires successful profile fetch.
  Future<bool> loginWithApiKey(String rawKey) async {
    final key = rawKey.trim();
    if (key.isEmpty) {
      _error = AuthErrorCodes.apiKeyRequired;
      notifyListeners();
      return false;
    }
    final attempt = ++_attempt;
    _setLoading(attempt, true);
    _error = null;
    notifyListeners();
    try {
      final profile = await _fetchProfile(attempt: attempt, apiKey: key);
      if (attempt != _attempt) return false;
      await _commitProfile(attempt, profile, apiKey: key);
      if (attempt != _attempt) return false;
      await _secureStore.write(kApiKeyStorageKey, key);
      if (attempt != _attempt) {
        if (!hasCredential) await _secureStore.delete(kApiKeyStorageKey);
        return false;
      }
      await _secureStore.delete(kAccessTokenStorageKey);
      if (attempt != _attempt) return false;
      _accessToken = null;
      _setOffline(false);
      return true;
    } on PixelfoxApiException catch (e) {
      if (attempt != _attempt) return false;
      _error = e.message;
      _clearLocalAuth();
      return false;
    } catch (e) {
      if (attempt != _attempt) return false;
      _error = AuthErrorCodes.loginFailed;
      if (isTransportFailure(e)) _setOffline(true);
      _clearLocalAuth();
      return false;
    } finally {
      _setLoading(attempt, false);
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final userId = _profile?.id;
    final token = _accessToken;
    final attempt = ++_attempt;
    _clearLocalAuth();
    _error = null;
    _setOffline(false);
    notifyListeners();
    if (token != null) {
      final client = _clientFactory(accessToken: token);
      try {
        await _deadline(client, client.logoutSession());
      } catch (_) {}
    }
    await _deleteStoredCredential(attempt, userId);
    if (attempt == _attempt) notifyListeners();
  }

  /// Re-fetch profile (storage stats, plan, …) without re-entering the key.
  ///
  /// [silent] skips the loading flag so a background retry does not disable
  /// the login form or the storage refresh spinner.
  Future<bool> refreshProfile({bool silent = false}) async {
    if (!hasCredential) {
      if (_offline) {
        final reachability = await _tryLoadProviders();
        if (reachability == _Reachability.online) {
          _setOffline(false);
          notifyListeners();
        }
      }
      return false;
    }
    final attempt = ++_attempt;
    if (!silent) {
      _setLoading(attempt, true);
      notifyListeners();
    }
    try {
      final profile = await _fetchProfile(
        attempt: attempt,
        apiKey: _apiKey,
        accessToken: _accessToken,
      );
      if (attempt != _attempt) return false;
      await _commitProfile(
        attempt,
        profile,
        apiKey: _apiKey,
        accessToken: _accessToken,
      );
      if (attempt != _attempt) return false;
      _setOffline(false);
      return true;
    } on PixelfoxApiException catch (e) {
      if (attempt != _attempt) return false;
      if (_isAuthRejection(e)) {
        _error = e.message;
        await _rejectStoredSession();
        return false;
      }
      // The server answered, so this is not an offline session.
      _setOffline(false);
      if (!silent) _error = e.message;
      return false;
    } catch (e) {
      if (attempt != _attempt) return false;
      if (isTransportFailure(e)) {
        _setOffline(true);
        return false;
      }
      if (!silent) _error = AuthErrorCodes.loginFailed;
      return false;
    } finally {
      if (!silent) _setLoading(attempt, false);
      if (attempt == _attempt) notifyListeners();
    }
  }

  Future<void> _persistSession(AuthSession session) async {
    await _secureStore.write(kAccessTokenStorageKey, session.token);
    await _secureStore.delete(kApiKeyStorageKey);
    _accessToken = session.token;
    _apiKey = null;
    _profile = session.user;
    _error = null;
    await _writeProfileCache(session.user);
  }

  void _setLoading(int attempt, bool value) {
    if (value) {
      _loadingOwner = attempt;
      _loading = true;
      return;
    }
    if (_loadingOwner == attempt) _loading = false;
  }

  /// Loads a profile without writing auth state.
  ///
  /// The HTTP client is closed when the deadline passes, so a slow socket
  /// cannot finish later and apply a session that was already abandoned.
  Future<UserProfile> _fetchProfile({
    required int attempt,
    String? apiKey,
    String? accessToken,
  }) {
    final client = _clientFactory(apiKey: apiKey, accessToken: accessToken);
    final future = client.getProfile();
    var abandoned = false;
    unawaited(
      future.then<void>(
        (_) {},
        onError: (Object error, StackTrace _) {
          if (!abandoned || attempt != _attempt) return;
          if (error is! PixelfoxApiException || !_isAuthRejection(error)) {
            return;
          }
          _error ??= error.message;
          unawaited(_rejectStoredSession());
        },
      ),
    );
    return _deadline(client, future, onAbandon: () => abandoned = true);
  }

  Future<T> _deadline<T>(
    PixelfoxApiClient client,
    Future<T> request, {
    void Function()? onAbandon,
  }) {
    return request
        .timeout(
          kReachabilityTimeout,
          onTimeout: () {
            onAbandon?.call();
            client.close();
            throw TimeoutException('Fotoly unreachable', kReachabilityTimeout);
          },
        )
        .whenComplete(() {
          client.close();
        });
  }

  Future<void> _commitProfile(
    int attempt,
    UserProfile profile, {
    String? apiKey,
    String? accessToken,
  }) async {
    if (attempt != _attempt) return;
    _apiKey = apiKey;
    _accessToken = accessToken;
    _profile = profile;
    _error = null;
    await _writeProfileCache(profile);
    if (attempt != _attempt) await _restoreProfileCache();
  }

  Future<void> _restoreProfileCache() async {
    final profile = _profile;
    if (!hasCredential || profile == null) {
      await _clearProfileCache();
      return;
    }
    await _writeProfileCache(profile);
  }

  void _clearLocalAuth() {
    _profile = null;
    _apiKey = null;
    _accessToken = null;
  }

  Future<void> _rejectStoredSession({int? userId}) async {
    final id = userId ?? _profile?.id;
    final attempt = ++_attempt;
    _clearLocalAuth();
    _setOffline(false);
    notifyListeners();
    await _deleteStoredCredential(attempt, id);
  }

  Future<void> _deleteStoredCredential(int attempt, int? userId) async {
    await _clearGalleryCache(userId);
    if (attempt != _attempt) return;
    await _secureStore.delete(kApiKeyStorageKey);
    if (attempt != _attempt) return;
    await _secureStore.delete(kAccessTokenStorageKey);
    if (attempt != _attempt) return;
    await _clearProfileCache();
  }

  Future<void> _clearGalleryCache(int? userId) async {
    final prefs = _prefs;
    if (prefs == null || userId == null) return;
    final brand = AppBrand.current;
    await prefs.remove(brand.galleryPageCacheKey(userId, 'desc'));
    await prefs.remove(brand.galleryPageCacheKey(userId, 'asc'));
  }

  bool _isAuthRejection(PixelfoxApiException error) =>
      error.statusCode == 401 || error.statusCode == 403;

  Future<void> _writeProfileCache(UserProfile profile) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(
      AppBrand.current.profileCacheKey,
      jsonEncode(profile.toCacheJson()),
    );
  }

  Future<UserProfile?> _readProfileCache() async {
    final prefs = _prefs;
    if (prefs == null) return null;
    final raw = await prefs.getString(AppBrand.current.profileCacheKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return UserProfile.fromCacheJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearProfileCache() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.remove(AppBrand.current.profileCacheKey);
  }

  void _setOffline(bool value) {
    _offline = value;
    if (value) {
      _retryTimer ??= Timer.periodic(kOfflineRetryInterval, (_) {
        unawaited(_retryReachability());
      });
    } else {
      _retryTimer?.cancel();
      _retryTimer = null;
    }
  }

  Future<void> _retryReachability() async {
    if (!_offline || _retrying) return;
    _retrying = true;
    try {
      await refreshProfile(silent: true);
    } finally {
      _retrying = false;
    }
  }
}
