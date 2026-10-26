import 'package:flutter_test/flutter_test.dart';
import 'package:fotoly_mobile/l10n/app_strings_de.dart';
import 'package:fotoly_mobile/l10n/app_strings_en.dart';
import 'package:fotoly_mobile/l10n/user_error_l10n.dart';
import 'package:fotoly_mobile/services/auth_errors.dart';
import 'package:fotoly_mobile/services/backup_errors.dart';

void main() {
  const de = AppStringsDe();
  const en = AppStringsEn();

  test('wrong password from the API is German', () {
    expect(
      localizeUserError(
        de,
        'Invalid email or password',
        fallback: de.loginFailed,
      ),
      'E-Mail oder Passwort ist falsch.',
    );
  });

  test('client auth codes stay out of the UI', () {
    expect(
      localizeUserError(
        de,
        AuthErrorCodes.credentialsRequired,
        fallback: de.loginFailed,
      ),
      de.enterEmailPassword,
    );
    expect(
      localizeUserError(
        en,
        AuthErrorCodes.apiKeyRequired,
        fallback: en.loginFailed,
      ),
      en.enterApiKey,
    );
  });

  test('known API and backup messages map in both languages', () {
    expect(
      localizeUserError(
        de,
        'Email is already registered',
        fallback: de.registrationFailed,
      ),
      de.emailAlreadyRegistered,
    );
    expect(
      localizeUserError(
        de,
        'Please activate your account via email.',
        fallback: de.loginFailed,
      ),
      de.accountNotActivated,
    );
    expect(
      localizeUserError(
        en,
        'Invalid API key — check the key in your Fotoly settings',
        fallback: en.galleryLoadError,
      ),
      contains('Invalid API key'),
    );
    expect(
      localizeUserError(en, 'Could not load images', fallback: en.genericError),
      en.galleryLoadError,
    );
    expect(
      localizeUserError(
        de,
        BackupErrorCodes.uploadsFailed,
        fallback: de.genericError,
      ),
      de.someUploadsFailed,
    );
    expect(
      localizeUserError(de, '2 of 5 uploads failed', fallback: de.genericError),
      de.someUploadsFailed,
    );
    expect(
      localizeUserError(
        de,
        BackupErrorCodes.scanFailed,
        fallback: de.genericError,
      ),
      de.scanFailed,
    );
  });

  test('technical exceptions use the fallback', () {
    expect(
      localizeUserError(
        de,
        'ClientException: Connection refused',
        fallback: de.loginFailed,
      ),
      de.networkError,
    );
    expect(
      localizeUserError(
        de,
        'FormatException: bad json',
        fallback: de.loginFailed,
      ),
      de.loginFailed,
    );
    expect(
      localizeUserError(de, null, fallback: de.loginFailed),
      de.loginFailed,
    );
  });
}
