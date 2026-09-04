import 'package:flutter_test/flutter_test.dart';
import 'package:fotoly_mobile/utils/gravatar.dart';

void main() {
  test(
    'hashEmail trims, lowercases, and SHA-256 hashes (Gravatar docs sample)',
    () {
      // https://docs.gravatar.com/general/hash/
      expect(
        Gravatar.hashEmail('MyEmailAddress@example.com '),
        '84059b07d4be67b806386c0aad8070a23f18836bbaae342275dc0a83414c32ee',
      );
      expect(
        Gravatar.hashEmail('myemailaddress@example.com'),
        '84059b07d4be67b806386c0aad8070a23f18836bbaae342275dc0a83414c32ee',
      );
    },
  );

  test('imageUrl builds https gravatar path with size and default', () {
    final url = Gravatar.imageUrl(
      'myemailaddress@example.com',
      size: 104,
      defaultImage: 'mp',
    );
    expect(
      url,
      startsWith(
        'https://www.gravatar.com/avatar/'
        '84059b07d4be67b806386c0aad8070a23f18836bbaae342275dc0a83414c32ee',
      ),
    );
    expect(url, contains('s=104'));
    expect(url, contains('d=mp'));
    expect(url, contains('r=g'));
  });
}
