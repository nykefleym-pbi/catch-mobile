import 'package:catch_mobile/features/catdex/domain/cat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromMap parses tags, trims, and drops blanks', () {
    final cat = Cat.fromMap({
      'id': '1',
      'name': 'Milo',
      'tags': ['cute', '  ', 'sunny '],
    });
    expect(cat.tags, ['cute', 'sunny']);
  });

  test('a missing tags column yields an empty list', () {
    final cat = Cat.fromMap({'id': '1', 'name': 'Milo'});
    expect(cat.tags, isEmpty);
  });

  test('matchesQuery matches the name or any tag, case-insensitively', () {
    final cat = Cat.fromMap({
      'id': '1',
      'name': 'Milo',
      'tags': ['Sunbeam', 'porch cat'],
    });
    expect(cat.matchesQuery('mil'), isTrue); // name
    expect(cat.matchesQuery('SUN'), isTrue); // tag, case-insensitive
    expect(cat.matchesQuery('porch'), isTrue);
    expect(cat.matchesQuery('dog'), isFalse);
    expect(cat.matchesQuery(''), isTrue); // empty query matches all
  });
}
