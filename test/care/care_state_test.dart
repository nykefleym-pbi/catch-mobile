import 'package:catch_mobile/features/care/domain/care_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CareState', () {
    test('a fresh cat starts perfectly content', () {
      final care = CareState.initial('cat-1');
      expect(care.currentHunger, 100);
      expect(care.currentHappiness, 100);
      expect(care.currentMood, 'Blissful');
    });

    test('needs decay gently over time', () {
      final care = CareState(
        catId: 'cat-1',
        hunger: 100,
        happiness: 100,
        mood: 'content',
        lastUpdated: DateTime.now().subtract(const Duration(hours: 10)),
      );
      // ~3 points/hour → 100 - 30 = 70.
      expect(care.currentHunger, 70);
      expect(care.currentHappiness, 70);
    });

    test('decay never bottoms out below the non-punitive floor', () {
      final care = CareState(
        catId: 'cat-1',
        hunger: 100,
        happiness: 100,
        mood: 'content',
        lastUpdated: DateTime.now().subtract(const Duration(days: 30)),
      );
      expect(care.currentHunger, 30);
      expect(care.currentHappiness, 30);
    });

    test('feeding fills hunger and lifts happiness from the decayed value', () {
      final care = CareState(
        catId: 'cat-1',
        hunger: 50,
        happiness: 40,
        mood: 'restless',
        lastUpdated: DateTime.now().subtract(const Duration(hours: 10)),
      );
      // happiness decays 40 -> 30 (floor), then +5 on feed.
      final fed = care.fed();
      expect(fed.hunger, 100);
      expect(fed.happiness, 35);
    });

    test('playing tops up happiness', () {
      final care = CareState(
        catId: 'cat-1',
        hunger: 80,
        happiness: 40,
        mood: 'restless',
        lastUpdated: DateTime.now(),
      );
      final played = care.played();
      expect(played.happiness, 100);
      expect(played.hunger, 80);
    });

    test('fromMap tolerates missing fields', () {
      final care = CareState.fromMap({'cat_id': 'cat-9'});
      expect(care.catId, 'cat-9');
      expect(care.hunger, 100);
      expect(care.happiness, 100);
    });
  });
}
