import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../config/app_brand.dart';
import '../models/pixelfox_album.dart';
import '../models/pixelfox_image.dart';
import '../models/upload_result.dart';
import '../models/upload_session.dart';
import '../models/user_profile.dart';

/// Thrown when the API returns a non-success status.
class PixelfoxApiException implements Exception {
  PixelfoxApiException(this.message, {this.statusCode, this.body});

  final String message;
  final int? statusCode;
  final String? body;

  @override
  String toString() =>
      'PixelfoxApiException($statusCode): $message${body != null ? ' — $body' : ''}';
}

/// Low-level request recorder for tests (captures session body + upload auth).
class ApiRequestLog {
  ApiRequestLog({
    required this.method,
    required this.url,
    this.headers = const {},
    this.jsonBody,
    this.multipartFilename,
    this.multipartByteLength,
  });

  final String method;
  final String url;
  final Map<String, String> headers;
  final Map<String, dynamic>? jsonBody;
  final String? multipartFilename;
  final int? multipartByteLength;
}

/// Injectable HTTP so unit tests drive the real client with a fake network.
abstract class ApiHttp {
  Future<http.Response> get(Uri url, {Map<String, String>? headers});

  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  });

  Future<http.StreamedResponse> send(http.BaseRequest request);
}

class DefaultApiHttp implements ApiHttp {
  DefaultApiHttp([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
      _client.get(url, headers: headers);

  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) => _client.post(url, headers: headers, body: body, encoding: encoding);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _client.send(request);
}

class AuthProviderInfo {
  const AuthProviderInfo({required this.id, required this.name});

  final String id;
  final String name;

  factory AuthProviderInfo.fromJson(Map<String, dynamic> json) {
    return AuthProviderInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}

class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final UserProfile user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      token: json['token'] as String? ?? '',
      user: UserProfile.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

/// Pixelfox Public API v1 client.
///
/// Auth: `X-API-Key` or `Authorization: Bearer pxls_…`.
class PixelfoxApiClient {
  PixelfoxApiClient({
    this.apiKey,
    this.accessToken,
    ApiHttp? httpClient,
    String? baseUrl,
    this._requestLog,
  }) : baseUrl = baseUrl ?? ApiConfig.baseUrl,
       _http = httpClient ?? DefaultApiHttp();

  final String? apiKey;
  final String? accessToken;
  final String baseUrl;
  final ApiHttp _http;
  final List<ApiRequestLog>? _requestLog;

  String get _apiRoot => '$baseUrl${ApiConfig.apiPrefix}';

  Map<String, String> get _jsonHeaders => {'Accept': 'application/json'};

  Map<String, String> get _authHeaders {
    final headers = Map<String, String>.from(_jsonHeaders);
    final session = accessToken?.trim();
    if (session != null && session.isNotEmpty) {
      headers['Authorization'] = 'Bearer $session';
      return headers;
    }
    final key = apiKey?.trim();
    if (key != null && key.isNotEmpty) {
      headers[ApiConfig.apiKeyHeader] = key;
    }
    return headers;
  }

