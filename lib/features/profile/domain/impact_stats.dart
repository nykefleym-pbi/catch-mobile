import 'package:flutter/foundation.dart';

/// "Impact so far" — an **honest**, own-data reflection of the player's kindness
/// (cats met, places explored, bond built, lessons learned).
///
/// INVARIANT (ADR 0005): this must **never** carry donation, "cats helped",
/// fundraising, revenue, or partner figures. Those belong to Phase 4 and are
/// gated on real-world legitimacy — showing them here would be a fabricated
/// claim. The metric set is deliberately closed and pinned by a unit test, so
/// no real-world-impact field can be slipped in before it is truthful.
@immutable
class ImpactStats {
  const ImpactStats({
    required this.catsMet,
    required this.placesExplored,
    required this.bondShared,
    required this.lessonsLearned,
  });

  final int catsMet;
  final int placesExplored;
  final int bondShared;
  final int lessonsLearned;

  /// The ordered, own-data metrics for display. These keys are the *only* impact
  /// metrics that exist pre-Phase-4; a test pins this allow-list so nothing that
  /// implies real-world impact (donations, cats helped) can appear here.
  Map<String, int> toMetrics() => {
        'cats_met': catsMet,
        'places_explored': placesExplored,
        'bond_shared': bondShared,
        'lessons_learned': lessonsLearned,
      };

  static const ImpactStats empty = ImpactStats(
    catsMet: 0,
    placesExplored: 0,
    bondShared: 0,
    lessonsLearned: 0,
  );
}
