import 'package:flutter/foundation.dart';

import '../../care/domain/care_state.dart';

/// The six friendly-contest stats (04-game-systems §Friendly PvP). They exist so
/// a cat has a *character* in playful, no-harm contests — never a combat rating.
enum CatStat { agility, speed, confidence, curiosity, energy, cuteness }

/// A cat's friendly-contest profile.
///
/// **No-pay-to-win is structural here, not a promise.** [derive] takes only care
/// wellbeing, the permanent bond, growth stage, and personality — there is
/// deliberately *no* item, currency, or purchase parameter anywhere in the
/// signature, so no amount of spending can move a stat (04-game-systems: "Stats
/// derive from care, growth stage, personality, and player choices — not from
/// purchasable power"). `test/pvp/cat_stats_test.dart` guards this.
@immutable
class CatStats {
  const CatStats({
    required this.agility,
    required this.speed,
    required this.confidence,
    required this.curiosity,
    required this.energy,
    required this.cuteness,
  });

  final int agility;
  final int speed;
  final int confidence;
  final int curiosity;
  final int energy;
  final int cuteness;

  int operator [](CatStat s) => switch (s) {
        CatStat.agility => agility,
        CatStat.speed => speed,
        CatStat.confidence => confidence,
        CatStat.curiosity => curiosity,
        CatStat.energy => energy,
        CatStat.cuteness => cuteness,
      };

  /// Derive a stat profile from the things a caring player actually influences.
  /// [hunger]/[happiness]/[hygiene]/[play]/[sleep] are the *current* (drifted)
  /// need values (0–100); [friendship] is the permanent bond; [growthStage] is
  /// one of kitten/young/adult/senior; [traitId] is the cat's personality trait.
  factory CatStats.derive({
    required int friendship,
    required String growthStage,
    String? traitId,
    required int hunger,
    required int happiness,
    required int hygiene,
    required int play,
    required int sleep,
  }) {
    // Wellbeing: a well-cared-for cat brings more to a friendly contest.
    final wellbeing = (hunger + happiness + hygiene + play + sleep) / 5.0;
    // The permanent bond gives a steady, earned lift (kindness, not spending).
    final bondBonus = Bond.levelIndexFor(friendship) * 4.0;
    final base = wellbeing * 0.6 + bondBonus;

    final growth = _growthDeltas[growthStage] ?? _growthDeltas['adult']!;
    final trait = _traitDeltas[traitId] ?? const {};

    int stat(CatStat s) {
      final value = base + (growth[s] ?? 0) + (trait[s] ?? 0);
      return value.round().clamp(1, 100);
    }

    return CatStats(
      agility: stat(CatStat.agility),
      speed: stat(CatStat.speed),
      confidence: stat(CatStat.confidence),
      curiosity: stat(CatStat.curiosity),
      energy: stat(CatStat.energy),
      cuteness: stat(CatStat.cuteness),
    );
  }

  /// Convenience: derive straight from a [CareState] using its current values.
  factory CatStats.fromCare(
    CareState care, {
    required String growthStage,
    String? traitId,
  }) =>
      CatStats.derive(
        friendship: care.friendship,
        growthStage: growthStage,
        traitId: traitId,
        hunger: care.currentHunger,
        happiness: care.currentHappiness,
        hygiene: care.currentHygiene,
        play: care.currentPlay,
        sleep: care.currentSleep,
      );
}

/// Growth stages shift the profile while identity persists (04 §Growth): a
/// kitten is bouncy and adorable, a senior calm and self-assured.
const Map<String, Map<CatStat, int>> _growthDeltas = {
  'kitten': {
    CatStat.agility: 8,
    CatStat.speed: 4,
    CatStat.confidence: -6,
    CatStat.curiosity: 8,
    CatStat.energy: 10,
    CatStat.cuteness: 12,
  },
  'young': {
    CatStat.agility: 6,
    CatStat.speed: 6,
    CatStat.curiosity: 4,
    CatStat.energy: 8,
    CatStat.cuteness: 6,
  },
  'adult': {
    CatStat.agility: 4,
    CatStat.speed: 6,
    CatStat.confidence: 8,
    CatStat.curiosity: 2,
    CatStat.energy: 4,
    CatStat.cuteness: 2,
  },
  'senior': {
    CatStat.agility: -2,
    CatStat.speed: -4,
    CatStat.confidence: 12,
    CatStat.curiosity: 2,
    CatStat.energy: -4,
    CatStat.cuteness: 8,
  },
};

/// Personality gives flavour, not a stat ladder (04 §Personality "variety and
/// flavour, not a stat ladder"). Deltas mirror the doc's examples (an Explorer
/// does better in treasure hunts, a Lazy cat is slower, etc.).
const Map<String, Map<CatStat, int>> _traitDeltas = {
  'curious': {CatStat.curiosity: 12, CatStat.agility: 4},
  'brave': {CatStat.confidence: 12, CatStat.speed: 4},
  'lazy': {CatStat.cuteness: 10, CatStat.energy: -8, CatStat.speed: -6},
  'foodie': {CatStat.cuteness: 8, CatStat.energy: 4},
  'mischievous': {CatStat.agility: 10, CatStat.curiosity: 6},
  'elegant': {CatStat.cuteness: 12, CatStat.confidence: 6},
  'playful': {CatStat.energy: 12, CatStat.agility: 6},
  'protective': {CatStat.confidence: 10, CatStat.speed: 4},
  'explorer': {CatStat.curiosity: 12, CatStat.speed: 6, CatStat.energy: 4},
  'shy': {CatStat.cuteness: 8, CatStat.confidence: -6, CatStat.curiosity: 4},
};