  Future<List<AuthProviderInfo>> listAuthProviders() async {
    final uri = Uri.parse('$_apiRoot/auth/providers');
    _log(
      ApiRequestLog(method: 'GET', url: uri.toString(), headers: _jsonHeaders),
    );
    final response = await _http.get(uri, headers: _jsonHeaders);
    if (response.statusCode != 200) {
      throw PixelfoxApiException(
        'Could not load login providers',
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final items = json['providers'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(AuthProviderInfo.fromJson)
        .where((p) => p.id.isNotEmpty)
        .toList();
  }

  Future<AuthSession> loginWithPassword({
    required String email,
    required String password,
  }) async {
    return _postAuthSession(
      Uri.parse('$_apiRoot/auth/login'),
      {'email': email, 'password': password},
      invalidMessage: 'Invalid email or password',
    );
  }

  Future<AuthSession> exchangeAuthCode(String code) async {
    return _postAuthSession(Uri.parse('$_apiRoot/auth/token'), {
      'code': code,
    }, invalidMessage: 'Social login failed');
  }

  Future<void> logoutSession() async {
    final uri = Uri.parse('$_apiRoot/auth/logout');
    _log(
      ApiRequestLog(method: 'POST', url: uri.toString(), headers: _authHeaders),
    );
    final response = await _http.post(uri, headers: _authHeaders);
    if (response.statusCode == 204 || response.statusCode == 200) {
      return;
    }
    if (response.statusCode == 401) {
      return;
    }
    throw PixelfoxApiException(
      'Logout failed',
      statusCode: response.statusCode,
      body: response.body,
    );
  }

  Uri oauthStartUri(String provider) {
    return Uri.parse(
      '$_apiRoot/auth/$provider/start',
    ).replace(queryParameters: {'redirect_uri': ApiConfig.appRedirectUri});
  }

  Future<AuthSession> _postAuthSession(
    Uri uri,
    Map<String, dynamic> body, {
    required String invalidMessage,
  }) async {
    final headers = {..._jsonHeaders, 'Content-Type': 'application/json'};
    _log(
      ApiRequestLog(
        method: 'POST',
        url: uri.toString(),
        headers: headers,
        jsonBody: body,
      ),
    );
    final response = await _http.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw PixelfoxApiException(
        _apiErrorMessage(response.body, invalidMessage),
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    if (response.statusCode != 200) {
      throw PixelfoxApiException(
        _apiErrorMessage(response.body, 'Login failed'),
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final session = AuthSession.fromJson(json);
    if (session.token.trim().isEmpty) {
      throw PixelfoxApiException('Login failed: missing session token');
    }
    return session;
  }

  String _apiErrorMessage(String body, String fallback) {
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) {
        final message = json['message'] as String?;
        if (message != null && message.trim().isNotEmpty) {
          return message;
        }
      }
    } catch (_) {}
    return fallback;
  }

  /// Validates the key by loading the user profile.
  Future<UserProfile> getProfile() async {
    final uri = Uri.parse('$_apiRoot/user/profile');
    _log(
      ApiRequestLog(method: 'GET', url: uri.toString(), headers: _authHeaders),
    );
    final response = await _http.get(uri, headers: _authHeaders);
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw PixelfoxApiException(
        accessToken != null && accessToken!.trim().isNotEmpty
            ? 'Session expired — please sign in again'
            : 'Invalid API key — check the key in your ${AppBrand.current.displayName} settings',
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    if (response.statusCode != 200) {
      throw PixelfoxApiException(
        'Could not load profile',
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return UserProfile.fromJson(json);
  }

  /// Lists the authenticated user’s albums.
  Future<List<PixelfoxAlbum>> listAlbums() async {
    final uri = Uri.parse('$_apiRoot/albums');
    _log(
      ApiRequestLog(method: 'GET', url: uri.toString(), headers: _authHeaders),
    );
    final response = await _http.get(uri, headers: _authHeaders);
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw PixelfoxApiException(
        'Invalid API key — check the key in your ${AppBrand.current.displayName} settings',
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    if (response.statusCode != 200) {
      throw PixelfoxApiException(
        'Could not load albums',
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final list = json['albums'] as List<dynamic>? ?? const [];
    return list
        .whereType<Map>()
        .map((e) => PixelfoxAlbum.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }

  /// Lists account images with optional cursor paging.
  Future<PixelfoxImagePage> listImages({int limit = 50, String? cursor}) async {
    final uri = Uri.parse('$_apiRoot/images').replace(
      queryParameters: {
        'limit': '$limit',
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    _log(
      ApiRequestLog(method: 'GET', url: uri.toString(), headers: _authHeaders),
    );
    final response = await _http.get(uri, headers: _authHeaders);
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw PixelfoxApiException(
        'Invalid API key — check the key in your ${AppBrand.current.displayName} settings',
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    if (response.statusCode != 200) {
      throw PixelfoxApiException(
        'Could not load images',
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return PixelfoxImagePage.fromJson(json);
  }

  /// Creates an upload session. Prefer [originalOnly] for simple backups.
  Future<UploadSession> createUploadSession({
    required int fileSize,
    bool originalOnly = true,
    int? albumId,
    bool? isNsfw,
  }) async {
    final uri = Uri.parse('$_apiRoot/upload/sessions');
    final body = <String, dynamic>{
      'file_size': fileSize,
      if (originalOnly) 'processing': {'profile': 'original_only'},
      'album_id': ?albumId,
      'is_nsfw': ?isNsfw,
    };

    final headers = {..._authHeaders, 'Content-Type': 'application/json'};
    _log(
      ApiRequestLog(
        method: 'POST',
        url: uri.toString(),
        headers: headers,
        jsonBody: body,
      ),
    );

    final response = await _http.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PixelfoxApiException(
        'Could not create upload session',
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return UploadSession.fromJson(json);
  }

  /// Multipart upload to the session [uploadUrl] using the session token.
  Future<UploadResult> uploadFile({
    required UploadSession session,
    required String filename,
    required List<int> bytes,
    String fieldName = 'file',
  }) async {
    if (session.maxBytes > 0 && bytes.length > session.maxBytes) {
      throw PixelfoxApiException(
        'File exceeds session max_bytes (${session.maxBytes})',
      );
    }

    final uri = Uri.parse(session.uploadUrl);
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer ${session.token}';
    request.headers['Accept'] = 'application/json';
    request.files.add(
      http.MultipartFile.fromBytes(fieldName, bytes, filename: filename),
    );

    _log(
      ApiRequestLog(
        method: 'POST',
        url: uri.toString(),
        headers: Map<String, String>.from(request.headers),
        multipartFilename: filename,
        multipartByteLength: bytes.length,
      ),
    );

    final streamed = await _http.send(request);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PixelfoxApiException(
        'Upload failed',
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return UploadResult.fromJson(json);
  }

  /// Full flow: session + multipart for one image.
  Future<UploadResult> uploadImageBytes({
    required String filename,
    required List<int> bytes,
    bool originalOnly = true,
    int? albumId,
  }) async {
    final session = await createUploadSession(
      fileSize: bytes.length,
      originalOnly: originalOnly,
      albumId: albumId,
    );
    return uploadFile(session: session, filename: filename, bytes: bytes);
  }

  /// Whether the image resource still exists for this account.
  ///
  /// Returns `true` on HTTP 200, `false` on 404.
  /// Throws [PixelfoxApiException] for auth failures and other errors
  /// (caller must not treat those as “missing”).
  Future<bool> imageExists(String imageUuid) async {
    final uri = Uri.parse('$_apiRoot/images/$imageUuid');
    _log(
      ApiRequestLog(method: 'GET', url: uri.toString(), headers: _authHeaders),
    );
    final response = await _http.get(uri, headers: _authHeaders);
    if (response.statusCode == 200) return true;
    if (response.statusCode == 404) return false;
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw PixelfoxApiException(
        'Invalid API key — check the key in your ${AppBrand.current.displayName} settings',
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    throw PixelfoxApiException(
      'Could not verify image',
      statusCode: response.statusCode,
      body: response.body,
    );
  }

  void _log(ApiRequestLog entry) => _requestLog?.add(entry);
}
