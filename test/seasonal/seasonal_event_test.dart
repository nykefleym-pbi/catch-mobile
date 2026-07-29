import 'package:catch_mobile/features/nook/domain/decor.dart';
import 'package:catch_mobile/features/seasonal/domain/seasonal_event.dart';
import 'package:catch_mobile/features/wardrobe/domain/collar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('activeSeasonalEvent', () {
    test('January resolves to Winter Hush', () {
      expect(activeSeasonalEvent(DateTime(2026, 1, 15)).id, 'winter');
    });

    test('April resolves to Spring Blossoms', () {
      expect(activeSeasonalEvent(DateTime(2026, 4, 15)).id, 'spring');
    });

    test('July resolves to Summer Sunbeams', () {
      expect(activeSeasonalEvent(DateTime(2026, 7, 15)).id, 'summer');
    });

    test('October resolves to Autumn Leaves', () {
      expect(activeSeasonalEvent(DateTime(2026, 10, 15)).id, 'autumn');
    });

    test('December resolves to Winter Hush', () {
      expect(activeSeasonalEvent(DateTime(2026, 12, 25)).id, 'winter');
    });

    test('is deterministic for the same input', () {
      final a = activeSeasonalEvent(DateTime(2026, 6, 1));
      final b = activeSeasonalEvent(DateTime(2026, 6, 1));
      expect(a.id, b.id);
      expect(a.name, b.name);
    });

    test('every season has non-empty featured lists that resolve', () {
      for (final month in [1, 4, 7, 10]) {
        final event = activeSeasonalEvent(DateTime(2026, month, 1));
        expect(event.featuredCollarIds, isNotEmpty);
        expect(event.featuredDecorIds, isNotEmpty);
        for (final id in event.featuredCollarIds) {
          expect(collarById(id), isNotNull, reason: 'collar id $id');
        }
        for (final id in event.featuredDecorIds) {
          expect(decorById(id), isNotNull, reason: 'decor id $id');
        }
      }
    });
  });
}
