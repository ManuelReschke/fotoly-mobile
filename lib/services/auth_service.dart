import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../config/app_brand.dart';
import '../models/user_profile.dart';
import 'pixelfox_api_client.dart';
import 'storage.dart';

String get kApiKeyStorageKey => AppBrand.current.apiKeyStorageKey;
String get kAccessTokenStorageKey => AppBrand.current.accessTokenStorageKey;

typedef ApiClientFactory =
    PixelfoxApiClient Function({String? apiKey, String? accessToken});

typedef OpenAuthSession =
    Future<Uri> Function(Uri authorizationUrl, String callbackUrlScheme);

/// Manages API-key and app-session auth.
class AuthService extends ChangeNotifier {
  AuthService({
    required this._secureStore,
    ApiClientFactory? clientFactory,
    this._openAuthSession,
  }) : _clientFactory =
           clientFactory ??
           (({apiKey, accessToken}) =>
               PixelfoxApiClient(apiKey: apiKey, accessToken: accessToken));

  final SecureStore _secureStore;
  final ApiClientFactory _clientFactory;
  final OpenAuthSession? _openAuthSession;

  UserProfile? _profile;
  String? _apiKey;
  String? _accessToken;
  String? _error;
  bool _loading = false;
  bool _initialized = false;
  List<AuthProviderInfo> _providers = const [];

  UserProfile? get profile => _profile;
  String? get apiKey => _apiKey;
  String? get accessToken => _accessToken;
  String? get error => _error;
  bool get loading => _loading;
  bool get isAuthenticated =>
      _profile != null && (_apiKey != null || _accessToken != null);
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

  Future<void> bootstrap() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await loadProviders();
      final session = await _secureStore.read(kAccessTokenStorageKey);
      if (session != null && session.trim().isNotEmpty) {
        await _validateAndStore(accessToken: session.trim());
        return;
      }
      final key = await _secureStore.read(kApiKeyStorageKey);
      if (key == null || key.trim().isEmpty) {
        _apiKey = null;
        _accessToken = null;
        _profile = null;
      } else {
        await _validateAndStore(apiKey: key.trim());
      }
    } catch (e) {
      _error = e.toString();
      _profile = null;
    } finally {
      _loading = false;
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> loadProviders() async {
    try {
      _providers = await _guestClient.listAuthProviders();
    } catch (_) {
      _providers = const [];
    }
  }

  Future<bool> loginWithPassword(String email, String password) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || password.isEmpty) {
      _error = 'Please enter email and password';
      notifyListeners();
      return false;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final session = await _guestClient.loginWithPassword(
        email: trimmedEmail,
        password: password,
      );
      await _persistSession(session);
      return true;
    } on PixelfoxApiException catch (e) {
      _error = e.message;
      _clearLocalAuth();
      return false;
    } catch (e) {
      _error = 'Login failed: $e';
      _clearLocalAuth();
      return false;
    } finally {
      _loading = false;
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
      _error = 'Please enter username, email and password';
      notifyListeners();
      return false;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _guestClient.register(
        username: trimmedName,
        email: trimmedEmail,
        password: password,
      );
      return true;
    } on PixelfoxApiException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Registration failed: $e';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> loginWithProvider(String providerId) async {
    final opener = _openAuthSession;
    if (opener == null) {
      _error = 'Social login is not available on this device';
      notifyListeners();
      return false;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await opener(
        _guestClient.oauthStartUri(providerId),
        ApiConfig.callbackUrlScheme,
      );
      final code = result.queryParameters['code']?.trim() ?? '';
      if (code.isEmpty) {
        _error = 'Social login was cancelled';
        return false;
      }
      final session = await _guestClient.exchangeAuthCode(code);
      await _persistSession(session);
      return true;
    } on PixelfoxApiException catch (e) {
      _error = e.message;
      _clearLocalAuth();
      return false;
    } catch (e) {
      _error = 'Social login failed: $e';
      _clearLocalAuth();
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Login with a new API key — requires successful profile fetch.
  Future<bool> loginWithApiKey(String rawKey) async {
    final key = rawKey.trim();
    if (key.isEmpty) {
      _error = 'Please enter your ${AppBrand.current.displayName} API key';
      notifyListeners();
      return false;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _validateAndStore(apiKey: key);
      await _secureStore.write(kApiKeyStorageKey, key);
      await _secureStore.delete(kAccessTokenStorageKey);
      _accessToken = null;
      return true;
    } on PixelfoxApiException catch (e) {
      _error = e.message;
      _clearLocalAuth();
      return false;
    } catch (e) {
      _error = 'Login failed: $e';
      _clearLocalAuth();
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final token = _accessToken;
    if (token != null) {
      try {
        await _clientFactory(accessToken: token).logoutSession();
      } catch (_) {}
    }
    await _secureStore.delete(kApiKeyStorageKey);
    await _secureStore.delete(kAccessTokenStorageKey);
    _clearLocalAuth();
    _error = null;
    notifyListeners();
  }

  /// Re-fetch profile (storage stats, plan, …) without re-entering the key.
  Future<bool> refreshProfile() async {
    if (_accessToken == null && _apiKey == null) return false;
    _loading = true;
    notifyListeners();
    try {
      await _validateAndStore(apiKey: _apiKey, accessToken: _accessToken);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _persistSession(AuthSession session) async {
    await _secureStore.write(kAccessTokenStorageKey, session.token);
    await _secureStore.delete(kApiKeyStorageKey);
    _accessToken = session.token;
    _apiKey = null;
    _profile = session.user;
    _error = null;
  }

  Future<void> _validateAndStore({String? apiKey, String? accessToken}) async {
    final client = _clientFactory(apiKey: apiKey, accessToken: accessToken);
    final profile = await client.getProfile();
    _apiKey = apiKey;
    _accessToken = accessToken;
    _profile = profile;
    _error = null;
  }

  void _clearLocalAuth() {
    _profile = null;
    _apiKey = null;
    _accessToken = null;
  }
}
