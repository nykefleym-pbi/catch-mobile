import 'package:flutter/foundation.dart';

import 'cat.dart';

/// A pure, read-only snapshot of the player's whole collection — the data
/// behind the CatDex showcase (roadmap p3: "CatDex showcases"). Every figure
/// here celebrates *care and collecting*, never spending: totals, distinct
/// personalities met, places walked, and cosmetics styled. There is no score,
/// no leaderboard, and no purchasable lever — in keeping with the product's
/// kindness-over-competition, no-pay-to-win pillars.
@immutable
class CollectionSummary {
  const CollectionSummary({
    required this.totalCats,
    required this.traitsCollected,
    required this.traitsKnown,
    required this.placesMet,
    required this.collarsStyled,
    required this.firstMet,
    required this.latestMet,
  });

  /// How many companions the player has caught.
  final int totalCats;

  /// Distinct known personalities represented in the collection.
  final int traitsCollected;

  /// The total number of personalities the client knows about (the
  /// denominator for a gentle "collected X of Y" line).
  final int traitsKnown;

  /// How many cats were met with a (coarse, fuzzed) location — a proxy for
  /// "places walked". Never exposes the coordinates themselves.
  final int placesMet;

  /// Distinct cosmetic collars currently equipped across the collection.
  final int collarsStyled;

  /// The earliest and most recent companions by discovery time, if known.
  final Cat? firstMet;
  final Cat? latestMet;

  bool get isEmpty => totalCats == 0;

  /// Progress (0–1) toward meeting one of every known personality — a soft,
  /// never-punitive completion signal for the showcase header.
  double get traitProgress =>
      traitsKnown == 0 ? 0 : (traitsCollected / traitsKnown).clamp(0.0, 1.0);

  /// Derives the summary from the player's own cats. Pure and deterministic —
  /// the same list always yields the same figures.
  factory CollectionSummary.fromCats(List<Cat> cats) {
    if (cats.isEmpty) {
      return CollectionSummary(
        totalCats: 0,
        traitsCollected: 0,
        traitsKnown: kKnownTraitIds.length,
        placesMet: 0,
        collarsStyled: 0,
        firstMet: null,
        latestMet: null,
      );
    }

    final knownTraits = kKnownTraitIds.toSet();
    final traits = <String>{};
    final collars = <String>{};
    var placed = 0;
    Cat? first;
    Cat? latest;

    for (final cat in cats) {
      final trait = cat.traitId;
      if (trait != null && knownTraits.contains(trait)) traits.add(trait);
      final collar = cat.collarId;
      if (collar != null && collar.isNotEmpty) collars.add(collar);
      if (cat.hasLocation) placed++;

      final discovered = cat.discoveredAt;
      if (discovered != null) {
        if (first?.discoveredAt == null ||
            discovered.isBefore(first!.discoveredAt!)) {
          first = cat;
        }
        if (latest?.discoveredAt == null ||
            discovered.isAfter(latest!.discoveredAt!)) {
          latest = cat;
        }
      }
    }

    return CollectionSummary(
      totalCats: cats.length,
      traitsCollected: traits.length,
      traitsKnown: kKnownTraitIds.length,
      placesMet: placed,
      collarsStyled: collars.length,
      firstMet: first,
      latestMet: latest,
    );
  }
}
