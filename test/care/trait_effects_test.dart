import 'package:catch_mobile/features/care/domain/care_state.dart';
import 'package:catch_mobile/features/care/domain/trait_effects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TraitCareEffects', () {
    test('null and unknown traits are the identity baseline', () {
      expect(TraitCareEffects.forTrait(null), same(TraitCareEffects.baseline));
      expect(TraitCareEffects.forTrait('made_up'),
          same(TraitCareEffects.baseline));
    });

    test('baseline is neutral (no modulation)', () {
      const b = TraitCareEffects.baseline;
      expect(b.hungerDecayMult, 1.0);
      expect(b.happinessDecayMult, 1.0);
      expect(b.hygieneDecayMult, 1.0);
      expect(b.playDecayMult, 1.0);
      expect(b.sleepRegenMult, 1.0);
      expect(b.feedBondBonus, 0);
      expect(b.feedHappinessBonus, 0);
      expect(b.playBondBonus, 0);
      expect(b.groomBondBonus, 0);
      expect(b.groomHappinessBonus, 0);
    });

    test('known traits carry their signature nudges', () {
      final foodie = TraitCareEffects.forTrait('foodie');
      expect(foodie.feedHappinessBonus, 3);
      expect(foodie.feedBondBonus, 1);

      final lazy = TraitCareEffects.forTrait('lazy');
      expect(lazy.sleepRegenMult, greaterThan(1.0));
      expect(lazy.playDecayMult, lessThan(1.0));
    });

    test('welfare invariant: no trait ever makes care harsher', () {
      for (final id in const [
        'foodie',
        'lazy',
        'playful',
        'brave',
        'curious',
        'elegant',
        'mischievous',
        'protective',
        'explorer',
        'shy',
      ]) {
        final e = TraitCareEffects.forTrait(id);
        // Decay can only slow (<= 1.0); sleep recovery can only speed (>= 1.0).
        expect(e.hungerDecayMult, lessThanOrEqualTo(1.0), reason: id);
        expect(e.happinessDecayMult, lessThanOrEqualTo(1.0), reason: id);
        expect(e.hygieneDecayMult, lessThanOrEqualTo(1.0), reason: id);
        expect(e.playDecayMult, lessThanOrEqualTo(1.0), reason: id);
        expect(e.sleepRegenMult, greaterThanOrEqualTo(1.0), reason: id);
        // Action bonuses can only add.
        expect(e.feedBondBonus, greaterThanOrEqualTo(0), reason: id);
        expect(e.feedHappinessBonus, greaterThanOrEqualTo(0), reason: id);
        expect(e.playBondBonus, greaterThanOrEqualTo(0), reason: id);
        expect(e.groomBondBonus, greaterThanOrEqualTo(0), reason: id);
        expect(e.groomHappinessBonus, greaterThanOrEqualTo(0), reason: id);
      }
    });
  });

  group('CareState personality modulation', () {
    test('a trait-less cat behaves exactly as the baseline', () {
      final care = CareState(
        catId: 'c',
        hunger: 100,
        happiness: 100,
        play: 100,
        mood: 'content',
        lastUpdated: DateTime.now().subtract(const Duration(hours: 10)),
      );
      expect(care.currentPlay, 80); // 2/hour * 10h
    });

    test('a lazy cat frets less about play (slower drift)', () {
      final lazy = CareState(
        catId: 'c',
        hunger: 100,
        happiness: 100,
        play: 100,
        mood: 'content',
        lastUpdated: DateTime.now().subtract(const Duration(hours: 10)),
        traitId: 'lazy',
      );
      // playDecayMult 0.7 -> 1.4/hour * 10h = 14 -> 86 (vs 80 baseline).
      expect(lazy.currentPlay, 86);
    });

    test('a foodie gains a little extra from feeding (never less)', () {
      CareState make(String? trait) => CareState(
            catId: 'c',
            hunger: 50,
            happiness: 40,
            mood: 'restless',
            lastUpdated: DateTime.now().subtract(const Duration(hours: 10)),
            friendship: 4,
            traitId: trait,
          );
      final plain = make(null).fed();
      final foodie = make('foodie').fed();
      expect(foodie.happiness, greaterThan(plain.happiness));
      expect(foodie.friendship, greaterThan(plain.friendship));
      // Concretely: happiness 30(floor)+5+3 = 38; bond 4+1+1 = 6.
      expect(foodie.happiness, 38);
      expect(foodie.friendship, 6);
    });

    test('care actions preserve the trait for future modulation', () {
      final care = CareState(
        catId: 'c',
        hunger: 100,
        happiness: 100,
        mood: 'content',
        lastUpdated: DateTime.now(),
        traitId: 'shy',
      );
      expect(care.groomed().traitId, 'shy');
      expect(care.played().traitId, 'shy');
      expect(care.fed().traitId, 'shy');
    });
  });
}
