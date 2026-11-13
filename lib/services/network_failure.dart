import 'dart:async';

import 'package:http/http.dart' as http;

/// Stable code stored when a gallery load fails before any page is cached.
abstract final class NetworkErrorCodes {
  static const unreachable = 'error.network';
}

/// How long a startup or retry request may wait before the app treats the
/// server as unreachable. A missing network can otherwise stall TCP for minutes.
const Duration kReachabilityTimeout = Duration(seconds: 4);

/// How often an offline session asks Fotoly whether it is reachable again.
const Duration kOfflineRetryInterval = Duration(seconds: 20);

/// True when [error] means the device never got an HTTP response.
///
/// Socket failures from `dart:io` are matched by type name so this file stays
/// free of a `dart:io` import and still compiles for web.
bool isTransportFailure(Object error) {
  if (error is TimeoutException || error is http.ClientException) return true;
  switch (error.runtimeType.toString()) {
    case 'SocketException':
    case 'HandshakeException':
    case 'TlsException':
    case 'HttpException':
      return true;
    default:
      return false;
  }
}
