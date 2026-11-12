import 'package:flutter_test/flutter_test.dart';
import 'package:fotoly_mobile/models/upload_size_policy.dart';
import 'package:fotoly_mobile/services/backup_errors.dart';
import 'package:fotoly_mobile/services/backup_ledger.dart';
import 'package:fotoly_mobile/services/file_scanner.dart';
import 'package:fotoly_mobile/services/pixelfox_api_client.dart';

const _free = 25 * 1024 * 1024;

LocalImageFile _file(String name, int size) =>
    LocalImageFile(path: '/photos/$name', name: name, sizeBytes: size);

void main() {
  test('files over the plan limit are blocked and stay out of pending', () {
    final small = _file('small.jpg', _free);
    final collage = _file('collage.jpg', _free + 1);
    final saved = _file('saved.jpg', _free + 500);

    final groups = splitBackupFiles(
      files: [small, collage, saved],
      isBackedUp: (file) => file.path == saved.path,
      maxUploadBytes: _free,
    );

    expect(groups.pending.map((file) => file.name), ['small.jpg']);
    expect(groups.tooLarge.map((file) => file.name), ['collage.jpg']);
    expect(groups.secured.map((file) => file.name), ['saved.jpg']);
  });

  test('unknown plan limit leaves every new file pending', () {
    final collage = _file('collage.jpg', 80 * 1024 * 1024);
    final groups = splitBackupFiles(
      files: [collage],
      isBackedUp: (_) => false,
      maxUploadBytes: null,
    );

    expect(groups.pending, [collage]);
    expect(groups.tooLarge, isEmpty);
  });

  test('offer follows the smallest paid plan that can take the files', () {
    final premium = offerForOversizedFiles([
      _file('a.jpg', 30 * 1024 * 1024),
      _file('b.jpg', kPremiumUploadBytes),
    ]);
    expect(premium.plan, HigherUploadPlan.premium);
    expect(premium.beyondEveryPlan, 0);

    final max = offerForOversizedFiles([
      _file('a.jpg', 30 * 1024 * 1024),
      _file('b.jpg', kPremiumUploadBytes + 1),
    ]);
    expect(max.plan, HigherUploadPlan.premiumMax);
    expect(max.beyondEveryPlan, 0);

    final mixed = offerForOversizedFiles([
      _file('a.jpg', 40 * 1024 * 1024),
      _file('b.jpg', kPremiumMaxUploadBytes + 1),
    ]);
    expect(mixed.plan, HigherUploadPlan.premium);
    expect(mixed.beyondEveryPlan, 1);

    final none = offerForOversizedFiles([
      _file('huge.jpg', kPremiumMaxUploadBytes + 1),
    ]);
    expect(none.plan, isNull);
    expect(none.beyondEveryPlan, 1);
    expect(none.hasUpsell, isFalse);
  });

  test('a remembered server block stays until the profile limit grows', () {
    final collage = _file('collage.jpg', 100);
    final blocked = {fingerprintFor(collage)};

    final stillBlocked = splitBackupFiles(
      files: [collage],
      isBackedUp: (_) => false,
      maxUploadBytes: kPremiumUploadBytes,
      isBlocked: (file) => blocked.contains(fingerprintFor(file)),
    );
    expect(stillBlocked.tooLarge, [collage]);
    expect(stillBlocked.pending, isEmpty);

    final released = splitBackupFiles(
      files: [collage],
      isBackedUp: (_) => false,
      maxUploadBytes: kPremiumUploadBytes,
    );
    expect(released.pending, [collage]);
  });

  test('session size errors are the plan limit, quota errors are not', () {
    expect(
      isUploadTooLargeError(
        PixelfoxApiException('File exceeds session max_bytes (26214400)'),
      ),
      isTrue,
    );
    expect(
      isUploadTooLargeError(
        PixelfoxApiException(
          'Upload failed',
          statusCode: 413,
          body: '{"error":"payload_too_large","message":"file too large"}',
        ),
      ),
      isTrue,
    );
    expect(
      isUploadTooLargeError(
        PixelfoxApiException(
          'Upload failed',
          statusCode: 413,
          body: '{"error":"quota_exceeded"}',
        ),
      ),
      isFalse,
    );
    expect(
      maxBytesFromUploadError(
        PixelfoxApiException('File exceeds session max_bytes (26214400)'),
      ),
      26214400,
    );
  });
}
