import 'package:catch_mobile/features/catdex/domain/cat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cat.fromMap location', () {
    test('parses coarse geo coordinates', () {
      final cat = Cat.fromMap(const {
        'id': 'c1',
        'name': 'Clover',
        'geo_lat': 37.77,
        'geo_lng': -122.42,
      });

      expect(cat.lat, 37.77);
      expect(cat.lng, -122.42);
      expect(cat.hasLocation, isTrue);
    });

    test('accepts integer / string coordinates over the wire', () {
      final cat = Cat.fromMap(const {
        'id': 'c2',
        'name': 'Pepper',
        'geo_lat': 40,
        'geo_lng': '-73.5',
      });

      expect(cat.lat, 40.0);
      expect(cat.lng, -73.5);
      expect(cat.hasLocation, isTrue);
    });

    test('has no location when coordinates are absent', () {
      final cat = Cat.fromMap(const {'id': 'c3', 'name': 'Tofu'});

      expect(cat.lat, isNull);
      expect(cat.lng, isNull);
      expect(cat.hasLocation, isFalse);
    });

    test('has no location when only one coordinate is present', () {
      final cat = Cat.fromMap(const {
        'id': 'c4',
        'name': 'Nimbus',
        'geo_lat': 37.77,
      });

      expect(cat.hasLocation, isFalse);
    });
  });
}
