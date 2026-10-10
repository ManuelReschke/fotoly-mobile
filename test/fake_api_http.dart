import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:fotoly_mobile/services/pixelfox_api_client.dart';

/// Fake network layer — only outside the client under test.
class FakeApiHttp implements ApiHttp {
  FakeApiHttp({
    this.profileStatus = 200,
    this.profileBody,
    this.sessionStatus = 200,
    this.sessionBody,
    this.uploadStatus = 200,
    this.uploadBody,
    this.albumsStatus = 200,
    this.albumsBody,
    this.albumWriteStatus = 200,
    this.albumWriteBody,
    this.membersStatus = 200,
    this.membersBody,
    this.memberPostStatus = 201,
    this.memberPostBody,
    this.memberDeleteStatus = 204,
    this.memberDeleteBody,
    this.categoriesStatus = 200,
    this.categoriesBody,
    this.categoryCreateStatus = 201,
    this.categoryCreateBody,
    this.categoryAssignStatus = 200,
    this.categoryAssignBody,
    this.imagesStatus = 200,
    this.imagesBody,
    this.imageStatusByUuid = const {},
    this.defaultImageStatus = 404,
    this.defaultImageBody,
    this.providersStatus = 200,
    this.providersBody,
    this.registerStatus = 201,
    this.registerBody,
    this.loginStatus = 200,
    this.loginBody,
    this.tokenStatus = 200,
    this.tokenBody,
    this.logoutStatus = 204,
  });

  int profileStatus;
  String? profileBody;
  int sessionStatus;
  String? sessionBody;
  int uploadStatus;
  String? uploadBody;
  int albumsStatus;
  String? albumsBody;

  /// Status and body for POST/PATCH/PUT/DELETE under `/albums`.
  int albumWriteStatus;
  String? albumWriteBody;
  int membersStatus;
  String? membersBody;
  int memberPostStatus;
  String? memberPostBody;
  int memberDeleteStatus;
  String? memberDeleteBody;
  int categoriesStatus;
  String? categoriesBody;
  int categoryCreateStatus;
  String? categoryCreateBody;
  int categoryAssignStatus;
  String? categoryAssignBody;
  int imagesStatus;
  String? imagesBody;

  /// Per-uuid HTTP status for `GET /images/{uuid}`.
  Map<String, int> imageStatusByUuid;

  /// Used when [imageStatusByUuid] has no entry for a uuid.
  int defaultImageStatus;
  String? defaultImageBody;
  int providersStatus;
  String? providersBody;
  int registerStatus;
  String? registerBody;
  int loginStatus;
  String? loginBody;
  int tokenStatus;
  String? tokenBody;
  int logoutStatus;

  final List<http.BaseRequest> sent = [];

  static final _imagePath = RegExp(r'/images/([^/]+)$');
  static final _membersPath = RegExp(r'/albums/\d+/members(?:/\d+)?$');
  static final _categoryAssignPath = RegExp(r'/albums/\d+/categories$');

