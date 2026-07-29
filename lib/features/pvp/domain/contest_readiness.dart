import 'package:flutter/foundation.dart';

import 'cat_stats.dart';

/// A cozy, solo read of how ready a cat is for the *friendly* contests coming in
/// Phase 3 (roadmap p3a/b) — computed purely from its [CatStats], which in turn
/// come only from care, bond, growth, and personality. There is deliberately no
/// live opponent, no score to beat, and no purchase lever anywhere in reach: the
/// only way any of these numbers move is caring for the cat.
///
/// The single most important product line here is [careNudge]: when a stat is a
/// little low, the game points the player at *a kind care action*, never a shop.
@immutable
class ContestReadiness {
  const ContestReadiness({
    required this.overall,
    required this.strongest,
    required this.gentlest,
  });

  /// Average of the six stats, 0–100 — a soft "how warmed-up are we?" ring.
  final int overall;

  /// The cat's brightest stat (its signature event) and its gentlest one (the
  /// stat a little care would lift). Ties resolve by [CatStat] declaration order
  /// so the result is fully deterministic.
  final CatStat strongest;
  final CatStat gentlest;

  factory ContestReadiness.from(CatStats stats) {
    var strongest = CatStat.values.first;
    var gentlest = CatStat.values.first;
    var total = 0;
    for (final s in CatStat.values) {
      final v = stats[s];
      total += v;
      if (v > stats[strongest]) strongest = s;
      if (v < stats[gentlest]) gentlest = s;
    }
    return ContestReadiness(
      overall: (total / CatStat.values.length).round(),
      strongest: strongest,
      gentlest: gentlest,
    );
  }

  /// The friendly event this cat shines at, matched to [strongest].
  String get signatureEvent => _events[strongest]!;

  /// A warm, encouraging read of overall readiness — never a pass/fail.
  String get moodLine {
    if (overall >= 80) return 'Bright-eyed and bushy-tailed — raring to play!';
    if (overall >= 55) return 'Warmed up and happy to join in.';
    if (overall >= 30) return 'A little sleepy, but always up for gentle fun.';
    return 'Cozy and low-key today — a bit of care will perk them up.';
  }

  /// The kindness nudge: a care action (never a purchase) that would lift the
  /// [gentlest] stat. This is the *only* improvement path the screen ever offers.
  String get careNudge => _nudges[gentlest]!;

  static const Map<CatStat, String> _events = {
    CatStat.agility: 'Agility course',
    CatStat.speed: 'Zoomie race',
    CatStat.confidence: 'Paw wrestling',
    CatStat.curiosity: 'Treasure hunt',
    CatStat.energy: 'Toy chase',
    CatStat.cuteness: 'Cutest-pose parade',
  };

  static const Map<CatStat, String> _nudges = {
    CatStat.agility: 'A little more playtime keeps them nimble.',
    CatStat.speed: 'Regular play keeps them quick on their paws.',
    CatStat.confidence: 'Time together, gently, builds their confidence.',
    CatStat.curiosity: 'New play and fresh toys keep their curiosity bright.',
    CatStat.energy: 'A good meal and a proper nap restore their energy.',
    CatStat.cuteness: 'A spa-day groom brings out their shine.',
  };
}

/// Human-friendly label for a [CatStat] (e.g. cuteness -> 'Cuteness').
String statLabel(CatStat stat) => switch (stat) {
      CatStat.agility => 'Agility',
      CatStat.speed => 'Speed',
      CatStat.confidence => 'Confidence',
      CatStat.curiosity => 'Curiosity',
      CatStat.energy => 'Energy',
      CatStat.cuteness => 'Cuteness',
    };
