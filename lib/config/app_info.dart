import 'app_brand.dart';

/// App metadata shown in the UI.
///
/// Keep [version] / [buildNumber] in sync with `pubspec.yaml` `version:`.
class AppInfo {
  static const String version = '1.0.0';
  static const String buildNumber = '1';

  /// User-facing label, e.g. `1.0.0 (1)`.
  static String get displayVersion => '$version ($buildNumber)';

  static String get websiteHost => AppBrand.current.websiteHost;
}
