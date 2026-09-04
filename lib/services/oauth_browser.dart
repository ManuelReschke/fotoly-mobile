import 'dart:async';

typedef LaunchUrl = Future<bool> Function(Uri url);

/// Opens the system browser and waits for a callback URI with [callbackUrlScheme].
///
/// Linux cannot depend on `flutter_web_auth_2` (it pulls `webkit2gtk`).
/// Android/iOS/Linux all use the system browser plus an incoming app link.
Future<Uri> openOAuthSession({
  required Uri authorizationUrl,
  required String callbackUrlScheme,
  required LaunchUrl launchUrl,
  required Stream<Uri> incomingLinks,
  Duration timeout = const Duration(minutes: 5),
}) async {
  final done = Completer<Uri>();
  final sub = incomingLinks.listen((uri) {
    if (uri.scheme == callbackUrlScheme && !done.isCompleted) {
      done.complete(uri);
    }
  });
  try {
    final launched = await launchUrl(authorizationUrl);
    if (!launched) {
      throw StateError('Could not open the login browser');
    }
    try {
      return await done.future.timeout(timeout);
    } on TimeoutException {
      throw StateError('Social login timed out');
    }
  } finally {
    await sub.cancel();
  }
}
