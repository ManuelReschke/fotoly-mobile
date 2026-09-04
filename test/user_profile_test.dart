import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixelfox_mobile/models/user_profile.dart';

void main() {
  test('parses storage usage from profile fixture', () {
    final json =
        jsonDecode(
              File('test/fixtures/profile_success.json').readAsStringSync(),
            )
            as Map<String, dynamic>;

    final profile = UserProfile.fromJson(json);

    expect(profile.storageUsedBytes, 734003200);
    expect(profile.storageQuotaBytes, 3149926400);
    expect(profile.storageRemainingBytes, 2415919104);
    expect(profile.imageCount, 128);
    expect(profile.hasStorageUsage, isTrue);
    expect(profile.storageUsageRatio, closeTo(734003200 / 3149926400, 1e-9));
  });

  test('formatBytes scales units', () {
    expect(formatBytes(0), '0 B');
    expect(formatBytes(512), '512 B');
    expect(formatBytes(1024), '1.0 KB');
    expect(formatBytes(734003200), '700 MB'); // ≥100 → no fraction
    expect(formatBytes(3149926400), '2.9 GB');
  });

  test('ratio clamps and handles missing data', () {
    const empty = UserProfile(
      id: 1,
      username: 'x',
      email: '',
      status: 'active',
      plan: 'free',
    );
    expect(empty.hasStorageUsage, isFalse);
    expect(empty.storageUsageRatio, isNull);

    const full = UserProfile(
      id: 1,
      username: 'x',
      email: '',
      status: 'active',
      plan: 'free',
      storageUsedBytes: 500,
      storageQuotaBytes: 100,
    );
    expect(full.storageUsageRatio, 1.0);
  });
}
