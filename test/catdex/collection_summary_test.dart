import 'package:catch_mobile/features/catdex/domain/cat.dart';
import 'package:catch_mobile/features/catdex/domain/collection_summary.dart';
import 'package:flutter_test/flutter_test.dart';

Cat _cat(
  String id, {
  String? trait,
  String? collar,
  double? lat,
  double? lng,
  DateTime? discovered,
}) =>
    Cat(
      id: id,
      name: 'Cat $id',
      traitId: trait,
      collarId: collar,
      lat: lat,
      lng: lng,
      discoveredAt: discovered,
    );

void main() {
  group('CollectionSummary.fromCats', () {
    test('empty collection reports zeros and known-trait denominator', () {
      final s = CollectionSummary.fromCats(const []);
      expect(s.isEmpty, isTrue);
      expect(s.totalCats, 0);
      expect(s.traitsCollected, 0);
      expect(s.traitsKnown, kKnownTraitIds.length);
      expect(s.placesMet, 0);
      expect(s.collarsStyled, 0);
      expect(s.firstMet, isNull);
      expect(s.latestMet, isNull);
      expect(s.traitProgress, 0);
    });

    test('counts totals, distinct traits, places and collars', () {
      final cats = [
        _cat('a', trait: 'curious', collar: 'red', lat: 1, lng: 2),
        _cat('b', trait: 'curious', collar: 'blue'), // dup trait
        _cat('c', trait: 'brave', lat: 3, lng: 4),
        _cat('d', collar: 'red'), // dup collar, no trait, no place
      ];
      final s = CollectionSummary.fromCats(cats);
      expect(s.totalCats, 4);
      expect(s.traitsCollected, 2); // curious + brave
      expect(s.placesMet, 2); // a + c
      expect(s.collarsStyled, 2); // red + blue
    });

    test('unknown server-side traits do not count toward collected', () {
      final s = CollectionSummary.fromCats([
        _cat('a', trait: 'sparkly'), // not in kKnownTraitIds
        _cat('b', trait: 'lazy'),
      ]);
      expect(s.traitsCollected, 1);
    });

    test('firstMet is earliest and latestMet is newest by discovery time', () {
      final cats = [
        _cat('mid', discovered: DateTime(2026, 5, 1)),
        _cat('old', discovered: DateTime(2026, 1, 1)),
        _cat('new', discovered: DateTime(2026, 9, 1)),
      ];
      final s = CollectionSummary.fromCats(cats);
      expect(s.firstMet?.id, 'old');
      expect(s.latestMet?.id, 'new');
    });

    test('traitProgress is fraction of known traits met', () {
      final cats = [
        for (final t in kKnownTraitIds.take(5)) _cat(t, trait: t),
      ];
      final s = CollectionSummary.fromCats(cats);
      expect(s.traitsCollected, 5);
      expect(s.traitProgress, closeTo(5 / kKnownTraitIds.length, 1e-9));
    });

    test('is deterministic for the same input', () {
      final cats = [
        _cat('a', trait: 'curious', lat: 1, lng: 2),
        _cat('b', trait: 'brave'),
      ];
      final a = CollectionSummary.fromCats(cats);
      final b = CollectionSummary.fromCats(cats);
      expect(a.totalCats, b.totalCats);
      expect(a.traitsCollected, b.traitsCollected);
      expect(a.placesMet, b.placesMet);
      expect(a.collarsStyled, b.collarsStyled);
    });
  });
}
