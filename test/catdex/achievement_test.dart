import 'package:catch_mobile/features/catdex/domain/achievement.dart';
import 'package:catch_mobile/features/catdex/domain/cat.dart';
import 'package:catch_mobile/features/catdex/domain/collection_summary.dart';
import 'package:flutter_test/flutter_test.dart';

Cat _cat(
  String id, {
  String? trait,
  String? collar,
  double? lat,
  double? lng,
}) =>
    Cat(
      id: id,
      name: 'Cat $id',
      traitId: trait,
      collarId: collar,
      lat: lat,
      lng: lng,
    );

CollectionSummary _summary(List<Cat> cats) => CollectionSummary.fromCats(cats);

void main() {
  group('Achievement', () {
    test('earned once current meets the goal', () {
      const a = Achievement(
        id: 'x',
        emoji: '🐾',
        title: 't',
        description: 'd',
        current: 5,
        goal: 5,
      );
      expect(a.earned, isTrue);
      expect(a.progress, 1.0);
    });

    test('progress clamps to 0..1 and label never exceeds the goal', () {
      const over = Achievement(
        id: 'x',
        emoji: '🐾',
        title: 't',
        description: 'd',
        current: 9,
        goal: 5,
      );
      expect(over.progress, 1.0); // clamped
      expect(over.progressLabel, '5 / 5'); // numerator clamped for display

      const part = Achievement(
        id: 'y',
        emoji: '🐾',
        title: 't',
        description: 'd',
        current: 2,
        goal: 5,
      );
      expect(part.earned, isFalse);
      expect(part.progress, closeTo(0.4, 1e-9));
      expect(part.progressLabel, '2 / 5');
    });

    test('a zero goal is treated as already complete, never locked', () {
      const z = Achievement(
        id: 'z',
        emoji: '🐾',
        title: 't',
        description: 'd',
        current: 0,
        goal: 0,
      );
      expect(z.earned, isTrue);
      expect(z.progress, 1.0);
    });
  });

  group('AchievementBook.evaluate', () {
    test('an empty collection earns nothing', () {
      final badges = AchievementBook.evaluate(_summary(const []));
      expect(badges, isNotEmpty);
      expect(badges.every((b) => !b.earned), isTrue);
      expect(AchievementBook.earnedCount(_summary(const [])), 0);
    });

    test('meeting one cat earns First Friend only', () {
      final s = _summary([_cat('a', trait: 'curious')]);
      final badges = AchievementBook.evaluate(s);
      final first = badges.firstWhere((b) => b.id == 'first_friend');
      expect(first.earned, isTrue);
      // Nothing needing 3+ of anything is earned yet.
      expect(badges.firstWhere((b) => b.id == 'growing_family').earned, isFalse);
      expect(AchievementBook.earnedCount(s), 1);
    });

    test('every known personality earns the rainbow badge', () {
      final cats = [
        for (final t in kKnownTraitIds) _cat(t, trait: t),
      ];
      final s = _summary(cats);
      final all = AchievementBook.evaluate(s)
          .firstWhere((b) => b.id == 'every_personality');
      expect(all.earned, isTrue);
      expect(all.goal, kKnownTraitIds.length);
    });

    test('styling three collars earns Stylist', () {
      final s = _summary([
        _cat('a', collar: 'red'),
        _cat('b', collar: 'blue'),
        _cat('c', collar: 'green'),
      ]);
      final stylist =
          AchievementBook.evaluate(s).firstWhere((b) => b.id == 'stylist');
      expect(stylist.earned, isTrue);
    });

    test('is deterministic in content and order', () {
      final cats = [_cat('a', trait: 'brave', collar: 'red', lat: 1, lng: 2)];
      final one = AchievementBook.evaluate(_summary(cats));
      final two = AchievementBook.evaluate(_summary(cats));
      expect(one.map((b) => b.id).toList(), two.map((b) => b.id).toList());
      for (var i = 0; i < one.length; i++) {
        expect(one[i].current, two[i].current);
        expect(one[i].goal, two[i].goal);
      }
    });

    test('no badge rewards spending or competition (care/collecting only)', () {
      // Guards the pillar: the catalogue ids are all about meeting, exploring,
      // and styling — never buying, racing, or beating someone.
      final ids =
          AchievementBook.evaluate(_summary(const [])).map((b) => b.id).toSet();
      const forbidden = {'purchase', 'spend', 'pvp', 'win', 'streak', 'rank'};
      expect(ids.intersection(forbidden), isEmpty);
    });
  });
}
