import '../services/file_scanner.dart';
import 'user_profile.dart';

/// Premium per-file cap. Mirrors PixelFox `entitlements.MaxUploadBytes`.
///
/// The live block uses the profile limit. These ceilings only choose which
/// paid plan the backup card offers.
const int kPremiumUploadBytes = 50 * 1024 * 1024;

/// Premium Max per-file cap. Files above this fit no plan.
const int kPremiumMaxUploadBytes = 100 * 1024 * 1024;

/// Paid plan that can accept at least one oversized file.
enum HigherUploadPlan { premium, premiumMax }

/// Which upsell, if any, covers the oversized files.
class OversizedUploadOffer {
  const OversizedUploadOffer({
    required this.plan,
    required this.beyondEveryPlan,
  });

  /// Null when every file is above [kPremiumMaxUploadBytes].
  final HigherUploadPlan? plan;

  /// Files no plan can store. They still need a smaller export.
  final int beyondEveryPlan;

  bool get hasUpsell => plan != null;
}

/// Inventory split for one scan.
class BackupFileGroups {
  const BackupFileGroups({
    required this.pending,
    required this.tooLarge,
    required this.secured,
  });

  final List<LocalImageFile> pending;
  final List<LocalImageFile> tooLarge;
  final List<LocalImageFile> secured;
}

/// True when [sizeBytes] is above a known positive plan limit.
bool fileExceedsUploadLimit(int sizeBytes, int? maxUploadBytes) {
  if (maxUploadBytes == null || maxUploadBytes <= 0) return false;
  return sizeBytes > maxUploadBytes;
}

/// Splits a scan into secured, still uploadable, and too large for the plan.
///
/// [isBlocked] keeps files the server already rejected, even when the cached
/// profile limit is higher than that rejection.
BackupFileGroups splitBackupFiles({
  required List<LocalImageFile> files,
  required bool Function(LocalImageFile file) isBackedUp,
  required int? maxUploadBytes,
  bool Function(LocalImageFile file)? isBlocked,
}) {
  final pending = <LocalImageFile>[];
  final tooLarge = <LocalImageFile>[];
  final secured = <LocalImageFile>[];
  for (final file in files) {
    if (isBackedUp(file)) {
      secured.add(file);
      continue;
    }
    if (fileExceedsUploadLimit(file.sizeBytes, maxUploadBytes) ||
        (isBlocked?.call(file) ?? false)) {
      tooLarge.add(file);
      continue;
    }
    pending.add(file);
  }
  return BackupFileGroups(
    pending: pending,
    tooLarge: tooLarge,
    secured: secured,
  );
}

/// Picks Premium, Premium Max, or no upsell from the oversized file sizes.
OversizedUploadOffer offerForOversizedFiles(Iterable<LocalImageFile> files) {
  var needsPremium = false;
  var needsPremiumMax = false;
  var beyond = 0;
  for (final file in files) {
    final size = file.sizeBytes;
    if (size <= kPremiumUploadBytes) {
      needsPremium = true;
    } else if (size <= kPremiumMaxUploadBytes) {
      needsPremiumMax = true;
    } else {
      beyond++;
    }
  }
  final HigherUploadPlan? plan;
  if (needsPremiumMax) {
    plan = HigherUploadPlan.premiumMax;
  } else if (needsPremium) {
    plan = HigherUploadPlan.premium;
  } else {
    plan = null;
  }
  return OversizedUploadOffer(plan: plan, beyondEveryPlan: beyond);
}

/// Plan and file sizes for the backup card. Drops a trailing ".0".
String formatUploadLimit(int bytes) {
  return formatBytes(bytes).replaceFirst(RegExp(r'\.0 '), ' ');
}
