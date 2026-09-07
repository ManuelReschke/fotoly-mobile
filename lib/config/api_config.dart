import 'app_brand.dart';

/// Pixelfox Public API configuration.
class ApiConfig {
  /// Override with `--dart-define=PIXELFOX_API_BASE=http://127.0.0.1:8080`.
  /// Empty means the active [AppBrand] host (pixelfox.cc / fotoly.eu).
  static const String _baseUrlOverride = String.fromEnvironment(
    'PIXELFOX_API_BASE',
  );

  static String get baseUrl => _baseUrlOverride.isNotEmpty
      ? _baseUrlOverride
      : AppBrand.current.apiBaseUrl;
  static const String apiPrefix = '/api/v1';

  /// Full API root, e.g. https://pixelfox.cc/api/v1
  static String get apiRoot => '$baseUrl$apiPrefix';

  static String profileUrl() => '$apiRoot/user/profile';
  static String uploadSessionsUrl() => '$apiRoot/upload/sessions';
  static String imagesUrl() => '$apiRoot/images';
  static String imageStatusUrl(String uuid) => '$apiRoot/images/$uuid/status';
  static String imageUrl(String uuid) => '$apiRoot/images/$uuid';

  /// Header name for API key auth (preferred per docs).
  static const String apiKeyHeader = 'X-API-Key';

  static String get callbackUrlScheme => AppBrand.current.callbackUrlScheme;
  static String get appRedirectUri => AppBrand.current.appRedirectUri;

  static String authProvidersUrl() => '$apiRoot/auth/providers';
  static String authLoginUrl() => '$apiRoot/auth/login';
  static String authRegisterUrl() => '$apiRoot/auth/register';
  static String authTokenUrl() => '$apiRoot/auth/token';
  static String authLogoutUrl() => '$apiRoot/auth/logout';
  static String authProviderStartUrl(String provider) =>
      '$apiRoot/auth/$provider/start';
}
