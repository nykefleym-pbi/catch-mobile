import 'package:catch_mobile/features/pvp/domain/cat_stats.dart';
import 'package:flutter_test/flutter_test.dart';

CatStats _derive({
  int friendship = 0,
  String growth = 'adult',
  String? trait,
  int need = 100,
}) =>
    CatStats.derive(
      friendship: friendship,
      growthStage: growth,
      traitId: trait,
      hunger: need,
      happiness: need,
      hygiene: need,
      play: need,
      sleep: need,
    );

void main() {
  group('CatStats.derive — provably no pay-to-win', () {
    test('is deterministic for identical inputs', () {
      final a = _derive(friendship: 30, trait: 'playful');
      final b = _derive(friendship: 30, trait: 'playful');
      expect(a.agility, b.agility);
      expect(a.energy, b.energy);
      expect(a.cuteness, b.cuteness);
    });

    test('better care yields higher stats', () {
      final neglected = _derive(need: 30);
      final adored = _derive(need: 100);
      // Every stat should be at least as high with full care; energy clearly so.
      expect(adored.energy, greaterThan(neglected.energy));
      expect(adored.agility, greaterThanOrEqualTo(neglected.agility));
    });

    test('a deeper bond raises stats (kindness, not spending)', () {
      final newFriend = _derive(friendship: 0);
      final kindred = _derive(friendship: 120);
      expect(kindred.confidence, greaterThan(newFriend.confidence));
      expect(kindred.speed, greaterThanOrEqualTo(newFriend.speed));
    });

    test('stats stay within 1..100', () {
      final maxed = _derive(friendship: 999, need: 100, trait: 'explorer');
      for (final s in CatStat.values) {
        expect(maxed[s], inInclusiveRange(1, 100));
      }
      final floored = _derive(friendship: 0, need: 30, trait: 'lazy');
      for (final s in CatStat.values) {
        expect(floored[s], inInclusiveRange(1, 100));
      }
    });

    test('personality shifts flavour without a purchasable lever', () {
      final plain = _derive(friendship: 20);
      final playful = _derive(friendship: 20, trait: 'playful');
      final explorer = _derive(friendship: 20, trait: 'explorer');
      expect(playful.energy, greaterThan(plain.energy));
      expect(explorer.curiosity, greaterThan(plain.curiosity));
      // There is no money/item parameter on derive at all — the only inputs are
      // care, bond, growth, and personality. This test documents that contract.
    });
  });
}