  static const _defaultMember =
      '{"user_id":3,"username":"ada","role":"viewer","origin":"invite","created_at":"2026-01-01T00:00:00Z","already_member":false}';
  static const _defaultCategory =
      '{"id":1,"name":"Trip","slug":"trip","scope":"private","album_count":0}';

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    sent.add(_RecordedRequest('GET', url, headers ?? {}));
    if (url.path.endsWith('/auth/providers')) {
      return http.Response(
        providersBody ?? '{"providers":[]}',
        providersStatus,
        headers: {'content-type': 'application/json'},
        request: http.Request('GET', url),
      );
    }
    if (url.path.endsWith('/user/profile')) {
      return http.Response(
        profileBody ?? '{}',
        profileStatus,
        headers: {'content-type': 'application/json'},
        request: http.Request('GET', url),
      );
    }
    if (url.path.endsWith('/album-categories')) {
      return http.Response(
        categoriesBody ?? '{"categories":[]}',
        categoriesStatus,
        headers: {'content-type': 'application/json'},
        request: http.Request('GET', url),
      );
    }
    if (_membersPath.hasMatch(url.path)) {
      return http.Response(
        membersBody ?? '{"members":[]}',
        membersStatus,
        headers: {'content-type': 'application/json'},
        request: http.Request('GET', url),
      );
    }
    if (url.path.endsWith('/albums')) {
      return http.Response(
        albumsBody ?? '{"albums":[]}',
        albumsStatus,
        headers: {'content-type': 'application/json'},
        request: http.Request('GET', url),
      );
    }
    if (url.path.endsWith('/images')) {
      return http.Response(
        imagesBody ?? '{"items":[],"has_more":false}',
        imagesStatus,
        headers: {'content-type': 'application/json'},
        request: http.Request('GET', url),
      );
    }
    final imageMatch = _imagePath.firstMatch(url.path);
    if (imageMatch != null && !url.path.endsWith('/status')) {
      final uuid = imageMatch.group(1)!;
      final status = imageStatusByUuid[uuid] ?? defaultImageStatus;
      final body = status == 200
          ? (defaultImageBody ?? '{"image_uuid":"$uuid"}')
          : (defaultImageBody ?? '{"error":"not_found"}');
      return http.Response(
        body,
        status,
        headers: {'content-type': 'application/json'},
        request: http.Request('GET', url),
      );
    }
    return http.Response('not found', 404);
  }

  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    final req = _RecordedRequest('POST', url, headers ?? {}, body: body);
    sent.add(req);
    if (url.path.endsWith('/upload/sessions')) {
      return http.Response(
        sessionBody ?? '{}',
        sessionStatus,
        headers: {'content-type': 'application/json'},
      );
    }
    if (url.path.endsWith('/auth/register')) {
      return http.Response(
        registerBody ?? '{}',
        registerStatus,
        headers: {'content-type': 'application/json'},
      );
    }
    if (url.path.endsWith('/auth/login')) {
      return http.Response(
        loginBody ?? '{}',
        loginStatus,
        headers: {'content-type': 'application/json'},
      );
    }
    if (url.path.endsWith('/auth/token')) {
      return http.Response(
        tokenBody ?? '{}',
        tokenStatus,
        headers: {'content-type': 'application/json'},
      );
    }
    if (url.path.endsWith('/auth/logout')) {
      return http.Response('', logoutStatus);
    }
    final sharing = _sharingWrite('POST', url);
    if (sharing != null) return sharing;
    if (url.path.contains('/albums')) {
      return _albumWrite(url);
    }
    return http.Response('not found', 404);
  }

  @override
  Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return _recordWrite('PATCH', url, headers: headers, body: body);
  }

  @override
  Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return _recordWrite('PUT', url, headers: headers, body: body);
  }

  @override
  Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return _recordWrite('DELETE', url, headers: headers, body: body);
  }

  Future<http.Response> _recordWrite(
    String method,
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    sent.add(_RecordedRequest(method, url, headers ?? {}, body: body));
    final sharing = _sharingWrite(method, url);
    if (sharing != null) return sharing;
    if (url.path.contains('/albums')) return _albumWrite(url);
    return http.Response('not found', 404);
  }

  http.Response? _sharingWrite(String method, Uri url) {
    if (url.path.endsWith('/album-categories')) {
      return http.Response(
        categoryCreateBody ?? _defaultCategory,
        categoryCreateStatus,
        headers: {'content-type': 'application/json'},
        request: http.Request(method, url),
      );
    }
    if (_membersPath.hasMatch(url.path)) {
      if (method == 'DELETE') {
        return http.Response(
          memberDeleteBody ?? '',
          memberDeleteStatus,
          request: http.Request(method, url),
        );
      }
      return http.Response(
        memberPostBody ?? _defaultMember,
        memberPostStatus,
        headers: {'content-type': 'application/json'},
        request: http.Request(method, url),
      );
    }
    if (_categoryAssignPath.hasMatch(url.path)) {
      return http.Response(
        categoryAssignBody ?? '{"categories":[]}',
        categoryAssignStatus,
        headers: {'content-type': 'application/json'},
        request: http.Request(method, url),
      );
    }
    return null;
  }

  http.Response _albumWrite(Uri url) {
    return http.Response(
      albumWriteBody ?? '{}',
      albumWriteStatus,
      headers: {'content-type': 'application/json'},
      request: http.Request('POST', url),
    );
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sent.add(request);
    final body = uploadBody ?? '{}';
    final bytes = utf8.encode(body);
    return http.StreamedResponse(
      Stream.fromIterable([bytes]),
      uploadStatus,
      headers: {'content-type': 'application/json'},
      contentLength: bytes.length,
      request: request,
    );
  }
}

class _RecordedRequest extends http.BaseRequest {
  _RecordedRequest(
    super.method,
    super.url,
    Map<String, String> headers, {
    this.body,
  }) {
    this.headers.addAll(headers);
  }

  final Object? body;

  @override
  http.ByteStream finalize() {
    super.finalize();
    return http.ByteStream.fromBytes(utf8.encode(body?.toString() ?? ''));
  }
}
