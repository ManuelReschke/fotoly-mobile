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
    this.imagesStatus = 200,
    this.imagesBody,
    this.imageStatusByUuid = const {},
    this.defaultImageStatus = 404,
    this.defaultImageBody,
    this.providersStatus = 200,
    this.providersBody,
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
  int imagesStatus;
  String? imagesBody;

  /// Per-uuid HTTP status for `GET /images/{uuid}`.
  Map<String, int> imageStatusByUuid;

  /// Used when [imageStatusByUuid] has no entry for a uuid.
  int defaultImageStatus;
  String? defaultImageBody;
  int providersStatus;
  String? providersBody;
  int loginStatus;
  String? loginBody;
  int tokenStatus;
  String? tokenBody;
  int logoutStatus;

  final List<http.BaseRequest> sent = [];

  static final _imagePath = RegExp(r'/images/([^/]+)$');

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
    return http.Response('not found', 404);
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
