import 'package:flutter/foundation.dart';

/// A Guardian rank tier. Rank is earned through kindness — caring for cats —
/// never combat (docs/product/01-vision.md), so the score blends how many cats
/// you've befriended with the total bond you've built with them.
@immutable
class GuardianTier {
  const GuardianTier(this.threshold, this.name);

  final int threshold;
  final String name;
}

const List<GuardianTier> _tiers = [
  GuardianTier(0, 'Fledgling Guardian'),
  GuardianTier(20, 'Caretaker'),
  GuardianTier(50, 'Kind Guardian'),
  GuardianTier(100, 'Devoted Guardian'),
  GuardianTier(200, 'Cat Whisperer'),
  GuardianTier(400, 'Legendary Guardian'),
];

/// Pure helpers for turning a Guardian score into a rank tier + progress.
class GuardianRank {
  const GuardianRank._();

  static int _indexFor(int score) {
    var index = 0;
    for (var i = 0; i < _tiers.length; i++) {
      if (score >= _tiers[i].threshold) {
        index = i;
      } else {
        break;
      }
    }
    return index;
  }

  static String labelFor(int score) => _tiers[_indexFor(score)].name;

  static bool isMax(int score) => _indexFor(score) >= _tiers.length - 1;

  /// Progress (0–1) within the current tier toward the next; full at max tier.
  static double progressFor(int score) {
    final i = _indexFor(score);
    if (i >= _tiers.length - 1) return 1;
    final current = _tiers[i].threshold;
    final next = _tiers[i + 1].threshold;
    return ((score - current) / (next - current)).clamp(0.0, 1.0);
  }

  /// Points still needed to reach the next tier, or 0 at max.
  static int toNext(int score) {
    final i = _indexFor(score);
    if (i >= _tiers.length - 1) return 0;
    return _tiers[i + 1].threshold - score;
  }
}

/// A snapshot of the player's Guardian identity and progress, aggregated from
/// their `profiles` row and their caught `cats`.
@immutable
class GuardianProfile {
  const GuardianProfile({
    required this.displayName,
    required this.catsCount,
    required this.totalBond,
  });

  final String? displayName;
  final int catsCount;
  final int totalBond;

  /// Kindness score: befriending cats and deepening each bond both count.
  int get score => catsCount * 3 + totalBond;

  String get rankLabel => GuardianRank.labelFor(score);
  double get rankProgress => GuardianRank.progressFor(score);
  bool get rankIsMax => GuardianRank.isMax(score);
  int get pointsToNextRank => GuardianRank.toNext(score);

  static const GuardianProfile empty =
      GuardianProfile(displayName: null, catsCount: 0, totalBond: 0);
}
