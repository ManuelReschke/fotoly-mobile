import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fotoly_mobile/models/pixelfox_image.dart';

void main() {
  late Map<String, dynamic> fixture;

  setUpAll(() {
    fixture = jsonDecode(File('test/fixtures/images_list.json').readAsStringSync())
        as Map<String, dynamic>;
  });

  test('parses list fixture items and page cursor', () {
    final page = PixelfoxImagePage.fromJson(fixture);
    expect(page.items, hasLength(2));
    expect(page.hasMore, isTrue);
    expect(page.nextCursor, 'cursor-page-2');
    expect(page.items.first.imageUuid, 'fd6b0a44-c4bb-4c95-8f48-31d5ec9cc4d8');
    expect(page.items.first.title, 'Sunset');
    expect(page.items.first.fileName, 'sunset.jpg');
    expect(page.items.first.width, 4000);
    expect(page.items.first.isNsfw, isFalse);
    expect(page.items.last.isNsfw, isTrue);
    expect(
      page.items.first.stableUrl,
      'https://pixelfox.cc/f/fd6b0a44-c4bb-4c95-8f48-31d5ec9cc4d8/original/original.jpg',
    );
  });

  test('tryParse returns null without uuid or stable_url', () {
    expect(PixelfoxImage.tryParse({'title': 'x'}), isNull);
    expect(
      PixelfoxImage.tryParse({'image_uuid': 'u', 'stable_url': ''}),
      isNull,
    );
    expect(
      PixelfoxImage.tryParse({
        'image_uuid': 'u',
        'stable_url': 'https://pixelfox.cc/f/u/original/original.jpg',
      }),
      isNotNull,
    );
  });

  test('fromJson page skips incomplete items', () {
    final page = PixelfoxImagePage.fromJson({
      'items': [
        {'title': 'bad'},
        {
          'image_uuid': 'ok',
          'stable_url': 'https://pixelfox.cc/f/ok/original/original.jpg',
        },
      ],
      'has_more': false,
    });
    expect(page.items, hasLength(1));
    expect(page.items.single.imageUuid, 'ok');
    expect(page.hasMore, isFalse);
    expect(page.nextCursor, isNull);
  });
}
