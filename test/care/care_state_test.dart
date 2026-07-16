import 'package:catch_mobile/features/care/domain/care_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CareState needs', () {
    test('a fresh cat starts perfectly content', () {
      final care = CareState.initial('cat-1');
      expect(care.currentHunger, 100);
      expect(care.currentHappiness, 100);
      expect(care.currentMood, 'Blissful');
      expect(care.friendship, 0);
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

    test('fromMap tolerates missing fields and carries friendship', () {
      final care = CareState.fromMap(const {'cat_id': 'cat-9'}, friendship: 7);
      expect(care.catId, 'cat-9');
      expect(care.hunger, 100);
      expect(care.happiness, 100);
      expect(care.friendship, 7);
    });
  });

  group('CareState actions', () {
    test('feeding fills hunger, lifts happiness, and bonds +1', () {
      final care = CareState(
        catId: 'cat-1',
        hunger: 50,
        happiness: 40,
        mood: 'restless',
        lastUpdated: DateTime.now().subtract(const Duration(hours: 10)),
        friendship: 4,
      );
      // happiness decays 40 -> 30 (floor), then +5 on a plain feed.
      final fed = care.fed();
      expect(fed.hunger, 100);
      expect(fed.happiness, 35);
      expect(fed.friendship, 5);
    });

    test('a richer treat grants more bond and happiness', () {
      final care = CareState(
        catId: 'cat-1',
        hunger: 50,
        happiness: 40,
        mood: 'restless',
        lastUpdated: DateTime.now().subtract(const Duration(hours: 10)),
        friendship: 4,
      );
      // happiness decays 40 -> 30, then +7; bond +3.
      final fed = care.fed(bondGain: 3, happinessGain: 7);
      expect(fed.hunger, 100);
      expect(fed.happiness, 37);
      expect(fed.friendship, 7);
    });

    test('playing tops up happiness and bonds +2', () {
      final care = CareState(
        catId: 'cat-1',
        hunger: 80,
        happiness: 40,
        mood: 'restless',
        lastUpdated: DateTime.now(),
        friendship: 4,
      );
      final played = care.played();
      expect(played.happiness, 100);
      expect(played.hunger, 80);
      expect(played.friendship, 6);
    });
  });

  group('Bond', () {
    test('labels climb with friendship points', () {
      expect(Bond.labelFor(0), 'New Friend');
      expect(Bond.labelFor(6), 'Familiar');
      expect(Bond.labelFor(30), 'Pal');
      expect(Bond.labelFor(500), 'Kindred Spirit');
    });

    test('reports the max tier', () {
      expect(Bond.isMax(50), isFalse);
      expect(Bond.isMax(120), isTrue);
      expect(Bond.isMax(999), isTrue);
    });

    test('progress runs 0..1 within a tier and is full at max', () {
      expect(Bond.progressFor(0), 0.0);
      expect(Bond.progressFor(3), closeTo(0.5, 0.0001)); // halfway 0 -> 6
      expect(Bond.progressFor(120), 1.0);
    });
  });
}
