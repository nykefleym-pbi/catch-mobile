import 'package:catch_mobile/features/pvp/domain/cat_stats.dart';
import 'package:catch_mobile/features/pvp/domain/contest_resolution.dart';
import 'package:catch_mobile/features/pvp/domain/match.dart';
import 'package:flutter_test/flutter_test.dart';

/// Build a stat set by overriding just the governing stats we care about, so a
/// test can pit a fast cat against a slow one without fighting the derive maths.
CatStats _stats({
  int agility = 50,
  int speed = 50,
  int confidence = 50,
  int curiosity = 50,
  int energy = 50,
  int cuteness = 50,
}) =>
    CatStats(
      agility: agility,
      speed: speed,
      confidence: confidence,
      curiosity: curiosity,
      energy: energy,
      cuteness: cuteness,
    );

void main() {
  group('ContestResolver.resolve — deterministic, no pay-to-win', () {
    test('the higher governing stat wins its event', () {
      // Zoomie race is decided on speed.
      final r = ContestResolver.resolve(
        MatchMode.zoomies,
        challenger: _stats(speed: 80),
        opponent: _stats(speed: 40),
      );
      expect(r.winner, ContestParty.challenger);
      expect(r.decidedBy, CatStat.speed);
      expect(r.challengerScore, 80);
      expect(r.opponentScore, 40);
      expect(r.isDraw, isFalse);
    });

    test('each mode turns on its own stat, not another', () {
      // A cat with monster speed but poor curiosity loses a treasure hunt.
      final r = ContestResolver.resolve(
        MatchMode.treasure,
        challenger: _stats(speed: 99, curiosity: 20),
        opponent: _stats(speed: 1, curiosity: 60),
      );
      expect(r.winner, ContestParty.opponent);
      expect(r.decidedBy, CatStat.curiosity);
    });

    test('is symmetric — swapping the cats mirrors the result', () {
      final a = _stats(energy: 70);
      final b = _stats(energy: 30);
      final forward = ContestResolver.resolve(
        MatchMode.toy,
        challenger: a,
        opponent: b,
      );
      final swapped = ContestResolver.resolve(
        MatchMode.toy,
        challenger: b,
        opponent: a,
      );
      expect(forward.winner, ContestParty.challenger);
      expect(swapped.winner, ContestParty.opponent);
    });

    test('a tie on the event stat is broken by all-round care (total)', () {
      // Equal agility, but the challenger is better cared-for overall.
      final r = ContestResolver.resolve(
        MatchMode.agility,
        challenger: _stats(agility: 50, cuteness: 90),
        opponent: _stats(agility: 50, cuteness: 10),
      );
      expect(r.winner, ContestParty.challenger);
      expect(r.decidedBy, CatStat.cuteness);
    });

    test('two identical cats draw — a happy, loser-free result', () {
      final r = ContestResolver.resolve(
        MatchMode.zoomies,
        challenger: _stats(),
        opponent: _stats(),
      );
      expect(r.winner, ContestParty.draw);
      expect(r.isDraw, isTrue);
    });

    test('is deterministic — identical inputs always give the same result', () {
      final a = _stats(speed: 61, cuteness: 44);
      final b = _stats(speed: 61, cuteness: 43);
      final first = ContestResolver.resolve(
        MatchMode.zoomies,
        challenger: a,
        opponent: b,
      );
      final second = ContestResolver.resolve(
        MatchMode.zoomies,
        challenger: a,
        opponent: b,
      );
      expect(first.winner, second.winner);
      expect(first.decidedBy, second.decidedBy);
      expect(first.challengerScore, second.challengerScore);
    });
  });

  group('MatchMode.governingStat — every mode maps to its play skill', () {
    test('modes decide on the stat their event rewards', () {
      expect(MatchMode.zoomies.governingStat, CatStat.speed);
      expect(MatchMode.agility.governingStat, CatStat.agility);
      expect(MatchMode.treasure.governingStat, CatStat.curiosity);
      expect(MatchMode.toy.governingStat, CatStat.energy);
    });
  });
}
